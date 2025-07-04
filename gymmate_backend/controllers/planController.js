const MealPlan = require('../models/mealPlan');
const WorkoutPlan = require('../models/workoutPlan');
const User = require('../models/User');

// GET /api/plans/meal?goal=...&dietType=...&bmiCategory=...&day=...
exports.getMealPlanForUser = async (req, res) => {
  try {
    const { goal, dietType, bmiCategory, day, memberId } = req.query;
    console.log('[MealPlan] Incoming query:', { goal, dietType, bmiCategory, day, memberId });
    if (memberId) {
      const member = await User.findById(memberId);
      if (member && member.customMealPlan) {
        console.log('[MealPlan] Returning customMealPlan for member:', memberId);
        return res.json(member.customMealPlan);
      }
    }
    let plan = await MealPlan.findOne({ goal, dietType, bmiCategory, day });
    console.log('[MealPlan] Plan found for query:', plan);
    if (!plan) {
      // fallback: generic plan for the day
      plan = await MealPlan.findOne({ day });
      console.log('[MealPlan] Fallback plan for day:', day, plan);
    }
    if (!plan && goal) {
      plan = await MealPlan.findOne({ goal });
      console.log('[MealPlan] Fallback plan for goal:', goal, plan);
    }
    if (!plan && dietType) {
      plan = await MealPlan.findOne({ dietType });
      console.log('[MealPlan] Fallback plan for dietType:', dietType, plan);
    }
    if (!plan) {
      plan = await MealPlan.findOne();
      console.log('[MealPlan] Fallback to any plan:', plan);
    }
    if (!plan) {
      console.log('[MealPlan] No meal plan found for:', { goal, dietType, bmiCategory, day });
      return res.status(404).json({ error: 'No meal plan found' });
    }
    // Group meals by time (e.g., 'lunch', 'breakfast') and put them in items array
    let mealsMap = {};
    if (Array.isArray(plan.meals)) {
      for (const meal of plan.meals) {
        const key = (meal.time || '').toLowerCase();
        if (!key) continue;
        if (!mealsMap[key]) {
          mealsMap[key] = { name: key.charAt(0).toUpperCase() + key.slice(1), items: [] };
        }
        mealsMap[key].items.push(meal);
      }
    }
    // Ensure all expected meal types exist as keys
    for (const type of ['breakfast', 'lunch', 'snack', 'dinner']) {
      if (!mealsMap[type]) {
        mealsMap[type] = { name: type.charAt(0).toUpperCase() + type.slice(1), items: [] };
      }
    }
    const planObj = plan.toObject ? plan.toObject() : plan;
    planObj.meals = mealsMap;
    console.log('[MealPlan] Final response:', planObj);
    res.json(planObj);
  } catch (e) {
    console.error('[MealPlan] Error:', e);
    res.status(500).json({ error: e.message });
  }
};

// GET /api/plans/workout?goal=...&workoutSplit=...&bmiCategory=...&day=...
exports.getWorkoutPlanForUser = async (req, res) => {
  try {
    const { goal, workoutSplit, bmiCategory, day, memberId } = req.query;
    if (memberId) {
      const member = await User.findById(memberId);
      if (member && member.customWorkoutPlan) {
        return res.json(member.customWorkoutPlan);
      }
    }
    let plan = await WorkoutPlan.findOne({ goal, workoutSplit, bmiCategory, day });
    if (!plan) {
      plan = await WorkoutPlan.findOne({ day });
    }
    if (!plan && goal) {
      plan = await WorkoutPlan.findOne({ goal });
    }
    if (!plan && workoutSplit) {
      plan = await WorkoutPlan.findOne({ workoutSplit });
    }
    if (!plan && bmiCategory) {
      plan = await WorkoutPlan.findOne({ bmiCategory });
    }
    if (!plan) {
      plan = await WorkoutPlan.findOne();
    }
    if (!plan) return res.status(404).json({ error: 'No workout plan found' });
    // Group exercises by muscleGroup for frontend compatibility
    let exercisesMap = {};
    if (Array.isArray(plan.exercises)) {
      for (const ex of plan.exercises) {
        const key = (ex.muscleGroup || 'other').toLowerCase();
        if (!exercisesMap[key]) {
          exercisesMap[key] = { muscleGroup: key.charAt(0).toUpperCase() + key.slice(1), items: [] };
        }
        exercisesMap[key].items.push(ex);
      }
    }
    const planObj = plan.toObject ? plan.toObject() : plan;
    planObj.exercises = exercisesMap;
    res.json(planObj);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};

// POST /api/plans/:memberId/:type (type = 'meal' or 'workout')
exports.trainerUpdatePlan = async (req, res) => {
  try {
    const { memberId, type } = req.params;
    const planData = req.body;
    const trainer = req.user;
    const member = await User.findById(memberId);
    if (!member || !member.gymId.equals(trainer.gymId)) {
      return res.status(403).json({ error: 'Not authorized for this member' });
    }
    // Store override as a custom field on the member (could be improved)
    if (type === 'meal') {
      member.customMealPlan = planData;
    } else if (type === 'workout') {
      member.customWorkoutPlan = planData;
    } else {
      return res.status(400).json({ error: 'Invalid plan type' });
    }
    await member.save();
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
};
