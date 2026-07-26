const mongoose = require('mongoose');
const WorkoutPlanTemplate = require('../models/WorkoutPlanTemplate');
const MealPlanTemplate = require('../models/MealPlanTemplate');
const MemberProfile = require('../models/MemberProfile');
const MemberWorkoutPlan = require('../models/MemberWorkoutPlan');
const MemberMealPlan = require('../models/MemberMealPlan');
const User = require('../models/User');
const TrainerAssignment = require('../models/TrainerAssignment');

function calcTDEE(profile) {
  const { sex, age, weightKg, heightCm, daysPerWeek } = profile;
  let bmr = 10 * weightKg + 6.25 * heightCm - 5 * age;
  if (sex === 'male') bmr += 5; else bmr -= 161;
  const mult = { 3: 1.375, 4: 1.465, 5: 1.550, 6: 1.725 }[daysPerWeek] || 1.375;
  return Math.round(bmr * mult);
}

function calcTargetKcal(tdee, goal, sex) {
  let target = tdee;
  if (goal === 'lose_fat') target -= 450;
  if (goal === 'build_muscle') target += 250;
  return Math.max(target, sex === 'female' ? 1300 : 1500);
}

// Maps the ORIGINAL app-entry onboarding data (User.profile / fitnessGoals /
// workoutHabits / dietPreferences - collected once at signup via
// OnboardingFlow) onto the newer MemberProfile shape this plan-generation
// system needs. Without this, a member who already completed onboarding
// gets asked the same handful of questions again on the Plan tab, because
// the two features were built independently against separate collections.
// Returns null if the source data is too sparse to derive a valid profile -
// the caller should fall back to asking the member directly in that case.
function deriveMemberProfileFromUser(user) {
  const p = user.profile || {};
  const wh = user.workoutHabits || {};
  const dp = user.dietPreferences || {};
  const goals = user.fitnessGoals || [];

  const sex = p.gender === 'male' || p.gender === 'female' ? p.gender : null;
  const age = Number(p.age);
  const weightKg = Number(p.weight);
  const heightCm = Number(p.height);
  if (!sex || !age || !weightKg || !heightCm) return null;

  const goalMap = {
    fat_loss: 'lose_fat',
    muscle_gain: 'build_muscle',
    muscle: 'build_muscle',
    strength: 'build_muscle',
    weight_maintenance: 'maintain',
    general_fitness: 'get_fit',
    endurance: 'get_fit',
    flexibility: 'get_fit',
    performance: 'get_fit',
  };
  const goal = goalMap[goals[0]] || 'get_fit';

  const levelMap = {
    sedentary: 'beginner',
    lightly_active: 'beginner',
    moderately_active: 'intermediate',
    very_active: 'advanced',
    extremely_active: 'advanced',
  };
  const fitnessLevel = levelMap[wh.currentActivityLevel] || 'beginner';

  const rawDays = Number(wh.workoutsPerWeek) || 3;
  const daysPerWeek = [3, 4, 5, 6].reduce(
    (closest, v) => (Math.abs(v - rawDays) < Math.abs(closest - rawDays) ? v : closest),
    3,
  );

  const dietMap = {
    vegetarian: 'vegetarian',
    vegan: 'vegan',
    keto: 'keto',
    non_vegetarian: 'high_protein',
    paleo: 'high_protein',
  };
  const dietPref = dietMap[dp.type] || 'none';

  return { sex, age, weightKg, heightCm, goal, fitnessLevel, daysPerWeek, dietPref };
}

function closestBracket(target) {
  const brackets = [1400, 1600, 1800, 2000, 2200, 2400, 2600, 2800];
  return brackets.reduce((p, c) => Math.abs(c - target) < Math.abs(p - target) ? c : p);
}

function calcMacros(goal, targetKcal) {
  const r = {
    lose_fat: { p: .35, c: .35, f: .30 },
    build_muscle: { p: .30, c: .45, f: .25 },
    get_fit: { p: .25, c: .45, f: .30 },
    maintain: { p: .25, c: .45, f: .30 },
  }[goal] || { p: .25, c: .45, f: .30 };
  return {
    proteinG: Math.round(targetKcal * r.p / 4),
    carbsG: Math.round(targetKcal * r.c / 4),
    fatG: Math.round(targetKcal * r.f / 9),
  };
}

function scalePortion(portion, scale) {
  const m = String(portion).match(/^([\d.]+)(.*)$/);
  if (m) return `${Math.round(parseFloat(m[1]) * scale * 10) / 10}${m[2]}`;
  return portion;
}

