const axios = require('axios');
const crypto = require('crypto');
const PlanCache = require('../models/PlanCache');
const User = require('../models/User');
const Plan = require('../models/plan');

const OLLAMA_URL = 'http://localhost:11434';
let availableOllamaModels = ['gemma:2b']; // Default, will update at server start

// Query Ollama for available models at server start
async function fetchAvailableOllamaModels() {
  try {
    const resp = await axios.get(`${OLLAMA_URL}/api/tags`);
    if (resp.data && Array.isArray(resp.data.models)) {
      availableOllamaModels = resp.data.models.map(m => m.name);
      console.log('🟢 Ollama available models:', availableOllamaModels);
    }
  } catch (err) {
    console.error('🔴 Could not fetch Ollama models:', err.message);
  }
}
fetchAvailableOllamaModels();

// Pre-warm Ollama model at server start
async function prewarmOllamaModel() {
  try {
    console.log('🟡 Pre-warming Ollama model gemma:2b...');
    const start = Date.now();
    await axios.post(
      OLLAMA_URL + '/api/generate',
      {
        model: 'gemma:2b',
        prompt: 'Say hello',
        format: 'json',
        stream: false
      },
      { timeout: 10000 }
    );
    console.log('🟢 Ollama gemma:2b pre-warmed in', Date.now() - start, 'ms');
  } catch (e) {
    console.error('🔴 Ollama pre-warm failed:', e.message);
  }
}
prewarmOllamaModel();

function prioritizeModels(models) {
  const priority = [
    'dolphin-mistral:latest', 'dolphin-mistral',
    'mistral:latest', 'mistral',
    'llama3:latest', 'llama3',
    'gemma:2b', 'gemma:latest', 'gemma'
  ];
  return models.sort((a, b) => {
    const ia = priority.findIndex(p => a.startsWith(p));
    const ib = priority.findIndex(p => b.startsWith(p));
    return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib);
  });
}

function calculateBMI(weight, height) {
  // weight in kg, height in cm
  if (!weight || !height) return null;
  const heightM = height / 100;
  return +(weight / (heightM * heightM)).toFixed(1);
}

function hashOnboardingData(data) {
  return crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex');
}

