require('dotenv').config();
const path = require('path');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const MealPlan = require('../models/mealPlan');
const WorkoutPlan = require('../models/workoutPlan');
const mealPlans = require(path.join(__dirname, '..', 'seed', 'seed_mealPlans.json'));
const workoutPlans = require(path.join(__dirname, '..', 'seed', 'seed_workoutPlans.json'));

const MONGODB_URI =
  process.env.MONGODB_URI ||
  process.env.MONGO_URI ||
  'mongodb://127.0.0.1:27017/gymmate_qa';

const QA_EMAILS = [
  'qa_superadmin@gymmate.local',
  'qa_owner_iron@gymmate.local',
  'qa_trainer_iron@gymmate.local',
  'qa_member_iron@gymmate.local',
  'qa_owner_flow@gymmate.local',
  'qa_member_flow@gymmate.local',
  'qa_owner_empty@gymmate.local',
];

const QA_GYM_NAMES = ['QA Iron Temple', 'QA Flow Studio', 'QA Empty Club'];
const QA_INVITE_PREFIX = 'QA';

function onboardingBundle(overrides = {}) {
  return {
    onboardingProgress: {
      isCompleted: true,
      currentStep: 7,
      stepsCompleted: [1, 2, 3, 4, 5, 6, 7],
      startedAt: new Date(),
      completedAt: new Date(),
      totalSteps: 7,
    },
    hasCompletedOnboarding: true,
    profile: {
      age: 29,
      gender: 'male',
      weight: 78,
      height: 178,
      avatar: 'default_user.png',
      bio: 'Consistent work beats occasional intensity.',
    },
    fitnessGoals: ['muscle_gain', 'strength'],
    dietPreferences: {
      type: 'flexible',
      allergies: [],
      dailyMeals: 4,
      waterIntake: 8,
      restrictions: [],
    },
    workoutHabits: {
      preferredTime: 'evening',
      favoriteExercises: ['weight_training', 'cardio'],
      currentActivityLevel: 'moderately_active',
      workoutsPerWeek: 5,
      sessionDuration: 75,
      hasInjuries: false,
      injuryDetails: null,
      split: 'Full Body',
    },
    firstChallenge: {
      isAccepted: true,
      type: '7_day_checkin',
      startDate: new Date(),
      endDate: null,
      progress: 100,
      isCompleted: true,
      completedAt: new Date(),
    },
    ...overrides,
  };
}

async function ensurePlanTemplates() {
  const mealCount = await MealPlan.countDocuments();
  const workoutCount = await WorkoutPlan.countDocuments();

  if (!mealCount) {
    await MealPlan.insertMany(mealPlans);
  }
  if (!workoutCount) {
    await WorkoutPlan.insertMany(workoutPlans);
  }
}

async function deleteExistingQaData() {
  const gyms = await Gym.find({ gymName: { $in: QA_GYM_NAMES } }).select('_id');
  const gymIds = gyms.map((gym) => gym._id);

  await InviteCode.deleteMany({
    $or: [
      { code: new RegExp(`^${QA_INVITE_PREFIX}`) },
      { gymName: { $in: QA_GYM_NAMES } },
      ...(gymIds.length ? [{ gymId: { $in: gymIds } }] : []),
    ],
  });

  await User.deleteMany({
    $or: [
      { email: { $in: QA_EMAILS } },
      { phone_number: { $in: ['5550001001', '5550001002', '5550002001'] } },
      ...(gymIds.length ? [{ gymId: { $in: gymIds } }] : []),
    ],
  });

  await Gym.deleteMany({
    $or: [{ gymName: { $in: QA_GYM_NAMES } }, { email: { $in: QA_EMAILS } }],
  });
}

async function createGymWithOwner({ gymName, email, password, address, contactNumber, services, branding }) {
  const hashedGymPassword = await bcrypt.hash(password, 10);
  const gym = await Gym.create({
    gymName,
    email,
    password: hashedGymPassword,
    address,
    contactNumber,
    services,
    branding,
    role: 'gym_owner',
  });

  const owner = await User.create({
    name: gymName,
    email,
    password,
    role: 'gym_owner',
    gymId: gym._id,
    phone_number: contactNumber,
  });

  gym.owner = owner._id;
  await gym.save();

  return { gym, owner };
}

