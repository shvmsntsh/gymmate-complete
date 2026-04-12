const Gym = require('../models/Gym');
const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const { getPlanCap } = require('./platformPlans');

async function getGymMemberUsage(gymId) {
  const gym = await Gym.findById(gymId).select('platformPlan memberCap planStatus status');
  if (!gym) {
    throw new Error('Gym not found');
  }

  const [activeMembers, openMemberInvites] = await Promise.all([
    User.countDocuments({
      gymId,
      role: 'gym_member',
      accountStatus: { $ne: 'deactivated' },
      $or: [{ registered: true }, { invited: { $ne: true } }],
    }),
    InviteCode.countDocuments({
      gymId,
      role: 'gym_member',
      used: false,
    }),
  ]);

  const memberCap = getPlanCap(gym.platformPlan, gym.memberCap);
  const usedSeats = activeMembers + openMemberInvites;

  return {
    gym,
    activeMembers,
    openMemberInvites,
    usedSeats,
    memberCap,
    remainingSeats: Math.max(0, memberCap - usedSeats),
    isLocked: usedSeats >= memberCap || gym.planStatus === 'locked',
  };
}

async function ensureCanCreateMemberInvite(gymId) {
  const usage = await getGymMemberUsage(gymId);
  if (usage.isLocked) {
    const planName = usage.gym.platformPlan || 'current plan';
    const error = new Error(
      `This gym has reached the ${usage.memberCap} member-seat limit for ${planName}. Upgrade the platform plan to create more member invites.`,
    );
    error.statusCode = 403;
    error.usage = usage;
    throw error;
  }
  return usage;
}

module.exports = {
  ensureCanCreateMemberInvite,
  getGymMemberUsage,
};