function generateDetailedFallbackWeekPlan(user) {
  // Helper functions for meals and workouts
  function getMealType(dietType, allergies, restrictions) {
    if (dietType === 'vegan') return 'vegan';
    if (dietType === 'vegetarian') return 'vegetarian';
    if (dietType === 'non_vegetarian') return 'non_veg';
    return 'mixed';
  }
  function filterAllergens(items, allergies) {
    if (!allergies || allergies.length === 0) return items;
    return items.filter(item => !allergies.some(all => item.toLowerCase().includes(all.toLowerCase())));
  }
  function adjustMacrosByGoal(macros, goal, gender, age, bmi) {
    let factor = 1;
    if (goal?.includes('muscle_gain')) factor = 1.2;
    if (goal?.includes('fat_loss')) factor = 0.8;
    if (goal?.includes('endurance')) factor = 1.1;
    if (gender === 'female') factor *= 0.9;
    if (age > 50) factor *= 0.95;
    if (bmi && bmi < 18.5) factor *= 1.1;
    if (bmi && bmi > 30) factor *= 0.85;
    return {
      cal: Math.round(macros.cal * factor),
      p: Math.round(macros.p * factor),
      c: Math.round(macros.c * factor),
      f: Math.round(macros.f * factor)
    };
  }
  function getMealsForDay(dayIdx, user, bmi) {
    // Templates for each type
    const vegMeals = [
      ['Poha', 'Upma', 'Dalia', 'Vegetable Paratha'],
      ['Paneer Curry', 'Dal Tadka', 'Rajma Rice', 'Chole Bhature'],
      ['Fruit Salad', 'Sprouts Chaat', 'Roasted Chickpeas', 'Yogurt with Fruits'],
      ['Palak Paneer', 'Mixed Veg Curry', 'Kadhi Rice', 'Aloo Gobi']
    ];
    const nonVegMeals = [
      ['Egg Bhurji', 'Chicken Sandwich', 'Omelette', 'Fish Poha'],
      ['Chicken Curry', 'Fish Fry', 'Egg Curry', 'Mutton Stew'],
      ['Chicken Salad', 'Egg Whites', 'Tuna Salad', 'Chicken Soup'],
      ['Grilled Chicken', 'Fish Curry', 'Egg Biryani', 'Prawn Masala']
    ];
    const veganMeals = [
      ['Oats Porridge', 'Vegan Upma', 'Tofu Scramble', 'Chickpea Pancake'],
      ['Tofu Curry', 'Vegan Dal', 'Quinoa Salad', 'Vegan Biryani'],
      ['Fruit Bowl', 'Roasted Seeds', 'Vegan Yogurt', 'Nut Mix'],
      ['Vegan Stir Fry', 'Lentil Soup', 'Stuffed Capsicum', 'Vegan Khichdi']
    ];
    let mealSet = vegMeals;
    if (user.dietPreferences?.type === 'non_vegetarian') mealSet = nonVegMeals;
    if (user.dietPreferences?.type === 'vegan') mealSet = veganMeals;
    // Rotate meals for variety
    const breakfastTitle = filterAllergens([mealSet[0][dayIdx % mealSet[0].length]], user.dietPreferences?.allergies)[0] || 'Breakfast';
    const lunchTitle = filterAllergens([mealSet[1][dayIdx % mealSet[1].length]], user.dietPreferences?.allergies)[0] || 'Lunch';
    const snackTitle = filterAllergens([mealSet[2][dayIdx % mealSet[2].length]], user.dietPreferences?.allergies)[0] || 'Snack';
    const dinnerTitle = filterAllergens([mealSet[3][dayIdx % mealSet[3].length]], user.dietPreferences?.allergies)[0] || 'Dinner';
    // Macros and micros (dynamic)
    function macros(cal, p, c, f) { return { cal, p, c, f }; }
    function micros(iron, calcium) { return { iron, calcium }; }
    // Adjust macros by user goal, gender, age, bmi
    const baseMacros = [
      macros(300, 12, 45, 8), // breakfast
      macros(500, 20, 70, 15), // lunch
      macros(200, 8, 30, 6), // snack
      macros(400, 18, 60, 12) // dinner
    ];
    return {
      breakfast: {
        title: breakfastTitle,
        macros: adjustMacrosByGoal(baseMacros[0], user.fitnessGoals, user.profile?.gender, user.profile?.age, bmi),
        micros: micros(10, 80)
      },
      lunch: {
        title: lunchTitle,
        macros: adjustMacrosByGoal(baseMacros[1], user.fitnessGoals, user.profile?.gender, user.profile?.age, bmi),
        micros: micros(15, 120)
      },
      snack: {
        title: snackTitle,
        macros: adjustMacrosByGoal(baseMacros[2], user.fitnessGoals, user.profile?.gender, user.profile?.age, bmi),
        micros: micros(8, 60)
      },
      dinner: {
        title: dinnerTitle,
        macros: adjustMacrosByGoal(baseMacros[3], user.fitnessGoals, user.profile?.gender, user.profile?.age, bmi),
        micros: micros(12, 100)
      }
    };
  }
  function getWorkoutForDay(dayIdx, user) {
    const splits = [
      { target: 'Push (Chest/Shoulders/Triceps)', exercises: ['Push-ups', 'Shoulder Press', 'Tricep Dips'] },
      { target: 'Pull (Back/Biceps)', exercises: ['Pull-ups', 'Bicep Curls', 'Rows'] },
      { target: 'Legs', exercises: ['Squats', 'Lunges', 'Calf Raises'] },
      { target: 'Cardio', exercises: ['Running', 'Cycling', 'Jump Rope'] },
      { target: 'Yoga/Flexibility', exercises: ['Sun Salutation', 'Downward Dog', 'Child Pose'] },
      { target: 'Rest/Recovery', exercises: [] },
      { target: 'Full Body', exercises: ['Burpees', 'Mountain Climbers', 'Plank'] }
    ];
    let split = splits[dayIdx % splits.length];
    if (user.fitnessGoals?.includes('fat_loss')) split = splits[3];
    if (user.fitnessGoals?.includes('flexibility')) split = splits[4];
    if (user.fitnessGoals?.includes('muscle_gain')) split = splits[dayIdx % 3];
    if (user.workoutHabits?.favoriteExercises?.length) {
      split.exercises = user.workoutHabits.favoriteExercises.slice(0, 3);
    }
    if (user.workoutHabits?.hasInjuries) {
      split.exercises = split.exercises.filter(e => !e.toLowerCase().includes('jump') && !e.toLowerCase().includes('burpee'));
      split.target += ' (Injury Safe)';
    }
    let duration = user.workoutHabits?.sessionDuration || 45;
    if (user.workoutHabits?.currentActivityLevel === 'sedentary') duration = Math.max(30, duration - 15);
    if (user.workoutHabits?.currentActivityLevel === 'very_active') duration = Math.min(90, duration + 15);
    if (user.profile?.age > 60) duration = Math.max(30, duration - 10);
    const sets = user.workoutHabits?.workoutsPerWeek >= 5 ? 4 : 3;
    const reps = user.fitnessGoals?.includes('endurance') ? 20 : 12;
    const exObjs = split.exercises.map(name => ({ name, sets, reps }));
    return {
      target: split.target,
      duration: duration,
      exercises: exObjs
    };
  }
  let bmi = null;
  if (user.profile?.weight && user.profile?.height) {
    const heightM = user.profile.height / 100;
    bmi = +(user.profile.weight / (heightM * heightM)).toFixed(1);
  }
  const daysOfWeek = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
  return daysOfWeek.map((day, idx) => ({
    day,
    meals: getMealsForDay(idx, user, bmi),
    workout: getWorkoutForDay(idx, user)
  }));
}

