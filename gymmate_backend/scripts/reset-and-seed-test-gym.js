require('dotenv').config();
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');

const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const Announcement = require('../models/Announcement');
const AnnouncementDelivery = require('../models/AnnouncementDelivery');
const AttendanceEvent = require('../models/AttendanceEvent');
const BiometricIdentity = require('../models/BiometricIdentity');
const BiometricIntegration = require('../models/BiometricIntegration');
const Conversation = require('../models/Conversation');
const DailyPlanLog = require('../models/DailyPlanLog');
const MediaAsset = require('../models/MediaAsset');
const MemberMembership = require('../models/MemberMembership');
const MembershipAuditLog = require('../models/MembershipAuditLog');
const MembershipChangeRequest = require('../models/MembershipChangeRequest');
const MembershipPlanCatalog = require('../models/MembershipPlanCatalog');
const MembershipRequest = require('../models/MembershipRequest');
const MembershipTemplate = require('../models/MembershipTemplate');
const Message = require('../models/Message');
const PaymentEntry = require('../models/PaymentEntry');
const PlanCache = require('../models/PlanCache');
const TrainerAssignment = require('../models/TrainerAssignment');

const MONGODB_URI =
  process.env.MONGODB_URI ||
  process.env.MONGO_URI ||
  'mongodb://127.0.0.1:27017/gymmate';

const TEST_GYM = {
  gymName: 'Test Iron Gym',
  email: 'owner@testgym.local',
  password: 'Owner123!',
  address: '101 Test Lane, Brooklyn',
  contactNumber: '5550001001',
  services: ['Strength', 'Conditioning', 'Recovery'],
  branding: {
    primaryColor: '#B59F5B',
    secondaryColor: '#F8D84B',
    logoUrl: null,
    logoScale: 1,
    logoOffsetX: 0,
    logoOffsetY: 0,
  },
};

const TEST_MEMBER = {
  name: 'Test Member Riley',
  email: 'member@testgym.local',
  password: 'Member123!',
  phone: '5550001002',
};

const args = new Set(process.argv.slice(2));
const shouldResetSuperadminOnly =
  args.has('--superadmin-only') || args.has('--blank');

const RESET_MODELS = [
  Announcement,
  AnnouncementDelivery,
  AttendanceEvent,
  BiometricIdentity,
  BiometricIntegration,
  Conversation,
  DailyPlanLog,
  Gym,
  InviteCode,
  MediaAsset,
  MemberMembership,
  MembershipAuditLog,
  MembershipChangeRequest,
  MembershipPlanCatalog,
  MembershipRequest,
  MembershipTemplate,
  Message,
  PaymentEntry,
  PlanCache,
  TrainerAssignment,
];

function onboardingBundle() {
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
      age: 28,
      gender: 'male',
      weight: 78,
      height: 178,
      avatar: 'default_user.png',
      bio: 'Consistent sessions and simple tracking.',
    },
    fitnessGoals: ['strength', 'general_fitness'],
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
  };
}

async function clearAllNonSuperadminData() {
  for (const Model of RESET_MODELS) {
    await Model.deleteMany({});
  }

  await User.deleteMany({ role: { $ne: 'superadmin' } });
}

async function listPreservedSuperadmins() {
  const superadmins = await User.find({ role: 'superadmin' })
    .sort({ createdAt: 1 })
    .select('name email')
    .lean();

  return superadmins.map((user) => ({
    name: user.name || null,
    email: user.email || null,
  }));
}

async function createGymWithOwner() {
  const hashedGymPassword = await bcrypt.hash(TEST_GYM.password, 10);
  const gym = await Gym.create({
    gymName: TEST_GYM.gymName,
    email: TEST_GYM.email,
    password: hashedGymPassword,
    address: TEST_GYM.address,
    contactNumber: TEST_GYM.contactNumber,
    services: TEST_GYM.services,
    branding: TEST_GYM.branding,
    role: 'gym_owner',
  });

  const owner = await User.create({
    name: TEST_GYM.gymName,
    email: TEST_GYM.email,
    password: TEST_GYM.password,
    role: 'gym_owner',
    gymId: gym._id,
    phone_number: TEST_GYM.contactNumber,
  });

  gym.owner = owner._id;
  await gym.save();

  return { gym, owner };
}

