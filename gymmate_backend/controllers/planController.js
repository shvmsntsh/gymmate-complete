const MealPlan = require('../models/mealPlan');
const WorkoutPlan = require('../models/workoutPlan');
const User = require('../models/User');
const TrainerAssignment = require('../models/TrainerAssignment');
const { hasRole } = require('../utils/roles');

const DEFAULT_MEAL_TYPES = ['breakfast', 'lunch', 'snack', 'dinner'];

function normalizeGoal(goal) {
  const allowed = new Set([
    'muscle_gain',
    'fat_loss',
    'endurance',
    'general_fitness',
    'strength',
    'performance',
  ]);
  return allowed.has(goal) ? goal : 'general_fitness';
}

function normalizeDietType(type) {
  const allowed = new Set([
    'flexible',
    'vegetarian',
    'non_vegetarian',
    'keto',
    'vegan',
    'high_protein',
    'low_carb',
  ]);
  return allowed.has(type) ? type : 'flexible';
}

function normalizeWorkoutSplit(split) {
  const allowed = new Set(['PPL', 'Bro Split', 'Full Body']);
  return allowed.has(split) ? split : 'Full Body';
}

function deriveDayLabel(value = new Date()) {
  return value.toLocaleDateString('en-US', {
    weekday: 'long',
    timeZone: 'UTC',
  });
}

function deriveBmiCategory(member) {
  const weight = Number(member?.profile?.weight || 0);
  const heightCm = Number(member?.profile?.height || 0);
  if (!weight || !heightCm) return 'normal';
  const heightM = heightCm / 100;
  const bmi = weight / (heightM * heightM);
  if (!Number.isFinite(bmi)) return 'normal';
  if (bmi < 18.5) return 'underweight';
  if (bmi < 25) return 'normal';
  if (bmi < 30) return 'overweight';
  return 'obese';
}

function deriveWorkoutSplit(member) {
  const workoutsPerWeek = Number(member?.workoutHabits?.workoutsPerWeek || 0);
  if (workoutsPerWeek >= 5) return 'PPL';
  if (workoutsPerWeek >= 4) return 'Bro Split';
  return 'Full Body';
}

function groupMealsByTime(plan) {
  const planObj = plan?.toObject ? plan.toObject() : plan;
  const mealsMap = {};

  if (Array.isArray(planObj?.meals)) {
    for (const meal of planObj.meals) {
      const key = (meal.time || '').toLowerCase();
      if (!key) continue;
      if (!mealsMap[key]) {
        mealsMap[key] = {
          name: key.charAt(0).toUpperCase() + key.slice(1),
          items: [],
        };
      }
      mealsMap[key].items.push(meal);
    }
  }

  for (const type of DEFAULT_MEAL_TYPES) {
    if (!mealsMap[type]) {
      mealsMap[type] = {
        name: type.charAt(0).toUpperCase() + type.slice(1),
        items: [],
      };
    }
  }

  return {
    ...(planObj || {}),
    meals: mealsMap,
  };
}

function groupExercisesByMuscleGroup(plan) {
  const planObj = plan?.toObject ? plan.toObject() : plan;
  const exercisesMap = {};

  if (Array.isArray(planObj?.exercises)) {
    for (const exercise of planObj.exercises) {
      const key = (exercise.muscleGroup || 'other').toLowerCase();
      if (!exercisesMap[key]) {
        exercisesMap[key] = {
          muscleGroup: key.charAt(0).toUpperCase() + key.slice(1),
          items: [],
        };
      }
      exercisesMap[key].items.push(exercise);
    }
  }

  return {
    ...(planObj || {}),
    exercises: exercisesMap,
  };
}

async function findMealPlan({ goal, dietType, bmiCategory, day }) {
  let plan = await MealPlan.findOne({ goal, dietType, bmiCategory, day });
  if (!plan) {
    plan = await MealPlan.findOne({ goal, dietType, bmiCategory });
  }
  if (!plan) {
    plan = await MealPlan.findOne({ goal, dietType, day });
  }
  if (!plan) {
    plan = await MealPlan.findOne({ goal, day });
  }
  if (!plan) {
    plan = await MealPlan.findOne({ day });
  }
  if (!plan && goal) {
    plan = await MealPlan.findOne({ goal });
  }
  if (!plan && dietType) {
    plan = await MealPlan.findOne({ dietType });
  }
  if (!plan) {
    plan = await MealPlan.findOne();
  }
  return plan;
}

async function findWorkoutPlan({ goal, workoutSplit, bmiCategory, day }) {
  let plan = await WorkoutPlan.findOne({ goal, workoutSplit, bmiCategory, day });
  if (!plan) {
    plan = await WorkoutPlan.findOne({ goal, workoutSplit, bmiCategory });
  }
  if (!plan) {
    plan = await WorkoutPlan.findOne({ goal, workoutSplit, day });
  }
  if (!plan) {
    plan = await WorkoutPlan.findOne({ goal, day });
  }
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
  return plan;
}