const BEST_MODEL_PRIORITY = [
  'dolphin-mistral:latest', 'dolphin-mistral',
  'mistral:latest', 'mistral',
  'llama3:latest', 'llama3',
  'gemma:2b', 'gemma:latest', 'gemma'
];
function getBestOllamaModel() {
  for (const name of BEST_MODEL_PRIORITY) {
    const found = availableOllamaModels.find(m => m.startsWith(name));
    if (found) return found;
  }
  return null;
}

// Utility to deeply convert any nested arrays/objects to plain values for JSON serialization
function deepSerialize(obj) {
  if (Array.isArray(obj)) {
    return obj.map(deepSerialize);
  } else if (obj && typeof obj === 'object') {
    const out = {};
    for (const k in obj) {
      out[k] = deepSerialize(obj[k]);
    }
    return out;
  }
  return obj;
}

// Ollama health check utility
async function checkOllamaHealth(model = 'gemma:2b') {
  try {
    const resp = await axios.post(
      OLLAMA_URL + '/api/generate',
      {
        model,
        prompt: 'Say hello as JSON: {"hello": "world"}',
        format: 'json',
        stream: false
      },
      { timeout: 5000 }
    );
    if (resp.data && resp.data.response && resp.data.response.includes('hello')) {
      console.log('🟢 Ollama health check passed for', model);
      return true;
    }
    console.error('🔴 Ollama health check failed for', model, resp.data);
    return false;
  } catch (e) {
    console.error('🔴 Ollama health check error for', model, e.message);
    return false;
  }
}

// Try models in order of preference
const OLLAMA_MODEL_PRIORITY = ['gemma:2b', 'llama3', 'mistral', 'dolphin-mistral:latest'];

