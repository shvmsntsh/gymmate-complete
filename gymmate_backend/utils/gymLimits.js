const Gym = require('../models/Gym');
const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const { getPlanCap } = require('./platformPlans');

async function getGymMemberUsage(gymId) {
  const gym = await Gym.findById(gymId).select('platformPlan memberCap planStatus status trialEndsAt');
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
  // null memberCap means an uncapped tier (Elite, or a Custom gym with no
  // cap override) — no soft-cap band to compare against.
  const isUncapped = memberCap === null || memberCap === undefined;
  const overCap = !isUncapped && usedSeats >= memberCap;

  // Trial gyms have no confirmed payment yet, so they're held to a firm
  // boundary rather than the soft/upsell cap paid tiers get: the 100-seat
  // cap genuinely blocks, and the trial itself expires 1 month after
  // registration with no cron job — this is just a plain date comparison
  // evaluated live on every request, so it's always correct and instant,
  // and needs no background job to keep it that way.
  const isOnTrial = Boolean(gym.trialEndsAt);
  const isTrialExpired = isOnTrial && gym.trialEndsAt.getTime() < Date.now();

  return {
    gym,
    activeMembers,
    openMemberInvites,
    usedSeats,
    memberCap,
    remainingSeats: isUncapped ? null : Math.max(0, memberCap - usedSeats),
    // Cap is a SOFT band for paid tiers (pricing/upsell signal only, never
    // blocks on its own) — see isLocked below for the trial exception.
    overCap,
    isOnTrial,
    isTrialExpired,
    trialEndsAt: gym.trialEndsAt || null,
    isLocked:
      gym.planStatus === 'locked' ||
      isTrialExpired ||
      (isOnTrial && !isTrialExpired && overCap),
  };
}

async function ensureCanCreateMemberInvite(gymId) {
  const usage = await getGymMemberUsage(gymId);
  if (usage.isLocked) {
    let message = 'This gym\'s platform plan is not active. Ask your platform admin to confirm your payment and reactivate your plan before inviting more members.';
    if (usage.isTrialExpired) {
      message = 'Your 1-month free trial has ended. Ask your platform admin to activate a paid plan to keep inviting members.';
    } else if (usage.isOnTrial && usage.overCap) {
      message = `Your free trial is limited to ${usage.memberCap} members. Ask your platform admin to activate a paid plan to invite more.`;
    }
    const error = new Error(message);
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