async function resolveMember(memberOrId) {
  if (memberOrId && typeof memberOrId === 'object' && memberOrId._id) {
    return memberOrId;
  }
  if (!memberOrId) return null;
  return User.findById(memberOrId)
    .select(
      'fitnessGoals dietPreferences workoutHabits profile customMealPlan customWorkoutPlan',
    )
    .lean();
}

function idsEqual(first, second) {
  if (!first || !second) {
    return false;
  }
  return String(first) === String(second);
}

async function userCanAccessMemberPlan(requester, member) {
  if (!requester || !member) {
    return false;
  }

  if (hasRole(requester, ['member'])) {
    return idsEqual(requester._id || requester.id, member._id);
  }

  if (hasRole(requester, ['owner', 'staff'])) {
    return idsEqual(requester.gymId, member.gymId);
  }

  if (hasRole(requester, ['trainer'])) {
    if (!idsEqual(requester.gymId, member.gymId)) {
      return false;
    }
    const assignment = await TrainerAssignment.findOne({
      gymId: requester.gymId,
      trainerId: requester._id || requester.id,
      memberId: member._id,
      status: 'active',
    }).select('_id');
    return Boolean(assignment);
  }

  return false;
}

async function loadAuthorizedMember(req, memberId) {
  const member = await User.findById(memberId)
    .select(
      'role gymId fitnessGoals dietPreferences workoutHabits profile customMealPlan customWorkoutPlan',
    )
    .lean();

  if (!member || member.role !== 'gym_member') {
    return { status: 404, error: 'Member not found' };
  }

  const allowed = await userCanAccessMemberPlan(req.user, member);
  if (!allowed) {
    return { status: 403, error: 'Not authorized for this member' };
  }

  return { member };
}

async function loadMealPlanForMember(memberOrId) {
  const member = await resolveMember(memberOrId);
  if (member?.customMealPlan) {
    return member.customMealPlan;
  }

  const plan = await findMealPlan({
    goal: normalizeGoal(member?.fitnessGoals?.[0]),
    dietType: normalizeDietType(member?.dietPreferences?.type),
    bmiCategory: deriveBmiCategory(member),
    day: deriveDayLabel(),
  });

  return plan ? groupMealsByTime(plan) : null;
}

async function loadWorkoutPlanForMember(memberOrId) {
  const member = await resolveMember(memberOrId);
  if (member?.customWorkoutPlan) {
    return member.customWorkoutPlan;
  }

  const plan = await findWorkoutPlan({
    goal: normalizeGoal(member?.fitnessGoals?.[0]),
    workoutSplit: normalizeWorkoutSplit(deriveWorkoutSplit(member)),
    bmiCategory: deriveBmiCategory(member),
    day: deriveDayLabel(),
  });

  return plan ? groupExercisesByMuscleGroup(plan) : null;
}

// GET /api/plans/meal?goal=...&dietType=...&bmiCategory=...&day=...
exports.getMealPlanForUser = async (req, res) => {
  try {
    const { goal, dietType, bmiCategory, day, memberId } = req.query;
    console.log('[MealPlan] Incoming query:', { goal, dietType, bmiCategory, day, memberId });
    if (memberId) {
      const access = await loadAuthorizedMember(req, memberId);
      if (!access.member) {
        return res.status(access.status).json({ error: access.error });
      }
      const resolvedPlan = await loadMealPlanForMember(access.member);
      if (resolvedPlan) {
        console.log('[MealPlan] Returning resolved meal plan for member:', memberId);
        return res.json(resolvedPlan);
      }
    }
    let plan = await findMealPlan({ goal, dietType, bmiCategory, day });
    console.log('[MealPlan] Plan found for query:', plan);
    if (!plan) {
      console.log('[MealPlan] No meal plan found for:', { goal, dietType, bmiCategory, day });
      return res.status(404).json({ error: 'No meal plan found' });
    }
    const planObj = groupMealsByTime(plan);
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
      const access = await loadAuthorizedMember(req, memberId);
      if (!access.member) {
        return res.status(access.status).json({ error: access.error });
      }
      const resolvedPlan = await loadWorkoutPlanForMember(access.member);
      if (resolvedPlan) {
        return res.json(resolvedPlan);
      }
    }
    let plan = await findWorkoutPlan({ goal, workoutSplit, bmiCategory, day });
    if (!plan) return res.status(404).json({ error: 'No workout plan found' });
    const planObj = groupExercisesByMuscleGroup(plan);
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
    if (!member || member.role !== 'gym_member' || !idsEqual(member.gymId, trainer.gymId)) {
      return res.status(403).json({ error: 'Not authorized for this member' });
    }

    if (hasRole(trainer, ['trainer'])) {
      const assignment = await TrainerAssignment.findOne({
        gymId: trainer.gymId,
        trainerId: trainer._id || trainer.id,
        memberId: member._id,
        status: 'active',
      }).select('_id');
      if (!assignment) {
        return res.status(403).json({ error: 'Not authorized for this member' });
      }
    } else if (!hasRole(trainer, ['owner', 'staff'])) {
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

exports.loadMealPlanForMember = loadMealPlanForMember;
exports.loadWorkoutPlanForMember = loadWorkoutPlanForMember;