// Helper to call Ollama for a single meal
async function getAIMeal(model, mealType, user, bmi, bmiCategory) {
  // Improved prompt: require all macros/micros, realistic non-zero values
  const prompt = `Output a JSON object for a ${user.dietPreferences.type} ${mealType} for a ${user.profile.age}y ${user.profile.gender} (${bmi.toFixed(1)} ${bmiCategory}), goals: ${user.fitnessGoals.join(' + ')}. Format: {"items": ["food1", "food2"], "cal": 400, "p": 20, "c": 50, "f": 10, "iron": 5, "calcium": 200}. All values must be realistic and non-zero.`;
  try {
    const resp = await axios.post(
      OLLAMA_URL + '/api/generate',
      {
        model,
        prompt,
        format: 'json',
        stream: false
      },
      { timeout: 8000 }
    );
    const raw = resp.data.response;
    let parsed = null;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      const jsonMatch = raw.match(/\{[\s\S]*\}/);
      if (jsonMatch) parsed = JSON.parse(jsonMatch[0]);
    }
    // Post-process: ensure all macros/micros are present and non-zero
    if (parsed && parsed.items && Array.isArray(parsed.items)) {
      const defaults = { cal: 400, p: 20, c: 50, f: 10, iron: 5, calcium: 200 };
      for (const key of Object.keys(defaults)) {
        if (!parsed[key] || typeof parsed[key] !== 'number' || parsed[key] <= 0) parsed[key] = defaults[key];
      }
      return deepSerialize(parsed);
    }
    throw new Error('Malformed meal');
  } catch (err) {
    console.error(`--- [Plan] AI meal (${mealType}) failed:`, err.message);
    return null;
  }
}
// Helper to call Ollama for workout
async function getAIWorkout(model, user, bmi, bmiCategory) {
  // Rotate target muscle group by day
  const dayTargets = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Full Body'];
  const todayIdx = new Date().getDay() % dayTargets.length;
  const target = dayTargets[todayIdx];
  // Improved prompt: request 3-5 specific exercises, each as an object with name, sets, reps, rest (seconds)
  const prompt = `Output a JSON object for a workout targeting ${target} for a ${user.profile.age}y ${user.profile.gender} with goals: ${user.fitnessGoals.join(', ')}. Include 3 to 5 specific exercises in the 'exercises' array, each as an object with fields: name, sets, reps, rest (seconds). Use realistic, specific exercises for ${target}. Format: {\"target\": \"${target}\", \"duration\": 50, \"exercises\": [{\"name\": \"Bench Press\", \"sets\": 4, \"reps\": 12, \"rest\": 90}], \"stretching\": {\"pre\": [\"Stretch1\"], \"post\": [\"Stretch2\"]}}`;
  try {
    const resp = await axios.post(
      OLLAMA_URL + '/api/generate',
      {
        model,
        prompt,
        format: 'json',
        stream: false
      },
      { timeout: 8000 }
    );
    const raw = resp.data.response;
    console.log('--- [Plan] Raw AI workout response:', raw);
    let parsed = null;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      const jsonMatch = raw.match(/\{[\s\S]*\}/);
      if (jsonMatch) parsed = JSON.parse(jsonMatch[0]);
    }
    // Post-process: ensure structure and 3-5 detailed exercises
    if (parsed && parsed.target && Array.isArray(parsed.exercises)) {
      if (!parsed.duration) parsed.duration = 50;
      if (!parsed.stretching) parsed.stretching = { pre: [], post: [] };
      // Fix each exercise to have all fields
      parsed.exercises = parsed.exercises.map((ex, i) => {
        if (typeof ex === 'string') {
          // Try to parse string like "Bench Press (4x12, rest 90s)"
          const match = ex.match(/^(.*)\s*\((\d+)x(\d+),?\s*rest\s*(\d+)s?\)?$/i);
          if (match) {
            return { name: match[1].trim(), sets: parseInt(match[2]), reps: parseInt(match[3]), rest: parseInt(match[4]) };
          }
          return { name: ex, sets: 3, reps: 12, rest: 60 };
        }
        return {
          name: ex.name || `Exercise ${i+1}`,
          sets: ex.sets && ex.sets > 0 ? ex.sets : 3,
          reps: ex.reps && ex.reps > 0 ? ex.reps : 12,
          rest: ex.rest && ex.rest > 0 ? ex.rest : 60
        };
      });
      // Pad or trim to 3-5
      const pad = [
        { name: 'Push-ups', sets: 3, reps: 15, rest: 60 },
        { name: 'Squats', sets: 3, reps: 15, rest: 60 },
        { name: 'Plank', sets: 3, reps: 1, rest: 60 },
        { name: 'Lunges', sets: 3, reps: 12, rest: 60 },
        { name: 'Rows', sets: 3, reps: 12, rest: 60 }
      ];
      while (parsed.exercises.length < 3) parsed.exercises.push(pad[parsed.exercises.length % pad.length]);
      if (parsed.exercises.length > 5) parsed.exercises = parsed.exercises.slice(0, 5);
      if (!parsed.stretching.pre) parsed.stretching.pre = [];
      if (!parsed.stretching.post) parsed.stretching.post = [];
      return deepSerialize(parsed);
    }
    throw new Error('Malformed workout');
  } catch (err) {
    console.error('--- [Plan] AI workout failed:', err.message);
    return null;
  }
}

