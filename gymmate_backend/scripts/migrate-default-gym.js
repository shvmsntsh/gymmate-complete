require('dotenv').config();
const mongoose = require('mongoose');
const Gym = require('../models/Gym');
const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const Plan = require('../models/plan');
const PlanCache = require('../models/PlanCache');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/gymmate';

async function ensureDefaultGym() {
  const existingDefaultGym = await Gym.findOne({ slug: 'default-gym' });
  if (existingDefaultGym) {
    return existingDefaultGym;
  }

  const fallbackOwner =
    await User.findOne({ role: 'superadmin' }) ||
    await User.findOne({ role: 'gym_owner' }) ||
    await User.findOne({});

  if (!fallbackOwner) {
    throw new Error('Cannot create default gym because no users exist to assign as owner.');
  }

  const defaultGym = await Gym.create({
    gymName: 'Default Gym',
    slug: 'default-gym',
    email: fallbackOwner.email,
    owner: fallbackOwner._id,
    services: []
  });

  return defaultGym;
}

async function run() {
  await mongoose.connect(MONGODB_URI);
  console.log('Connected to MongoDB');

  const defaultGym = await ensureDefaultGym();
  console.log(`Using default gym ${defaultGym._id} (${defaultGym.gymName})`);

  const orphanUsers = await User.find({
    role: { $in: ['admin', 'gym_owner', 'gym_trainer', 'gym_member'] },
    $or: [{ gymId: { $exists: false } }, { gymId: null }]
  });

  for (const user of orphanUsers) {
    user.gymId = defaultGym._id;
    await user.save();
  }

  const orphanInvites = await InviteCode.find({
    role: { $in: ['gym_member', 'gym_trainer'] },
    $or: [{ gymId: { $exists: false } }, { gymId: null }]
  });

  for (const invite of orphanInvites) {
    invite.gymId = defaultGym._id;
    invite.gymName = defaultGym.gymName;
    await invite.save();
  }

  const userPlans = await Plan.find({
    $or: [{ gymId: { $exists: false } }, { gymId: null }]
  }).populate('user', 'gymId');

  for (const plan of userPlans) {
    plan.gymId = plan.user?.gymId || defaultGym._id;
    await plan.save();
  }

  const cachedPlans = await PlanCache.find({
    $or: [{ gymId: { $exists: false } }, { gymId: null }]
  }).populate('userId', 'gymId');

  for (const planCache of cachedPlans) {
    planCache.gymId = planCache.userId?.gymId || defaultGym._id;
    await planCache.save();
  }

  console.log(`Backfilled ${orphanUsers.length} users, ${orphanInvites.length} invites, ${userPlans.length} plans, and ${cachedPlans.length} cached plans.`);
  await mongoose.disconnect();
}

run().catch(async (error) => {
  console.error(error);
  await mongoose.disconnect();
  process.exit(1);
});