function scaleMealPlan(template, scale) {
  return template.days.map(day => {
    const d = day.toObject ? day.toObject() : day;
    return {
      ...d,
      meals: d.meals.map(meal => ({
        ...meal,
        items: meal.items.map(item => ({
          name: item.name,
          portion: scalePortion(item.portion, scale),
          caloriesKcal: Math.round(item.caloriesKcal * scale),
          proteinG: Math.round(item.proteinG * scale * 10) / 10,
          carbsG: Math.round(item.carbsG * scale * 10) / 10,
          fatG: Math.round(item.fatG * scale * 10) / 10,
        }))
      }))
    };
  });
}

// Shared by saveProfile (explicit form submit) and getProfile's
// auto-derivation path (member who already onboarded elsewhere) - both need
// to end up with the same MemberProfile + MemberWorkoutPlan + MemberMealPlan
// documents, not just the profile.
async function upsertProfileAndGeneratePlans(userId, gymId, data) {
  const { sex, age, weightKg, heightCm, goal, fitnessLevel, daysPerWeek, dietPref, limitations } = data;

  const tdeeKcal = calcTDEE({ sex, age, weightKg, heightCm, daysPerWeek });
  const targetKcal = calcTargetKcal(tdeeKcal, goal, sex);

  const profile = await MemberProfile.findOneAndUpdate(
    { userId },
    {
      userId,
      gymId,
      sex,
      age,
      weightKg,
      heightCm,
      goal,
      fitnessLevel,
      daysPerWeek,
      dietPref: dietPref || 'none',
      limitations: limitations || '',
      tdeeKcal,
      targetKcal,
      onboardedAt: new Date(),
    },
    { upsert: true, new: true },
  );

  let workoutTemplate = await WorkoutPlanTemplate.findOne({ goal, fitnessLevel });
  if (!workoutTemplate) workoutTemplate = await WorkoutPlanTemplate.findOne({ goal, fitnessLevel: 'beginner' });
  if (!workoutTemplate) workoutTemplate = await WorkoutPlanTemplate.findOne({ goal: 'get_fit', fitnessLevel: 'beginner' });

  const dp = dietPref || 'none';
  let mealTemplate = await MealPlanTemplate.findOne({ goal, dietPref: dp });
  if (!mealTemplate) mealTemplate = await MealPlanTemplate.findOne({ goal, dietPref: 'none' });
  if (!mealTemplate) mealTemplate = await MealPlanTemplate.findOne({ goal: 'maintain', dietPref: 'none' });

  const calorieBracket = closestBracket(targetKcal);
  const portionScale = targetKcal / (mealTemplate?.baseCalories || 2000);
  const macros = calcMacros(goal, targetKcal);

  if (workoutTemplate) {
    const wt = workoutTemplate.toObject();
    await MemberWorkoutPlan.findOneAndUpdate(
      { userId },
      {
        userId,
        gymId,
        templateId: workoutTemplate._id,
        isModified: false,
        assignedAt: new Date(),
        goal,
        fitnessLevel,
        daysPerWeek,
        workouts: wt.workouts,
        schedules: wt.schedules,
        weeklyProgression: wt.weeklyProgression,
      },
      { upsert: true, new: true },
    );
  }

  let memberMealPlan = null;
  if (mealTemplate) {
    const scaledDays = scaleMealPlan(mealTemplate, portionScale);
    memberMealPlan = await MemberMealPlan.findOneAndUpdate(
      { userId },
      {
        userId,
        gymId,
        templateId: mealTemplate._id,
        isModified: false,
        assignedAt: new Date(),
        goal,
        dietPref: dp,
        calorieBracket,
        portionScale: Math.round(portionScale * 1000) / 1000,
        dailyCalories: Math.round(targetKcal),
        macros,
        days: scaledDays,
      },
      { upsert: true, new: true },
    );
  }

  return { profile, workoutTemplate, memberMealPlan, targetKcal, macros, daysPerWeek };
}