const generatePlan = async (req, res) => {
  try {
    console.log('--- [Plan] Incoming request from user:', req.user?._id);
    const user = req.user;
    const onboardingData = {
      age: user.profile.age,
      gender: user.profile.gender,
      height: user.profile.height,
      weight: user.profile.weight,
      diet: user.dietPreferences.type,
      goals: user.fitnessGoals,
      activity: user.workoutHabits.currentActivityLevel,
      frequency: user.workoutHabits.daysPerWeek,
    };
    console.log('--- [Plan] Onboarding data:', onboardingData);
    const onboardingHash = crypto.createHash('sha256').update(JSON.stringify(onboardingData)).digest('hex');
    // Check for cached plan
    let planDoc = await Plan.findOne({ user: user._id, onboardingHash });
    const forceRefresh = req.body && req.body.forceRefresh;
    if (planDoc && !forceRefresh) {
      console.log('--- [Plan] Cache hit for user:', user._id);
      return res.json({ plan: planDoc.plan, _cached: true });
    }
    // Compose plan
    const bmi = user.profile.weight / ((user.profile.height / 100) ** 2);
    const bmiCategory = bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Normal' : bmi < 30 ? 'Overweight' : 'Obese';
    const model = 'gemma:2b';
    // Call Ollama for each meal and workout
    const mealTypes = ['breakfast', 'lunch', 'snack', 'dinner'];
    const meals = {};
    let aiFailed = false;
    for (const mealType of mealTypes) {
      const meal = await getAIMeal(model, mealType, user, bmi, bmiCategory);
      if (meal) {
        meals[mealType] = meal;
      } else {
        aiFailed = true;
        break;
      }
    }
    let workout = null;
    if (!aiFailed) {
      workout = await getAIWorkout(model, user, bmi, bmiCategory);
      // Hybrid: if workout fails, use fallback only for workout
      if (!workout) {
        workout = generateRuleBasedFallback(onboardingData, bmi, bmiCategory).workout;
        console.log('--- [Plan] Hybrid plan: AI meals, fallback workout for user:', user._id, workout);
      }
    }
    let plan = null;
    if (Object.keys(meals).length === 4 && workout) {
      plan = {
        bmi: `${bmi.toFixed(1)} (${bmiCategory})`,
        goals: user.fitnessGoals,
        meals,
        workout,
        day: new Date().toLocaleDateString('en-US', { weekday: 'long' })
      };
      plan = deepSerialize(plan);
      console.log('--- [Plan] Multi-step AI/hybrid plan generated for user:', user._id, plan);
    } else {
      plan = generateRuleBasedFallback(onboardingData, bmi, bmiCategory);
      plan = deepSerialize(plan);
      console.log('--- [Plan] Fallback plan generated for user:', user._id, plan);
    }
    // Save to DB
    await Plan.findOneAndUpdate(
      { user: user._id, onboardingHash },
      { plan, updatedAt: new Date() },
      { upsert: true }
    );
    console.log('--- [Plan] Final plan for user:', user._id, plan);
    return res.json({ plan });
  } catch (err) {
    console.error('--- [Plan] Fatal error:', err);
    return res.status(500).json({ error: err.message });
  }
};

