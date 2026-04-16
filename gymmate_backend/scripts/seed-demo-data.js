require('dotenv').config();
const path = require('path');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const MealPlan = require('../models/mealPlan');
const WorkoutPlan = require('../models/workoutPlan');
const MembershipTemplate = require('../models/MembershipTemplate');
const MemberMembership = require('../models/MemberMembership');
const MembershipChangeRequest = require('../models/MembershipChangeRequest');
const MembershipAuditLog = require('../models/MembershipAuditLog');
const mealPlans = require(path.join(__dirname, '..', 'seed', 'seed_mealPlans.json'));
const workoutPlans = require(path.join(__dirname, '..', 'seed', 'seed_workoutPlans.json'));

const MONGODB_URI =
  process.env.MONGODB_URI ||
  process.env.MONGO_URI ||
  'mongodb://127.0.0.1:27017/gymmate';

const DEMO_USERS = {
  admin: { email: 'demo_admin@gymmate.local', password: 'DemoAdmin123!' },
  ownerIron: { email: 'demo_owner_iron@gymmate.local', password: 'DemoOwner123!' },
  trainerIron: { email: 'demo_trainer_iron@gymmate.local', password: 'DemoTrainer123!' },
  memberIron: {
    email: 'demo_member_iron@gymmate.local',
    password: 'DemoMember123!',
    phone: '5551001003',
  },
  ownerFlow: { email: 'demo_owner_flow@gymmate.local', password: 'DemoOwner123!' },
  memberFlow: {
    email: 'demo_member_flow@gymmate.local',
    password: 'DemoMember123!',
    phone: '5552001002',
  },
  ownerQuiet: { email: 'demo_owner_quiet@gymmate.local', password: 'DemoOwner123!' },
};

const DEMO_GYMS = {
  iron: 'Demo Iron Temple',
  flow: 'Demo Flow Studio',
  quiet: 'Demo Quiet Club',
};

const DEMO_CODES = ['DEMOUSED1', 'DEMOUSED2'];

