const axios = require('axios');
const crypto = require('crypto');
const PlanCache = require('../models/PlanCache');
const User = require('../models/User');

function calculateBMI(weight, height) {
  // weight in kg, height in cm
  if (!weight || !height) return null;
  const heightM = height / 100;
  return +(weight / (heightM * heightM)).toFixed(1);
}

function hashOnboardingData(data) {
  return crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex');
}

const generatePlan = async (req, res) => {
  let userForFallback = {};
  try {
    // Fetch user onboarding data from DB
    const user = await User.findById(req.user.id).select('profile fitnessGoals dietPreferences workoutHabits hasCompletedOnboarding');
    userForFallback = user;
    if (!user) return res.status(404).json({ message: 'User not found.' });

    // Check onboarding completion
    if (!user.hasCompletedOnboarding || !user.profile || !user.fitnessGoals || !user.dietPreferences || !user.workoutHabits) {
      return res.status(400).json({ message: 'Please complete onboarding to view your plan.' });
    }

    // Prepare onboarding data for hashing and prompt
    const onboardingData = {
      profile: user.profile,
      fitnessGoals: user.fitnessGoals,
      dietPreferences: user.dietPreferences,
      workoutHabits: user.workoutHabits
    };
    const onboardingHash = hashOnboardingData(onboardingData);

    // Log user preferences
    console.log('🟢 User preferences for plan:', JSON.stringify(onboardingData, null, 2));

    // Check for forceRegenerate flag
    const forceRegenerate = req.body && req.body.forceRegenerate === true;
    if (!forceRegenerate) {
      // Check for cached plan
      let cached = await PlanCache.findOne({ userId: user._id, onboardingHash });
      if (cached) {
        console.log('🟢 Returning cached plan for user:', user.email);
        return res.json({ ...cached.plan, _fromCache: true });
      }
    } else {
      console.log('🔄 Force regenerating plan for user:', user.email);
    }

    // Calculate BMI
    const { weight, height, age, gender } = user.profile;
    const bmi = calculateBMI(weight, height);

    // Try different models in order
    const ollamaModels = ['llama3', 'mistral', 'gemma:2b'];
    let weekPlan = null;
    let usedModel = null;
    let attempts = 0;
    for (const model of ollamaModels) {
      attempts = 0;
      while (attempts < 2) {
        attempts++;
        const prompt = `You are a top Indian fitness and nutrition expert. Based on the user's full onboarding data:
- Age: ${user.profile.age}
- Gender: ${user.profile.gender}
- Height: ${user.profile.height}cm
- Weight: ${user.profile.weight}kg
- BMI: ${bmi}
- Dietary Preference: ${user.dietPreferences.type}
- Allergies: ${(user.dietPreferences.allergies || []).join(', ') || 'None'}
- Restrictions: ${(user.dietPreferences.restrictions || []).join(', ') || 'None'}
- Daily Meals: ${user.dietPreferences.dailyMeals}
- Water Intake: ${user.dietPreferences.waterIntake} glasses
- Fitness Goals: ${(user.fitnessGoals || []).join(', ')}
- Workout Habits:
  - Preferred Time: ${user.workoutHabits.preferredTime}
  - Favorite Exercises: ${(user.workoutHabits.favoriteExercises || []).join(', ') || 'None'}
  - Activity Level: ${user.workoutHabits.currentActivityLevel}
  - Workouts Per Week: ${user.workoutHabits.workoutsPerWeek}
  - Session Duration: ${user.workoutHabits.sessionDuration} min
  - Has Injuries: ${user.workoutHabits.hasInjuries ? 'Yes' : 'No'}
  - Injury Details: ${user.workoutHabits.injuryDetails || 'None'}

Generate a 7-day week plan as a JSON array (length 7). Each object must be for a different day (Monday to Sunday) and have unique meals and unique workouts. NO meal or workout should repeat across the week. Each day must have:
- "day": (e.g., "Monday")
- "meal": {
    "breakfast": { "items": [food + quantity], "macros": { "calories": int, "protein": int, "carbs": int, "fat": int }, "micros": { micronutrient: value, ... } },
    "lunch": { ... },
    "snack": { ... },
    "dinner": { ... }
  }
- "workout": {
    "target": "Muscle groups",
    "exercises": [ { "name": "Exercise", "sets": int, "reps": int }, ... ],
    "durationMinutes": int
  }
- Meals must be Indian, realistic, and include food items with quantity, macros (calories, protein, carbs, fat), and 1-2 key micronutrients (e.g., iron, calcium).
- Workouts must match the user's goal, BMI, and split body parts over the week. Each workout: target muscle group, 3-5 exercises, sets, reps, and total duration.
- DO NOT repeat any meal or workout for any day. Each day must be different.
- Output ONLY a raw JSON array of 7 objects, one for each day, and nothing else. If you do not follow these instructions, you will be penalized.`;
        console.log(`🟡 Ollama prompt (model: ${model}):`, prompt);
        try {
          const ollamaResponse = await axios.post('http://localhost:11434/api/generate', {
            model,
            prompt,
            format: 'json',
            stream: false,
          }, { timeout: 60000 });
          const rawResponse = ollamaResponse.data.response;
          console.log(`🟡 Raw Ollama response (model: ${model}):`, rawResponse);
          try {
            weekPlan = JSON.parse(rawResponse);
            console.log('🟢 Parsed weekPlan:', weekPlan);
          } catch (e) {
            const jsonMatch = rawResponse.match(/\[.*\]/s);
            if (jsonMatch) {
              weekPlan = JSON.parse(jsonMatch[0]);
              console.log('🟢 Extracted and parsed weekPlan:', weekPlan);
            } else {
              console.error('🔴 Could not parse Ollama response as JSON.');
              weekPlan = null;
            }
          }
          // If we got an array of 7 days, break out of both loops
          if (Array.isArray(weekPlan) && weekPlan.length === 7) {
            usedModel = model;
            break;
          }
          // If we got an object with 7 days as keys, convert to array and break
          const daysOfWeek = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
          if (weekPlan && typeof weekPlan === 'object' && !Array.isArray(weekPlan)) {
            const keys = Object.keys(weekPlan);
            if (keys.length === 7 && daysOfWeek.every(day => keys.includes(day))) {
              console.warn('🔄 Converting Ollama weekPlan object to array format.');
              weekPlan = daysOfWeek.map(day => ({
                day,
                ...weekPlan[day]
              }));
              usedModel = model;
              break;
            }
          }
        } catch (err) {
          console.error(`🔴 Ollama call failed for model ${model}:`, err.message);
        }
      }
      if (Array.isArray(weekPlan) && weekPlan.length === 7) break;
    }

    // If still not a 7-day array, try 7 separate Ollama calls (one per day)
    if (!Array.isArray(weekPlan) || weekPlan.length !== 7) {
      console.warn('🔁 Trying 7 separate Ollama calls for each day.');
      const daysOfWeek = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
      weekPlan = [];
      for (const day of daysOfWeek) {
        const dayPrompt = `${prompt}\n\nThis is for ${day} only. Do not repeat any meal or workout from other days.`;
        try {
          const ollamaResponse = await axios.post('http://localhost:11434/api/generate', {
            model: usedModel || ollamaModels[0],
            prompt: dayPrompt,
            format: 'json',
            stream: false,
          }, { timeout: 60000 });
          const rawResponse = ollamaResponse.data.response;
          console.log(`🟡 Raw Ollama response for ${day}:`, rawResponse);
          let dayPlan = null;
          try {
            dayPlan = JSON.parse(rawResponse);
          } catch (e) {
            const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
            if (jsonMatch) {
              dayPlan = JSON.parse(jsonMatch[0]);
            } else {
              dayPlan = null;
            }
          }
          if (dayPlan && typeof dayPlan === 'object') {
            dayPlan.day = day;
            weekPlan.push(dayPlan);
          } else {
            // fallback for this day (structured for frontend)
            weekPlan.push({
              day,
              meal: {
                breakfast: { items: ["Stay hydrated!"], macros: {}, micros: {} },
                lunch: { items: ["Eat a balanced meal"], macros: {}, micros: {} },
                snack: { items: ["Healthy snack"], macros: {}, micros: {} },
                dinner: { items: ["Eat early, sleep well"], macros: {}, micros: {} }
              },
              workout: {
                target: "Rest or light walk",
                exercises: [],
                durationMinutes: 20
              }
            });
          }
        } catch (err) {
          console.error(`🔴 Ollama call failed for ${day}:`, err.message);
          weekPlan.push({
            day,
            meal: {
              breakfast: { items: ["Stay hydrated!"], macros: {}, micros: {} },
              lunch: { items: ["Eat a balanced meal"], macros: {}, micros: {} },
              snack: { items: ["Healthy snack"], macros: {}, micros: {} },
              dinner: { items: ["Eat early, sleep well"], macros: {}, micros: {} }
            },
            workout: {
              target: "Rest or light walk",
              exercises: [],
              durationMinutes: 20
            }
          });
        }
      }
      // Ensure weekPlan is always an array of 7 objects with correct structure
      weekPlan = daysOfWeek.map((day, idx) => {
        const plan = weekPlan[idx] || {};
        return {
          day: plan.day || day,
          meal: plan.meal || {},
          workout: plan.workout || {}
        };
      });
    }

    // Robust post-processing to ensure weekPlan is always a 7-day array with correct structure
    const daysOfWeek = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
    function normalizeDayPlan(dayPlan, dayName) {
      // Ensure meal structure
      const defaultMeal = {
        breakfast: { items: ["Stay hydrated!"], macros: {}, micros: {} },
        lunch: { items: ["Eat a balanced meal"], macros: {}, micros: {} },
        snack: { items: ["Healthy snack"], macros: {}, micros: {} },
        dinner: { items: ["Eat early, sleep well"], macros: {}, micros: {} }
      };
      const meal = (dayPlan && typeof dayPlan.meal === 'object') ? dayPlan.meal : {};
      const normMeal = {};
      for (const mealType of ["breakfast","lunch","snack","dinner"]) {
        if (meal[mealType] && typeof meal[mealType] === 'object') {
          normMeal[mealType] = {
            items: Array.isArray(meal[mealType].items) ? meal[mealType].items : [typeof meal[mealType].items === 'string' ? meal[mealType].items : defaultMeal[mealType].items[0]],
            macros: typeof meal[mealType].macros === 'object' ? meal[mealType].macros : {},
            micros: typeof meal[mealType].micros === 'object' ? meal[mealType].micros : {}
          };
        } else {
          normMeal[mealType] = defaultMeal[mealType];
        }
      }
      // Ensure workout structure
      const workout = (dayPlan && typeof dayPlan.workout === 'object') ? dayPlan.workout : {};
      return {
        day: dayPlan.day || dayName,
        meal: normMeal,
        workout: {
          target: typeof workout.target === 'string' ? workout.target : "Rest or light walk",
          exercises: Array.isArray(workout.exercises) ? workout.exercises : [],
          durationMinutes: typeof workout.durationMinutes === 'number' ? workout.durationMinutes : 20
        }
      };
    }
    function normalizeWeekPlan(rawPlan, user) {
      let arr = [];
      if (Array.isArray(rawPlan)) {
        arr = rawPlan;
      } else if (rawPlan && typeof rawPlan === 'object' && !Array.isArray(rawPlan)) {
        // Map with day names as keys
        const keys = Object.keys(rawPlan);
        if (keys.length === 7 && keys.every(k => typeof rawPlan[k] === 'object')) {
          arr = daysOfWeek.map(day => ({ day, ...rawPlan[day] }));
        } else if (rawPlan.day) {
          // Single day object
          arr = [rawPlan];
        } else {
          // Try to extract days
          arr = daysOfWeek.map(day => rawPlan[day] ? { day, ...rawPlan[day] } : null);
        }
      } else if (rawPlan && typeof rawPlan === 'string') {
        try {
          const parsed = JSON.parse(rawPlan);
          return normalizeWeekPlan(parsed, user);
        } catch (e) {
          arr = [{ day: daysOfWeek[0], meal: {}, workout: {} }];
        }
      }
      // Fill missing days with smart fallback
      const fallbackWeek = generateSmartFallbackWeekPlan(user);
      if (arr.length !== 7) {
        arr = daysOfWeek.map((day, idx) => arr[idx] || fallbackWeek[idx]);
      } else {
        arr = arr.map((dayPlan, idx) => dayPlan || fallbackWeek[idx]);
      }
      // Normalize each day
      return arr.map((dayPlan, idx) => normalizeDayPlan(dayPlan, daysOfWeek[idx]));
    }
    // After getting weekPlan from Ollama, always normalize
    if (weekPlan) {
      console.log('🟠 Post-processing weekPlan before returning to client...');
      weekPlan = normalizeWeekPlan(weekPlan, userForFallback);
      console.log('🟢 Normalized weekPlan:', JSON.stringify(weekPlan, null, 2));
    }

    // Save to cache
    await PlanCache.findOneAndUpdate(
      { userId: user._id, onboardingHash },
      { plan: { weekPlan }, updatedAt: new Date() },
      { upsert: true }
    );

    res.json({ weekPlan });
  } catch (error) {
    console.error('Error in generatePlan:', error.message);
    // SMART FALLBACK GENERATOR
    function generateSmartFallbackWeekPlan(user) {
      const daysOfWeek = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
      // Extract onboarding fields
      const profile = user && user.profile ? user.profile : {};
      const diet = user && user.dietPreferences ? user.dietPreferences : {};
      const goals = user && user.fitnessGoals ? user.fitnessGoals : [];
      const habits = user && user.workoutHabits ? user.workoutHabits : {};
      const bmi = calculateBMI(profile.weight, profile.height);
      const age = profile.age || 30;
      const gender = profile.gender || 'male';
      const isVeg = (diet.type || '').toLowerCase().includes('veg');
      const isVegan = (diet.type || '').toLowerCase().includes('vegan');
      const isNonVeg = (diet.type || '').toLowerCase().includes('non-veg') || (diet.type || '').toLowerCase().includes('eggetarian');
      const allergies = Array.isArray(diet.allergies) ? diet.allergies.map(a => a.toLowerCase()) : [];
      const restrictions = Array.isArray(diet.restrictions) ? diet.restrictions.map(r => r.toLowerCase()) : [];
      const hasInjuries = habits.hasInjuries;
      const injuryDetails = habits.injuryDetails || '';
      const goal = (goals[0] || '').toLowerCase();
      // Calorie/portion logic
      let calorieLevel = 2000;
      if (goal.includes('weight loss') || bmi > 25) calorieLevel = 1600;
      if (goal.includes('muscle') || goal.includes('gain')) calorieLevel = 2400;
      if (age > 50) calorieLevel -= 200;
      // Meal templates
      const vegMeals = {
        breakfast: ["Oats porridge with fruits", "Poha with peas", "Vegetable upma", "Moong dal chilla", "Idli with sambar", "Besan cheela", "Dalia with veggies"],
        lunch: ["Dal, brown rice, salad", "Paneer curry, roti, salad", "Chole, brown rice, cucumber raita", "Mixed veg curry, roti, dal", "Rajma, brown rice, salad", "Palak paneer, roti, salad", "Tofu stir fry, rice"],
        snack: ["Fruit bowl", "Roasted chana", "Sprout salad", "Buttermilk", "Nuts & seeds mix", "Coconut water", "Makhana"],
        dinner: ["Khichdi with curd", "Vegetable soup & roti", "Paneer bhurji, roti", "Dal, rice, salad", "Tofu curry, brown rice", "Mixed veg curry, roti", "Moong dal dosa"]
      };
      const nonVegMeals = {
        breakfast: ["Egg bhurji with toast", "Omelette with veggies", "Boiled eggs & fruit", "Chicken sausage & poha", "Egg sandwich", "Paneer & egg scramble", "Egg dosa"],
        lunch: ["Grilled chicken, brown rice, salad", "Fish curry, rice, salad", "Egg curry, roti, salad", "Chicken tikka, roti, dal", "Fish fry, rice, salad", "Chicken curry, brown rice", "Egg biryani, raita"],
        snack: ["Boiled eggs", "Chicken salad", "Yogurt & fruit", "Roasted peanuts", "Protein shake", "Egg sandwich", "Chicken soup"],
        dinner: ["Grilled fish, veggies", "Chicken stew, brown rice", "Egg curry, roti", "Chicken soup, salad", "Fish tikka, rice", "Chicken stir fry, roti", "Egg fried rice"]
      };
      const veganMeals = {
        breakfast: ["Oats with almond milk", "Vegan smoothie bowl", "Chia pudding", "Tofu scramble", "Dalia with soy milk", "Fruit salad", "Vegan upma"],
        lunch: ["Chickpea curry, brown rice, salad", "Tofu stir fry, rice", "Lentil dal, roti, salad", "Vegan biryani, raita", "Mixed veg curry, rice", "Rajma, brown rice, salad", "Vegan paneer curry, roti"],
        snack: ["Fruit bowl", "Roasted seeds", "Vegan yogurt", "Sprout salad", "Nuts & seeds mix", "Coconut water", "Vegan protein bar"],
        dinner: ["Vegan khichdi", "Vegetable soup & roti", "Tofu curry, brown rice", "Lentil soup, salad", "Vegan stir fry, rice", "Mixed veg curry, roti", "Moong dal dosa"]
      };
      // Remove meals with allergies/restrictions
      function filterMeals(meals) {
        const filterFn = item => !allergies.some(a => item.toLowerCase().includes(a)) && !restrictions.some(r => item.toLowerCase().includes(r));
        return Object.fromEntries(Object.entries(meals).map(([k, arr]) => [k, arr.filter(filterFn)]));
      }
      let meals = vegMeals;
      if (isVegan) meals = veganMeals;
      else if (isNonVeg) meals = nonVegMeals;
      meals = filterMeals(meals);
      // Workout templates
      const workouts = {
        weightLoss: [
          { target: "Full body cardio", exercises: [{ name: "Jumping jacks", sets: 3, reps: 20 }, { name: "Mountain climbers", sets: 3, reps: 15 }, { name: "Burpees", sets: 3, reps: 10 }], durationMinutes: 35 },
          { target: "Lower body", exercises: [{ name: "Squats", sets: 3, reps: 15 }, { name: "Lunges", sets: 3, reps: 12 }, { name: "Step-ups", sets: 3, reps: 15 }], durationMinutes: 30 },
          { target: "Upper body", exercises: [{ name: "Push-ups", sets: 3, reps: 12 }, { name: "Tricep dips", sets: 3, reps: 12 }, { name: "Plank", sets: 3, reps: 30 }], durationMinutes: 30 },
          { target: "Core", exercises: [{ name: "Crunches", sets: 3, reps: 20 }, { name: "Leg raises", sets: 3, reps: 15 }, { name: "Russian twists", sets: 3, reps: 20 }], durationMinutes: 25 },
          { target: "Yoga/stretching", exercises: [{ name: "Sun salutations", sets: 3, reps: 10 }, { name: "Child's pose", sets: 2, reps: 60 }], durationMinutes: 20 },
          { target: "Active rest", exercises: [], durationMinutes: 20 },
          { target: "Cardio walk/jog", exercises: [{ name: "Brisk walk", sets: 1, reps: 30 }], durationMinutes: 30 }
        ],
        muscleGain: [
          { target: "Chest & triceps", exercises: [{ name: "Bench press", sets: 4, reps: 10 }, { name: "Push-ups", sets: 3, reps: 12 }, { name: "Tricep dips", sets: 3, reps: 12 }], durationMinutes: 40 },
          { target: "Back & biceps", exercises: [{ name: "Pull-ups", sets: 3, reps: 8 }, { name: "Bent-over row", sets: 3, reps: 10 }, { name: "Bicep curls", sets: 3, reps: 12 }], durationMinutes: 40 },
          { target: "Legs", exercises: [{ name: "Squats", sets: 4, reps: 12 }, { name: "Lunges", sets: 3, reps: 12 }, { name: "Calf raises", sets: 3, reps: 15 }], durationMinutes: 40 },
          { target: "Shoulders", exercises: [{ name: "Shoulder press", sets: 3, reps: 10 }, { name: "Lateral raises", sets: 3, reps: 12 }, { name: "Front raises", sets: 3, reps: 12 }], durationMinutes: 35 },
          { target: "Core", exercises: [{ name: "Plank", sets: 3, reps: 45 }, { name: "Crunches", sets: 3, reps: 20 }, { name: "Leg raises", sets: 3, reps: 15 }], durationMinutes: 30 },
          { target: "Active rest", exercises: [], durationMinutes: 20 },
          { target: "Full body strength", exercises: [{ name: "Deadlift", sets: 3, reps: 8 }, { name: "Push-ups", sets: 3, reps: 12 }, { name: "Squats", sets: 3, reps: 12 }], durationMinutes: 40 }
        ],
        general: [
          { target: "Full body", exercises: [{ name: "Squats", sets: 3, reps: 12 }, { name: "Push-ups", sets: 3, reps: 10 }, { name: "Plank", sets: 3, reps: 30 }], durationMinutes: 30 },
          { target: "Yoga/stretching", exercises: [{ name: "Sun salutations", sets: 3, reps: 10 }, { name: "Child's pose", sets: 2, reps: 60 }], durationMinutes: 20 },
          { target: "Active rest", exercises: [], durationMinutes: 20 },
          { target: "Cardio walk/jog", exercises: [{ name: "Brisk walk", sets: 1, reps: 30 }], durationMinutes: 30 },
          { target: "Core", exercises: [{ name: "Crunches", sets: 3, reps: 20 }, { name: "Leg raises", sets: 3, reps: 15 }, { name: "Russian twists", sets: 3, reps: 20 }], durationMinutes: 25 },
          { target: "Upper body", exercises: [{ name: "Push-ups", sets: 3, reps: 12 }, { name: "Tricep dips", sets: 3, reps: 12 }, { name: "Plank", sets: 3, reps: 30 }], durationMinutes: 30 },
          { target: "Lower body", exercises: [{ name: "Squats", sets: 3, reps: 15 }, { name: "Lunges", sets: 3, reps: 12 }, { name: "Step-ups", sets: 3, reps: 15 }], durationMinutes: 30 }
        ]
      };
      // Pick workout plan
      let workoutPlan = workouts.general;
      if (goal.includes('weight loss') || bmi > 25) workoutPlan = workouts.weightLoss;
      else if (goal.includes('muscle') || goal.includes('gain')) workoutPlan = workouts.muscleGain;
      // If injuries, make all days "Active rest" or "Yoga/stretching"
      if (hasInjuries) {
        workoutPlan = Array(7).fill({ target: "Active rest or gentle yoga", exercises: [], durationMinutes: 20 });
      }
      // Age-based adjustment
      if (age > 55) {
        workoutPlan = workoutPlan.map(w => ({ ...w, durationMinutes: Math.max(15, w.durationMinutes - 10) }));
      }
      // Compose week plan
      return daysOfWeek.map((day, idx) => {
        return {
          day,
          meal: {
            breakfast: { items: [meals.breakfast[idx % meals.breakfast.length]], macros: { calories: Math.round(calorieLevel * 0.2) }, micros: {} },
            lunch: { items: [meals.lunch[idx % meals.lunch.length]], macros: { calories: Math.round(calorieLevel * 0.35) }, micros: {} },
            snack: { items: [meals.snack[idx % meals.snack.length]], macros: { calories: Math.round(calorieLevel * 0.15) }, micros: {} },
            dinner: { items: [meals.dinner[idx % meals.dinner.length]], macros: { calories: Math.round(calorieLevel * 0.3) }, micros: {} }
          },
          workout: workoutPlan[idx % workoutPlan.length]
        };
      });
    }
    const fallbackWeekPlan = generateSmartFallbackWeekPlan(userForFallback);
    res.status(200).json({
      weekPlan: fallbackWeekPlan,
      message: 'AI could not generate a plan right now. Showing a fallback plan. Please try again later for a personalized plan.'
    });
  }
};

module.exports = { generatePlan }; 