const indianTrainerNames = [
  'Amit', 'Priya', 'Rahul', 'Sneha', 'Vikram', 'Anjali', 'Rohit', 'Neha', 'Siddharth', 'Pooja',
  'Karan', 'Meera', 'Arjun', 'Divya', 'Saurabh', 'Riya', 'Manish', 'Shreya', 'Nikhil', 'Simran'
];
function getRandomTrainerName() {
  return indianTrainerNames[Math.floor(Math.random() * indianTrainerNames.length)];
}

// AI Coach Chat: Personalized chat with Ollama
const aiCoachChat = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('name profile fitnessGoals dietPreferences workoutHabits');
    if (!user) return res.status(404).json({ message: 'User not found.' });

    const { message } = req.body;
    if (!message || typeof message !== 'string') {
      return res.status(400).json({ message: 'Message is required.' });
    }

    const trainerName = getRandomTrainerName();
    // Personalize the prompt with user data and new instructions
    const prompt = `You are a TFT Trained Coach from India. For this conversation, your name is ${trainerName}.\n\n` +
      `The user is ${user.name}, with the following profile:\n` +
      `Age: ${user.profile?.age || 'N/A'}\n` +
      `Gender: ${user.profile?.gender || 'N/A'}\n` +
      `Height: ${user.profile?.height || 'N/A'} cm\n` +
      `Weight: ${user.profile?.weight || 'N/A'} kg\n` +
      `Fitness Goals: ${(user.fitnessGoals || []).join(', ') || 'N/A'}\n` +
      `Diet: ${user.dietPreferences?.type || 'N/A'}\n` +
      `Allergies: ${(user.dietPreferences?.allergies || []).join(', ') || 'None'}\n` +
      `Workout Habits: Prefers ${user.workoutHabits?.preferredTime || 'N/A'}, ${user.workoutHabits?.workoutsPerWeek || 0} workouts/week.\n` +
      `\nUser's question: ${message}\n\n` +
      `Reply ONLY as a real human TFT Trained Coach named ${trainerName}.\n` +
      `Give a short, quick, natural answer in everyday language.\n` +
      `Do NOT mention you are an AI, do NOT give disclaimers, do NOT sound robotic.\n` +
      `Be friendly, direct, and helpful.\n` +
      `Never say you are an AI or language model.\n`;

    // Call Ollama (use first available model)
    const ollamaModels = ['llama3', 'mistral', 'gemma:2b'];
    let reply = null;
    for (const model of ollamaModels) {
      try {
        const ollamaResponse = await axios.post('http://localhost:11434/api/generate', {
          model,
          prompt,
          stream: false,
        }, { timeout: 60000 });
        reply = ollamaResponse.data.response;
        if (reply) break;
      } catch (err) {
        console.error(`Ollama call failed for model ${model}:`, err.message);
      }
    }
    if (!reply) {
      return res.status(500).json({ message: 'AI coach is unavailable. Please try again later.' });
    }
    return res.json({ reply });
  } catch (err) {
    console.error('AI Coach Chat error:', err);
    return res.status(500).json({ message: 'Internal server error.' });
  }
};