async function seedQaData() {
  await mongoose.connect(MONGODB_URI);
  console.log(`Connected to ${MONGODB_URI}`);

  await ensurePlanTemplates();
  await deleteExistingQaData();

  const iron = await createGymWithOwner({
    gymName: 'QA Iron Temple',
    email: 'qa_owner_iron@gymmate.local',
    password: 'QaOwner123!',
    address: '101 Iron Lane, Brooklyn',
    contactNumber: '5550001001',
    services: ['Strength', 'Conditioning', 'Recovery'],
    branding: {
      logoUrl: null,
      primaryColor: '#B59F5B',
      secondaryColor: '#F8D84B',
      logoScale: 1,
      logoOffsetX: 0,
      logoOffsetY: 0,
    },
  });

  const flow = await createGymWithOwner({
    gymName: 'QA Flow Studio',
    email: 'qa_owner_flow@gymmate.local',
    password: 'QaOwner123!',
    address: '22 Flow Street, Manhattan',
    contactNumber: '5550002001',
    services: ['Yoga', 'Pilates'],
    branding: {
      logoUrl: null,
      primaryColor: '#7F9C8B',
      secondaryColor: '#E6D8A7',
      logoScale: 1,
      logoOffsetX: 0,
      logoOffsetY: 0,
    },
  });

  const empty = await createGymWithOwner({
    gymName: 'QA Empty Club',
    email: 'qa_owner_empty@gymmate.local',
    password: 'QaOwner123!',
    address: '5 Quiet Ave, Queens',
    contactNumber: '5550003001',
    services: [],
    branding: {
      logoUrl: null,
      primaryColor: '#B59F5B',
      secondaryColor: '#F8D84B',
      logoScale: 1,
      logoOffsetX: 0,
      logoOffsetY: 0,
    },
  });

  const trainer = await User.create({
    name: 'QA Coach Mason',
    email: 'qa_trainer_iron@gymmate.local',
    password: 'QaTrainer123!',
    role: 'gym_trainer',
    gymId: iron.gym._id,
    phone_number: '5550001002',
  });

  const member = await User.create({
    name: 'QA Member Riley',
    email: 'qa_member_iron@gymmate.local',
    password: 'QaMember123!',
    role: 'gym_member',
    gymId: iron.gym._id,
    phone_number: '5550001003',
    ...onboardingBundle(),
  });

  const flowMember = await User.create({
    name: 'QA Member Skye',
    email: 'qa_member_flow@gymmate.local',
    password: 'QaMember123!',
    role: 'gym_member',
    gymId: flow.gym._id,
    phone_number: '5550002002',
    ...onboardingBundle({
      profile: {
        age: 32,
        gender: 'female',
        weight: 61,
        height: 167,
        avatar: 'default_user.png',
        bio: 'Steady movement, strong recovery.',
      },
      fitnessGoals: ['flexibility', 'general_fitness'],
      dietPreferences: {
        type: 'vegetarian',
        allergies: [],
        dailyMeals: 3,
        waterIntake: 8,
        restrictions: [],
      },
      workoutHabits: {
        preferredTime: 'morning',
        favoriteExercises: ['yoga', 'cardio'],
        currentActivityLevel: 'lightly_active',
        workoutsPerWeek: 4,
        sessionDuration: 60,
        hasInjuries: false,
        injuryDetails: null,
        split: 'Full Body',
      },
    }),
  });

  const superadmin = await User.create({
    name: 'QA Superadmin',
    email: 'qa_superadmin@gymmate.local',
    password: 'QaAdmin123!',
    role: 'superadmin',
  });

  await InviteCode.insertMany([
    {
      code: 'QAMEMBER1',
      role: 'gym_member',
      gymId: iron.gym._id,
      gymName: iron.gym.gymName,
      used: false,
      usedBy: null,
    },
    {
      code: 'QATRAINR1',
      role: 'gym_trainer',
      gymId: iron.gym._id,
      gymName: iron.gym.gymName,
      used: false,
      usedBy: null,
    },
    {
      code: 'QAOWNER01',
      role: 'gym_owner',
      gymId: null,
      gymName: null,
      used: false,
      usedBy: null,
    },
  ]);

  console.log('QA seed complete');
  console.log(JSON.stringify({
    superadmin: { email: superadmin.email, password: 'QaAdmin123!' },
    owner: { email: iron.owner.email, password: 'QaOwner123!' },
    trainer: { email: trainer.email, password: 'QaTrainer123!' },
    member: { email: member.email, password: 'QaMember123!', phone: member.phone_number, quickJoinOtp: '1234' },
    flowOwner: { email: flow.owner.email, password: 'QaOwner123!' },
    emptyOwner: { email: empty.owner.email, password: 'QaOwner123!' },
    inviteCodes: ['QAMEMBER1', 'QATRAINR1', 'QAOWNER01'],
  }, null, 2));

  await mongoose.disconnect();
}

seedQaData().catch((error) => {
  console.error(error);
  process.exit(1);
});