// POST /api/member/me/profile
exports.saveProfile = async (req, res) => {
  try {
    const { sex, age, weightKg, heightCm, goal, fitnessLevel, daysPerWeek, dietPref, limitations } = req.body;
    const userId = req.user._id || req.user.id;
    const gymId = req.user.gymId;

    if (!sex || !age || !weightKg || !heightCm || !goal || !fitnessLevel || !daysPerWeek) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const { profile, workoutTemplate, memberMealPlan, targetKcal, macros } =
      await upsertProfileAndGeneratePlans(userId, gymId, {
        sex,
        age: Number(age),
        weightKg: Number(weightKg),
        heightCm: Number(heightCm),
        goal,
        fitnessLevel,
        daysPerWeek: Number(daysPerWeek),
        dietPref,
        limitations,
      });

    res.json({
      profile,
      workoutPlan: workoutTemplate ? { name: workoutTemplate.name, daysPerWeek: Number(daysPerWeek) } : null,
      mealPlan: memberMealPlan ? { dailyCalories: Math.round(targetKcal), macros } : null,
    });
  } catch (err) {
    console.error('saveProfile error:', err);
    res.status(500).json({ message: err.message });
  }
};

// GET /api/member/me/profile
exports.getProfile = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    let profile = await MemberProfile.findOne({ userId });

    if (!profile) {
      // No dedicated MemberProfile yet - before asking the member to
      // re-enter data they already gave during their original onboarding,
      // try to derive one from it so "Build my plan" can skip straight to
      // plan generation instead of showing a redundant mini-onboarding form.
      const user = await User.findById(userId);
      const derived = user ? deriveMemberProfileFromUser(user) : null;
      if (derived) {
        ({ profile } = await upsertProfileAndGeneratePlans(userId, user.gymId, derived));
      }
    }

    if (!profile) return res.status(404).json({ message: 'Profile not found' });
    res.json({ profile });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Shared self-healing helper: if a member's User has enough data to derive a
// MemberProfile but the plan doc requested hasn't been generated yet (e.g.
// a parallel request beat getProfile's own derivation to the punch), derive
// the profile and generate plans here too, so each endpoint is independently
// self-healing regardless of call order. Returns null if derivation truly
// isn't possible (sparse User data) - callers should 404 in that case.
async function ensureProfileAndPlans(userId) {
  const user = await User.findById(userId);
  const derived = user ? deriveMemberProfileFromUser(user) : null;
  if (!derived) return null;
  return upsertProfileAndGeneratePlans(userId, user.gymId, derived);
}

// GET /api/member/me/workout-plan
exports.getWorkoutPlan = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    let plan = await MemberWorkoutPlan.findOne({ userId });
    if (!plan) {
      const result = await ensureProfileAndPlans(userId);
      if (result) {
        plan = await MemberWorkoutPlan.findOne({ userId });
      }
    }
    if (!plan) return res.status(404).json({ message: 'No workout plan assigned. Complete your profile first.' });
    res.json({ workoutPlan: plan });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/member/me/meal-plan
exports.getMealPlan = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    let plan = await MemberMealPlan.findOne({ userId });
    if (!plan) {
      const result = await ensureProfileAndPlans(userId);
      if (result) {
        plan = await MemberMealPlan.findOne({ userId });
      }
    }
    if (!plan) return res.status(404).json({ message: 'No meal plan assigned. Complete your profile first.' });
    res.json({ mealPlan: plan });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// PUT /api/trainer/members/:memberId/workout-plan
exports.trainerUpdateWorkoutPlan = async (req, res) => {
  try {
    const { memberId } = req.params;
    const trainerId = req.user._id || req.user.id;
    const assignment = await TrainerAssignment.findOne({ trainerId, memberId, status: 'active' });
    if (!assignment) return res.status(403).json({ message: 'Not assigned to this member' });
    const member = await User.findById(memberId);
    if (!member) return res.status(404).json({ message: 'Member not found' });
    const plan = await MemberWorkoutPlan.findOneAndUpdate(
      { userId: memberId },
      {
        ...req.body,
        userId: memberId,
        gymId: member.gymId,
        isModified: true,
        modifiedBy: trainerId,
        modifiedAt: new Date(),
      },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
    res.json({ workoutPlan: plan });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// PUT /api/trainer/members/:memberId/meal-plan
exports.trainerUpdateMealPlan = async (req, res) => {
  try {
    const { memberId } = req.params;
    const trainerId = req.user._id || req.user.id;
    const assignment = await TrainerAssignment.findOne({ trainerId, memberId, status: 'active' });
    if (!assignment) return res.status(403).json({ message: 'Not assigned to this member' });
    const member = await User.findById(memberId);
    if (!member) return res.status(404).json({ message: 'Member not found' });
    const plan = await MemberMealPlan.findOneAndUpdate(
      { userId: memberId },
      {
        ...req.body,
        userId: memberId,
        gymId: member.gymId,
        isModified: true,
        modifiedBy: trainerId,
        modifiedAt: new Date(),
      },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
    res.json({ mealPlan: plan });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