// Helper: robust rule-based fallback
function generateRuleBasedFallback(onboarding, bmi, bmiCategory) {
  // Determine meal macros based on BMI and goal
  const { diet, goals, frequency } = onboarding;
  const goal = (goals && goals.length) ? goals[0].toLowerCase() : 'general';
  // Macro templates
  const macroTemplates = {
    muscle_gain: { cal: 600, p: 30, c: 60, f: 18 },
    fat_loss: { cal: 350, p: 22, c: 35, f: 10 },
    strength: { cal: 500, p: 28, c: 45, f: 15 },
    general: { cal: 450, p: 20, c: 50, f: 12 },
  };
  let macroType = 'general';
  if (goal.includes('muscle')) macroType = 'muscle_gain';
  else if (goal.includes('fat')) macroType = 'fat_loss';
  else if (goal.includes('strength')) macroType = 'strength';

  // Meal templates (Indian)
  const mealTemplates = {
    vegetarian: {
      breakfast: ['Paneer bhurji (100g)', '2 whole wheat toast'],
      lunch: ['Dal tadka (1 cup)', 'Jeera rice (1 cup)', 'Cabbage sabzi (1 cup)'],
      snack: ['Sprout salad (1 bowl)'],
      dinner: ['Palak paneer (1 cup)', '2 chapati', 'Cucumber salad'],
    },
    non_vegetarian: {
      breakfast: ['Egg bhurji (2 eggs)', 'Toast (2)'],
      lunch: ['Chicken curry (1 cup)', 'Rice (1 cup)'],
      snack: ['Boiled eggs (2)'],
      dinner: ['Fish fry (100g)', 'Roti (2)', 'Salad (1 bowl)'],
    },
    vegan: {
      breakfast: ['Oats porridge (1 bowl)', 'Banana (1)'],
      lunch: ['Chickpea curry (1 cup)', 'Brown rice (1 cup)'],
      snack: ['Roasted peanuts (30g)'],
      dinner: ['Tofu stir fry (1 cup)', 'Roti (2)', 'Salad (1 bowl)'],
    },
  };
  const mealType = diet === 'vegan' ? 'vegan' : (diet === 'non_vegetarian' ? 'non_vegetarian' : 'vegetarian');
  const macros = macroTemplates[macroType];
  // Simple micronutrient template
  const micros = { iron: 2, calcium: 80 };
  // Build meals
  const meals = {};
  ['breakfast', 'lunch', 'snack', 'dinner'].forEach(meal => {
    meals[meal] = {
      items: mealTemplates[mealType][meal],
      cal: macros.cal,
      p: macros.p,
      c: macros.c,
      f: macros.f,
      iron: micros.iron,
      calcium: micros.calcium,
    };
  });

  // Workout split logic
  let split, focus, exercises;
  function parseExercise(str) {
    // Try to parse 'Name (4x12)' or 'Name (4x12, rest 90s)'
    const match = str.match(/^(.*)\s*\((\d+)x(\d+)(?:,\s*rest\s*(\d+)s?)?\)?$/i);
    if (match) {
      return {
        name: match[1].trim(),
        sets: parseInt(match[2]),
        reps: parseInt(match[3]),
        rest: match[4] ? parseInt(match[4]) : 60
      };
    }
    return { name: str, sets: 3, reps: 12, rest: 60 };
  }
  if (frequency >= 5) {
    // Bro split
    const broSplits = [
      { target: 'Chest + Triceps', exercises: [
        'Barbell Bench Press (4x12)',
        'Incline Dumbbell Press (4x10)',
        'Cable Flyes (3x15)',
        'Triceps Pushdown (3x12)',
        'Overhead Triceps Extension (3x10)'
      ]},
      { target: 'Back + Biceps', exercises: [
        'Pull-ups (4x8)',
        'Barbell Row (4x10)',
        'Lat Pulldown (3x12)',
        'Dumbbell Curl (3x12)',
        'Hammer Curl (3x10)'
      ]},
      { target: 'Legs', exercises: [
        'Squats (4x12)',
        'Leg Press (4x10)',
        'Leg Extension (3x15)',
        'Hamstring Curl (3x12)',
        'Standing Calf Raise (3x15)'
      ]},
      { target: 'Shoulders', exercises: [
        'Overhead Press (4x10)',
        'Lateral Raise (3x15)',
        'Front Raise (3x12)',
        'Reverse Fly (3x12)',
        'Shrugs (3x15)'
      ]},
      { target: 'Arms + Core', exercises: [
        'Close-grip Bench Press (3x12)',
        'Barbell Curl (3x12)',
        'Triceps Dips (3x10)',
        'Plank (3x60s)',
        'Russian Twist (3x20)'
      ]},
    ];
    // Pick split based on day of week
    const todayIdx = (new Date().getDay() - 1 + 7) % 7;
    const bro = broSplits[todayIdx % broSplits.length];
    split = bro.target;
    exercises = bro.exercises.map(parseExercise);
  } else {
    // PPL split
    const pplSplits = [
      { target: 'Push (Chest/Shoulders/Triceps)', exercises: [
        'Bench Press (4x12)',
        'Overhead Press (4x10)',
        'Dumbbell Flyes (3x15)',
        'Triceps Pushdown (3x12)',
        'Lateral Raise (3x12)'
      ]},
      { target: 'Pull (Back/Biceps)', exercises: [
        'Pull-ups (4x8)',
        'Barbell Row (4x10)',
        'Face Pull (3x15)',
        'Dumbbell Curl (3x12)',
        'Hammer Curl (3x10)'
      ]},
      { target: 'Legs', exercises: [
        'Squats (4x12)',
        'Leg Press (4x10)',
        'Leg Extension (3x15)',
        'Hamstring Curl (3x12)',
        'Standing Calf Raise (3x15)'
      ]},
    ];
    const todayIdx = (new Date().getDay() - 1 + 7) % 7;
    const ppl = pplSplits[todayIdx % pplSplits.length];
    split = ppl.target;
    exercises = ppl.exercises.map(parseExercise);
  }
  // Add stretching
  const stretching = {
    pre: [
      'Neck rolls (30s)',
      'Arm circles (30s)',
      'Torso twists (30s)',
      'Leg swings (30s)'
    ],
    post: [
      'Hamstring stretch (30s)',
      'Quad stretch (30s)',
      'Child pose (30s)',
      'Shoulder stretch (30s)'
    ]
  };
  // Duration
  const duration = 50;
  // Build workout
  const workout = {
    target: split,
    duration,
    exercises,
    stretching
  };
  return {
    bmi: `${bmi.toFixed(1)} (${bmiCategory})`,
    goals: onboarding.goals,
    meals,
    workout,
    day: new Date().toLocaleDateString('en-US', { weekday: 'long' })
  };
}