function gymInitials(name) {
  const parts = String(name)
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (!parts.length) return 'GM';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

function buildInitialsLogoDataUri(gymName, palette = {}) {
  const initials = gymInitials(gymName);
  const bg = palette.primaryColor || '#B59F5B';
  const accent = palette.secondaryColor || '#F8D84B';
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
      <defs>
        <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="${bg}" />
          <stop offset="100%" stop-color="${accent}" />
        </linearGradient>
      </defs>
      <rect width="512" height="512" rx="128" fill="url(#g)" />
      <rect x="28" y="28" width="456" height="456" rx="112" fill="none" stroke="rgba(255,255,255,0.42)" stroke-width="14" />
      <text x="50%" y="55%" text-anchor="middle" dominant-baseline="middle" font-family="Arial, Helvetica, sans-serif" font-size="188" font-weight="700" fill="#231F16">${initials}</text>
    </svg>
  `.trim();

  return `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
}

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
      bio: 'Strong habits, steady sessions, and simple routines.',
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

async function deleteExistingDemoData() {
  const demoEmails = Object.values(DEMO_USERS).map((user) => user.email);
  const demoPhones = Object.values(DEMO_USERS)
    .map((user) => user.phone)
    .filter(Boolean);
  const demoGymNames = Object.values(DEMO_GYMS);

  const gyms = await Gym.find({ gymName: { $in: demoGymNames } }).select('_id');
  const gymIds = gyms.map((gym) => gym._id);
  
  const users = await User.find({ 
    $or: [
      { email: { $in: demoEmails } },
      { phone_number: { $in: demoPhones } },
      ...(gymIds.length ? [{ gymId: { $in: gymIds } }] : []),
    ]
  }).select('_id');
  const userIds = users.map(u => u._id);

  await InviteCode.deleteMany({
    $or: [
      { code: { $in: DEMO_CODES } },
      { gymName: { $in: demoGymNames } },
      ...(gymIds.length ? [{ gymId: { $in: gymIds } }] : []),
    ],
  });

  if (userIds.length > 0) {
    await MemberMembership.deleteMany({ memberId: { $in: userIds } });
    await MembershipChangeRequest.deleteMany({ memberId: { $in: userIds } });
    await MembershipAuditLog.deleteMany({ memberId: { $in: userIds } });
  }

  await User.deleteMany({
    $or: [
      { email: { $in: demoEmails } },
      { phone_number: { $in: demoPhones } },
      ...(gymIds.length ? [{ gymId: { $in: gymIds } }] : []),
    ],
  });

  await Gym.deleteMany({
    $or: [{ gymName: { $in: demoGymNames } }, { email: { $in: demoEmails } }],
  });
}

async function createGymWithOwner({
  gymName,
  email,
  password,
  address,
  contactNumber,
  services,
  branding,
}) {
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

async function seedDemoData() {
  await mongoose.connect(MONGODB_URI);

  await ensurePlanTemplates();
  await deleteExistingDemoData();

  const iron = await createGymWithOwner({
    gymName: DEMO_GYMS.iron,
    email: DEMO_USERS.ownerIron.email,
    password: DEMO_USERS.ownerIron.password,
    address: '101 Barbell Avenue, Brooklyn',
    contactNumber: '5551001001',
    services: ['Strength', 'Conditioning', 'Recovery'],
    branding: {
      primaryColor: '#B59F5B',
      secondaryColor: '#F8D84B',
      logoUrl: buildInitialsLogoDataUri(DEMO_GYMS.iron, {
        primaryColor: '#B59F5B',
        secondaryColor: '#F8D84B',
      }),
      logoScale: 1,
      logoOffsetX: 0,
      logoOffsetY: 0,
    },
  });

  const flow = await createGymWithOwner({
    gymName: DEMO_GYMS.flow,
    email: DEMO_USERS.ownerFlow.email,
    password: DEMO_USERS.ownerFlow.password,
    address: '22 Flow Street, Manhattan',
    contactNumber: '5552001001',
    services: ['Yoga', 'Pilates', 'Mobility'],
    branding: {
      primaryColor: '#7F9C8B',
      secondaryColor: '#E6D8A7',
      logoUrl: buildInitialsLogoDataUri(DEMO_GYMS.flow, {
        primaryColor: '#7F9C8B',
        secondaryColor: '#E6D8A7',
      }),
      logoScale: 1,
      logoOffsetX: 0,
      logoOffsetY: 0,
    },
  });

  const quiet = await createGymWithOwner({
    gymName: DEMO_GYMS.quiet,
    email: DEMO_USERS.ownerQuiet.email,
    password: DEMO_USERS.ownerQuiet.password,
    address: '5 Quiet Avenue, Queens',
    contactNumber: '5553001001',
    services: [],
    branding: {
      primaryColor: '#6E5D54',
      secondaryColor: '#D7C2A3',
      logoUrl: buildInitialsLogoDataUri(DEMO_GYMS.quiet, {
        primaryColor: '#6E5D54',
        secondaryColor: '#D7C2A3',
      }),
      logoScale: 1,
      logoOffsetX: 0,
      logoOffsetY: 0,
    },
  });

  const trainer = await User.create({
    name: 'Demo Coach Mason',
    email: DEMO_USERS.trainerIron.email,
    password: DEMO_USERS.trainerIron.password,
    role: 'gym_trainer',
    gymId: iron.gym._id,
    phone_number: '5551001002',
  });

  const member = await User.create({
    name: 'Demo Member Riley',
    email: DEMO_USERS.memberIron.email,
    password: DEMO_USERS.memberIron.password,
    role: 'gym_member',
    gymId: iron.gym._id,
    phone_number: DEMO_USERS.memberIron.phone,
    ...onboardingBundle(),
  });

  const ironTemplates = await MembershipTemplate.insertMany([
    {
      gymId: iron.gym._id,
      createdBy: iron.owner._id,
      name: 'Trial Pass',
      shortDescription: '7-day access to try everything',
      fullDescription: 'Get full access to gym facilities, classes, and trainer support for one week.',
      durationDays: 7,
      price: 0,
      joiningFee: 0,
      renewalLeadDays: 3,
      active: true,
      visibleToMembers: true,
      sortOrder: 1,
      upgradeRank: 0,
      category: 'trial',
      includedFeatures: {
        gymAccess: true,
        classAccess: false,
        trainerSupport: true,
        dietSupport: false,
        biometricAccess: false,
        lockerAccess: false,
        guestPasses: 0,
      },
      availableAddOns: {
        personalTraining: false,
        dietPlan: false,
      },
      rules: {
        canUpgrade: true,
        canDowngrade: false,
        canFreeze: false,
        freezeLimitDays: 0,
        requiresOwnerApproval: false,
        prorationMode: 'none',
        paymentModesAllowed: ['cash', 'upi', 'card', 'online', 'manual'],
      },
    },
    {
      gymId: iron.gym._id,
      createdBy: iron.owner._id,
      name: 'Monthly Basic',
      shortDescription: 'Essential gym access',
      fullDescription: 'Perfect for getting started. Includes gym access and locker.',
      durationDays: 30,
      price: 1500,
      joiningFee: 500,
      renewalLeadDays: 7,
      active: true,
      visibleToMembers: true,
      sortOrder: 2,
      upgradeRank: 1,
      category: 'monthly',
      includedFeatures: {
        gymAccess: true,
        classAccess: false,
        trainerSupport: false,
        dietSupport: false,
        biometricAccess: true,
        lockerAccess: true,
        guestPasses: 0,
      },
      availableAddOns: {
        personalTraining: true,
        dietPlan: true,
      },
      rules: {
        canUpgrade: true,
        canDowngrade: false,
        canFreeze: true,
        freezeLimitDays: 15,
        requiresOwnerApproval: true,
        prorationMode: 'credit_remaining_days',
        paymentModesAllowed: ['cash', 'upi', 'card', 'online', 'manual'],
      },
    },
    {
      gymId: iron.gym._id,
      createdBy: iron.owner._id,
      name: 'Monthly Premium',
      shortDescription: 'Full access with classes',
      fullDescription: 'Everything in Basic plus class access and trainer consultations.',
      durationDays: 30,
      price: 2500,
      joiningFee: 500,
      renewalLeadDays: 7,
      active: true,
      visibleToMembers: true,
      sortOrder: 3,
      upgradeRank: 2,
      category: 'monthly',
      includedFeatures: {
        gymAccess: true,
        classAccess: true,
        trainerSupport: true,
        dietSupport: false,
        biometricAccess: true,
        lockerAccess: true,
        guestPasses: 2,
      },
      availableAddOns: {
        personalTraining: true,
        dietPlan: true,
      },
      rules: {
        canUpgrade: true,
        canDowngrade: true,
        canFreeze: true,
        freezeLimitDays: 15,
        requiresOwnerApproval: true,
        prorationMode: 'credit_remaining_days',
        paymentModesAllowed: ['cash', 'upi', 'card', 'online', 'manual'],
      },
    },
    {
      gymId: iron.gym._id,
      createdBy: iron.owner._id,
      name: 'Quarterly Pro',
      shortDescription: 'Best value for serious members',
      fullDescription: '3 months of full access with personal training sessions included.',
      durationDays: 90,
      price: 6000,
      joiningFee: 300,
      renewalLeadDays: 14,
      active: true,
      visibleToMembers: true,
      sortOrder: 4,
      upgradeRank: 3,
      category: 'quarterly',
      includedFeatures: {
        gymAccess: true,
        classAccess: true,
        trainerSupport: true,
        dietSupport: true,
        biometricAccess: true,
        lockerAccess: true,
        guestPasses: 5,
      },
      availableAddOns: {
        personalTraining: true,
        dietPlan: true,
      },
      rules: {
        canUpgrade: true,
        canDowngrade: false,
        canFreeze: true,
        freezeLimitDays: 30,
        requiresOwnerApproval: true,
        prorationMode: 'credit_remaining_days',
        paymentModesAllowed: ['cash', 'upi', 'card', 'online', 'manual'],
      },
    },
    {
      gymId: iron.gym._id,
      createdBy: iron.owner._id,
      name: 'Yearly Elite',
      shortDescription: 'Ultimate membership',
      fullDescription: 'Full year of premium access with all benefits and priority support.',
      durationDays: 365,
      price: 20000,
      joiningFee: 0,
      renewalLeadDays: 30,
      active: true,
      visibleToMembers: true,
      sortOrder: 5,
      upgradeRank: 4,
      category: 'yearly',
      includedFeatures: {
        gymAccess: true,
        classAccess: true,
        trainerSupport: true,
        dietSupport: true,
        biometricAccess: true,
        lockerAccess: true,
        guestPasses: 12,
      },
      availableAddOns: {
        personalTraining: true,
        dietPlan: true,
      },
      rules: {
        canUpgrade: false,
        canDowngrade: false,
        canFreeze: true,
        freezeLimitDays: 60,
        requiresOwnerApproval: true,
        prorationMode: 'restart_full_term',
        paymentModesAllowed: ['cash', 'upi', 'card', 'online', 'manual'],
      },
    },
  ]);

  const ironBasicTemplate = ironTemplates.find(
    (template) => template.name === 'Monthly Basic',
  );
  const ironPremiumTemplate = ironTemplates.find(
    (template) => template.name === 'Monthly Premium',
  );

  const ironMembershipStartDate = new Date();
  ironMembershipStartDate.setDate(ironMembershipStartDate.getDate() - 20);

  const ironMembershipEndDate = new Date(ironMembershipStartDate);
  ironMembershipEndDate.setDate(
    ironMembershipEndDate.getDate() + (ironBasicTemplate?.durationDays || 30),
  );

  const ironNextRenewalDate = new Date(ironMembershipEndDate);
  ironNextRenewalDate.setDate(
    ironNextRenewalDate.getDate() - (ironBasicTemplate?.renewalLeadDays || 7),
  );

  await MemberMembership.create({
    gymId: iron.gym._id,
    memberId: member._id,
    membershipTemplateId: ironBasicTemplate?._id || null,
    status: 'active',
    startDate: ironMembershipStartDate,
    endDate: ironMembershipEndDate,
    nextRenewalDate: ironNextRenewalDate,
    activatedAt: ironMembershipStartDate,
    approvedBy: iron.owner._id,
    paymentStatus: 'paid',
    paymentMethod: 'cash',
    paymentReference: 'DEMO-CASH-001',
    notes: 'Seeded active membership for lifecycle verification.',
    entitlementsSnapshot: {
      gymAccess: true,
      classAccess: false,
      trainerSupport: false,
      dietSupport: false,
      biometricAccess: true,
      lockerAccess: true,
      guestPasses: 0,
      personalTraining: false,
      dietPlan: false,
    },
    isFrozen: false,
    isActiveBaseMembership: true,
  });

  if (ironPremiumTemplate) {
    await MembershipChangeRequest.create({
      gymId: iron.gym._id,
      memberId: member._id,
      requestType: 'upgrade',
      targetMembershipTemplateId: ironPremiumTemplate._id,
      requestedAddOns: {
        personalTraining: false,
        dietPlan: false,
      },
      paymentMode: 'upi',
      paymentReference: '',
      memberNote: 'Interested in classes and trainer support.',
      status: 'submitted',
      requestedAt: new Date(),
    });
  }

  const flowMember = await User.create({
    name: 'Demo Member Skye',
    email: DEMO_USERS.memberFlow.email,
    password: DEMO_USERS.memberFlow.password,
    role: 'gym_member',
    gymId: flow.gym._id,
    phone_number: DEMO_USERS.memberFlow.phone,
    ...onboardingBundle({
      profile: {
        age: 32,
        gender: 'female',
        weight: 61,
        height: 167,
        avatar: 'default_user.png',
        bio: 'Mobility first, energy always.',
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

  await MemberMembership.create({
    gymId: flow.gym._id,
    memberId: flowMember._id,
    membershipTemplateId: null,
    status: 'pending_payment',
    startDate: null,
    endDate: null,
    nextRenewalDate: null,
    activatedAt: null,
    approvedBy: iron.owner._id,
    paymentStatus: 'unpaid',
    paymentMethod: null,
    paymentReference: '',
    notes: '',
    entitlementsSnapshot: {
      gymAccess: false,
      classAccess: false,
      trainerSupport: false,
      dietSupport: false,
      biometricAccess: false,
      lockerAccess: false,
      guestPasses: 0,
      personalTraining: false,
      dietPlan: false,
    },
    isFrozen: false,
    isActiveBaseMembership: false,
  });

  const admin = await User.create({
    name: 'Demo Admin',
    email: DEMO_USERS.admin.email,
    password: DEMO_USERS.admin.password,
    role: 'admin',
  });

  await InviteCode.insertMany([
    {
      code: DEMO_CODES[0],
      role: 'gym_member',
      gymId: iron.gym._id,
      gymName: iron.gym.gymName,
      used: true,
      usedBy: member.email,
    },
    {
      code: DEMO_CODES[1],
      role: 'gym_trainer',
      gymId: iron.gym._id,
      gymName: iron.gym.gymName,
      used: true,
      usedBy: trainer.email,
    },
  ]);

  console.log(
    JSON.stringify(
      {
        admin: DEMO_USERS.admin,
        owner: DEMO_USERS.ownerIron,
        trainer: DEMO_USERS.trainerIron,
        member: {
          email: DEMO_USERS.memberIron.email,
          password: DEMO_USERS.memberIron.password,
          phone: DEMO_USERS.memberIron.phone,
          quickJoinOtp: '1234',
        },
        flowOwner: DEMO_USERS.ownerFlow,
        quietOwner: DEMO_USERS.ownerQuiet,
        gyms: [iron.gym.gymName, flow.gym.gymName, quiet.gym.gymName],
        memberExamples: [member.email, flowMember.email],
      },
      null,
      2,
    ),
  );

  await mongoose.disconnect();
}

seedDemoData().catch((error) => {
  console.error(error);
  process.exit(1);
});