async function seedMembershipData(gym, owner) {
  const member = await User.create({
    name: TEST_MEMBER.name,
    email: TEST_MEMBER.email,
    password: TEST_MEMBER.password,
    role: 'gym_member',
    gymId: gym._id,
    phone_number: TEST_MEMBER.phone,
    ...onboardingBundle(),
  });

  const templates = await MembershipTemplate.insertMany([
    {
      gymId: gym._id,
      createdBy: owner._id,
      name: 'Monthly Basic',
      shortDescription: 'Essential gym access',
      fullDescription: 'Gym access with locker and offline renewal workflow.',
      durationDays: 30,
      price: 1500,
      joiningFee: 500,
      renewalLeadDays: 7,
      active: true,
      visibleToMembers: true,
      sortOrder: 1,
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
        paymentModesAllowed: ['cash', 'upi'],
      },
    },
    {
      gymId: gym._id,
      createdBy: owner._id,
      name: 'Monthly Premium',
      shortDescription: 'Classes and trainer support',
      fullDescription: 'Upgraded access with class support and trainer consultations.',
      durationDays: 30,
      price: 2500,
      joiningFee: 500,
      renewalLeadDays: 7,
      active: true,
      visibleToMembers: true,
      sortOrder: 2,
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
        paymentModesAllowed: ['cash', 'upi'],
      },
    },
  ]);

  const basicTemplate = templates[0];
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - 20);

  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + basicTemplate.durationDays);

  const nextRenewalDate = new Date(endDate);
  nextRenewalDate.setDate(
    nextRenewalDate.getDate() - basicTemplate.renewalLeadDays,
  );

  const membership = await MemberMembership.create({
    gymId: gym._id,
    memberId: member._id,
    membershipTemplateId: basicTemplate._id,
    status: 'active',
    startDate,
    endDate,
    nextRenewalDate,
    activatedAt: startDate,
    approvedBy: owner._id,
    paymentStatus: 'paid',
    paymentMethod: 'cash',
    paymentReference: 'TEST-CASH-001',
    notes: 'Seeded active membership.',
    entitlementsSnapshot: {
      ...basicTemplate.includedFeatures,
      personalTraining: false,
      dietPlan: false,
    },
    isFrozen: false,
    isActiveBaseMembership: true,
  });

  await PaymentEntry.create({
    gymId: gym._id,
    memberId: member._id,
    membershipId: membership._id,
    amount: basicTemplate.price,
    mode: 'cash',
    reference: 'TEST-CASH-001',
    note: 'Seeded opening payment for active basic plan.',
    recordedBy: owner._id,
    recordedAt: startDate,
  });

  return { member };
}

async function main() {
  await mongoose.connect(MONGODB_URI);

  try {
    await clearAllNonSuperadminData();
    const preservedSuperadmins = await listPreservedSuperadmins();

    if (shouldResetSuperadminOnly) {
      console.log(
        JSON.stringify(
          {
            message: 'Reset complete. Preserved superadmin users only.',
            mode: 'superadmin-only',
            superadmins: preservedSuperadmins,
          },
          null,
          2,
        ),
      );
      return;
    }

    const { gym, owner } = await createGymWithOwner();
    const { member } = await seedMembershipData(gym, owner);

    console.log(
      JSON.stringify(
        {
          message: 'Reset complete. Preserved superadmin users only.',
          mode: 'seed-test-gym',
          superadmins: preservedSuperadmins,
          gym: {
            name: gym.gymName,
            id: gym._id,
          },
          owner: {
            email: TEST_GYM.email,
            password: TEST_GYM.password,
          },
          member: {
            email: TEST_MEMBER.email,
            password: TEST_MEMBER.password,
          },
          memberId: member._id,
        },
        null,
        2,
      ),
    );
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