function fixAIMinimalPlan(plan) {
  // If workout is inside meals, move it to top level
  if (plan.meals && plan.meals.workout) {
    plan.workout = plan.meals.workout;
    delete plan.meals.workout;
  }
  // If day is inside meals, move it to top level
  if (plan.meals && plan.meals.day) {
    plan.day = plan.meals.day;
    delete plan.meals.day;
  }
  // If only breakfast is present, copy it to other meals as fallback
  if (plan.meals && plan.meals.breakfast && (!plan.meals.lunch || !plan.meals.snack || !plan.meals.dinner)) {
    const b = plan.meals.breakfast;
    if (!plan.meals.lunch) plan.meals.lunch = JSON.parse(JSON.stringify(b));
    if (!plan.meals.snack) plan.meals.snack = JSON.parse(JSON.stringify(b));
    if (!plan.meals.dinner) plan.meals.dinner = JSON.parse(JSON.stringify(b));
  }
  // Ensure all required fields
  if (!plan.bmi) plan.bmi = '--';
  if (!plan.goals) plan.goals = [];
  if (!plan.meals) plan.meals = { breakfast: {}, lunch: {}, snack: {}, dinner: {} };
  if (!plan.meals.breakfast) plan.meals.breakfast = {};
  if (!plan.meals.lunch) plan.meals.lunch = {};
  if (!plan.meals.snack) plan.meals.snack = {};
  if (!plan.meals.dinner) plan.meals.dinner = {};
  if (!plan.workout) plan.workout = { target: '', duration: 0, exercises: [], stretching: { pre: [], post: [] } };
  if (!plan.day) plan.day = new Date().toLocaleDateString('en-US', { weekday: 'long' });
  return plan;
}

module.exports = {
  generatePlan,
  aiCoachChat,
}; 