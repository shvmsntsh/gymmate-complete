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

// POST /api/member/me/profile
exports.saveProfile = async (req, res) => {
  try {
    const { sex, age, weightKg, heightCm, goal, fitnessLevel, daysPerWeek, dietPref, limitations } = req.body;
    const userId = req.user._id || req.user.id;
    const gymId = req.user.gymId;

    if (!sex || !age || !weightKg || !heightCm || !goal || !fitnessLevel || !daysPerWeek) {
      return res.status(400).json({ message: 'Missing required fields' });
    }

    const tdeeKcal = calcTDEE({
      sex,
      age: Number(age),
      weightKg: Number(weightKg),
      heightCm: Number(heightCm),
      daysPerWeek: Number(daysPerWeek),
    });
    const targetKcal = calcTargetKcal(tdeeKcal, goal, sex);

    const profile = await MemberProfile.findOneAndUpdate(
      { userId },
      {
        userId,
        gymId,
        sex,
        age: Number(age),
        weightKg: Number(weightKg),
        heightCm: Number(heightCm),
        goal,
        fitnessLevel,
        daysPerWeek: Number(daysPerWeek),
        dietPref: dietPref || 'none',
        limitations: limitations || '',
        tdeeKcal,
        targetKcal,
        onboardedAt: new Date(),
      },
      { upsert: true, new: true }
    );

    // Find workout template
    let workoutTemplate = await WorkoutPlanTemplate.findOne({ goal, fitnessLevel });
    if (!workoutTemplate) workoutTemplate = await WorkoutPlanTemplate.findOne({ goal, fitnessLevel: 'beginner' });
    if (!workoutTemplate) workoutTemplate = await WorkoutPlanTemplate.findOne({ goal: 'get_fit', fitnessLevel: 'beginner' });

    // Find meal template
    const dp = dietPref || 'none';
    let mealTemplate = await MealPlanTemplate.findOne({ goal, dietPref: dp });
    if (!mealTemplate) mealTemplate = await MealPlanTemplate.findOne({ goal, dietPref: 'none' });
    if (!mealTemplate) mealTemplate = await MealPlanTemplate.findOne({ goal: 'maintain', dietPref: 'none' });

    const calorieBracket = closestBracket(targetKcal);
    const portionScale = targetKcal / (mealTemplate?.baseCalories || 2000);
    const macros = calcMacros(goal, targetKcal);

    // Clone and upsert workout plan
    let memberWorkoutPlan = null;
    if (workoutTemplate) {
      const wt = workoutTemplate.toObject();
      memberWorkoutPlan = await MemberWorkoutPlan.findOneAndUpdate(
        { userId },
        {
          userId,
          gymId,
          templateId: workoutTemplate._id,
          isModified: false,
          assignedAt: new Date(),
          goal,
          fitnessLevel,
          daysPerWeek: Number(daysPerWeek),
          workouts: wt.workouts,
          schedules: wt.schedules,
          weeklyProgression: wt.weeklyProgression,
        },
        { upsert: true, new: true }
      );
    }

    // Clone, scale, and upsert meal plan
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
        { upsert: true, new: true }
      );
    }

    res.json({
      profile,
      workoutPlan: workoutTemplate ? { name: workoutTemplate.name, daysPerWeek } : null,
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
    const profile = await MemberProfile.findOne({ userId });
    if (!profile) return res.status(404).json({ message: 'Profile not found' });
    res.json({ profile });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// GET /api/member/me/workout-plan
exports.getWorkoutPlan = async (req, res) => {
  try {
    const userId = req.user._id || req.user.id;
    const plan = await MemberWorkoutPlan.findOne({ userId });
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
    const plan = await MemberMealPlan.findOne({ userId });
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
    const plan = await MemberWorkoutPlan.findOneAndUpdate(
      { userId: memberId },
      { ...req.body, isModified: true, modifiedBy: trainerId, modifiedAt: new Date() },
      { new: true }
    );
    if (!plan) return res.status(404).json({ message: 'Member has no workout plan yet' });
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
    const plan = await MemberMealPlan.findOneAndUpdate(
      { userId: memberId },
      { ...req.body, isModified: true, modifiedBy: trainerId, modifiedAt: new Date() },
      { new: true }
    );
    if (!plan) return res.status(404).json({ message: 'Member has no meal plan yet' });
    res.json({ mealPlan: plan });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
