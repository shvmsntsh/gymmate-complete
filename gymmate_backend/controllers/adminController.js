const Gym = require('../models/Gym');
const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const { PLATFORM_PLAN_TIERS, getPlanCap, getPlanTier } = require('../utils/platformPlans');
const { getGymMemberUsage } = require('../utils/gymLimits');
const { normalizeServices, serviceSlug } = require('../utils/serviceCatalog');

const USER_SELECT = 'name email phone_number role gymId accountStatus deactivatedAt createdAt updatedAt registered invited';
const VALID_USER_STATUSES = new Set(['active', 'deactivated']);
const VALID_GYM_STATUSES = new Set(['active', 'inactive']);
const VALID_PLAN_STATUSES = new Set(['active', 'locked']);
const VALID_ROLES = new Set(['superadmin', 'admin', 'gym_owner', 'gym_staff', 'gym_trainer', 'gym_member']);

function serializeGym(gym, usage = null, owner = null) {
  const planKey = gym.platformPlan || 'launch_50';
  const plan = getPlanTier(planKey);
  const usagePayload = usage
    ? {
        activeMembers: usage.activeMembers,
        openMemberInvites: usage.openMemberInvites,
        usedSeats: usage.usedSeats,
        memberCap: usage.memberCap,
        remainingSeats: usage.remainingSeats,
        isLocked: usage.isLocked,
      }
    : null;
  return {
    id: gym._id,
    gymName: gym.gymName,
    name: gym.gymName,
    email: gym.email,
    address: gym.address || '',
    contactNumber: gym.contactNumber || '',
    status: gym.status || 'active',
    services: normalizeServices(gym.services),
    serviceSlugs: gym.serviceSlugs || normalizeServices(gym.services).map(serviceSlug),
    branding: gym.branding || {},
    owner: owner
      ? {
          id: owner._id,
          name: owner.name,
          email: owner.email,
          accountStatus: owner.accountStatus || 'active',
        }
      : null,
    platformPlan: planKey,
    platformPlanName: plan.name,
    memberCap: getPlanCap(planKey, gym.memberCap),
    planStatus: gym.planStatus || 'active',
    usage: usagePayload,
    createdAt: gym.createdAt,
    updatedAt: gym.updatedAt,
  };
}

function serializeUser(user, gym = null) {
  return {
    id: user._id,
    name: user.name,
    email: user.email,
    phone_number: user.phone_number || '',
    role: user.role,
    gymId: user.gymId || null,
    gymName: gym?.gymName || '',
    accountStatus: user.accountStatus || 'active',
    registered: user.registered,
    invited: user.invited,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

async function gymMapById(ids) {
  const gyms = await Gym.find({ _id: { $in: ids.filter(Boolean) } }).select('gymName');
  return new Map(gyms.map((gym) => [String(gym._id), gym]));
}

exports.getNetworkOverview = async (_req, res) => {
  try {
    const [gyms, usersByRole, inviteCounts] = await Promise.all([
      Gym.find({}).sort({ createdAt: -1 }).limit(6),
      User.aggregate([{ $group: { _id: '$role', count: { $sum: 1 } } }]),
      InviteCode.aggregate([{ $group: { _id: '$used', count: { $sum: 1 } } }]),
    ]);

    const roleCounts = Object.fromEntries(usersByRole.map((entry) => [entry._id || 'unknown', entry.count]));
    const inviteSummary = {
      open: inviteCounts.find((entry) => entry._id === false)?.count || 0,
      claimed: inviteCounts.find((entry) => entry._id === true)?.count || 0,
    };

    const usage = await Promise.all(
      gyms.map(async (gym) => serializeGym(gym, await getGymMemberUsage(gym._id))),
    );

    return res.json({
      planTiers: PLATFORM_PLAN_TIERS,
      counts: {
        gyms: await Gym.countDocuments({}),
        activeGyms: await Gym.countDocuments({ status: 'active' }),
        owners: roleCounts.gym_owner || 0,
        staff: roleCounts.gym_staff || 0,
        trainers: roleCounts.gym_trainer || 0,
        members: roleCounts.gym_member || 0,
        admins: (roleCounts.admin || 0) + (roleCounts.superadmin || 0),
        openInvites: inviteSummary.open,
        claimedInvites: inviteSummary.claimed,
      },
      recentGyms: usage,
    });
  } catch (error) {
    console.error('Admin overview failed:', error);
    return res.status(500).json({ message: 'Failed to load network overview.' });
  }
};

exports.listGyms = async (_req, res) => {
  try {
    const gyms = await Gym.find({}).sort({ createdAt: -1 });
    const owners = await User.find({ role: 'gym_owner' }).select(USER_SELECT);
    const ownersByGym = new Map(owners.map((owner) => [String(owner.gymId), owner]));
    const rows = await Promise.all(
      gyms.map(async (gym) => serializeGym(gym, await getGymMemberUsage(gym._id), ownersByGym.get(String(gym._id)))),
    );
    return res.json({ gyms: rows, planTiers: PLATFORM_PLAN_TIERS });
  } catch (error) {
    console.error('Admin list gyms failed:', error);
    return res.status(500).json({ message: 'Failed to load gyms.' });
  }
};

exports.updateGym = async (req, res) => {
  try {
    const updates = {};
    if (req.body.status && VALID_GYM_STATUSES.has(req.body.status)) {
      updates.status = req.body.status;
    }
    if (req.body.platformPlan) {
      if (!PLATFORM_PLAN_TIERS.some((tier) => tier.key === req.body.platformPlan)) {
        return res.status(400).json({ message: 'Choose a valid platform plan.' });
      }
      updates.platformPlan = req.body.platformPlan;
    }
    if (req.body.planStatus && VALID_PLAN_STATUSES.has(req.body.planStatus)) {
      updates.planStatus = req.body.planStatus;
    }
    if (req.body.memberCap !== undefined) {
      const memberCap = Number(req.body.memberCap);
      if (!Number.isFinite(memberCap) || memberCap < 1) {
        return res.status(400).json({ message: 'Member cap must be a positive number.' });
      }
      updates.memberCap = Math.floor(memberCap);
    }
    if (Object.keys(updates).length > 0) {
      updates.planUpdatedAt = new Date();
      updates.planUpdatedBy = req.user._id;
    }

    const gym = await Gym.findByIdAndUpdate(req.params.gymId, { $set: updates }, { new: true });
    if (!gym) return res.status(404).json({ message: 'Gym not found.' });

    return res.json({ gym: serializeGym(gym, await getGymMemberUsage(gym._id)) });
  } catch (error) {
    console.error('Admin update gym failed:', error);
    return res.status(500).json({ message: 'Failed to update gym.' });
  }
};

exports.listUsers = async (_req, res) => {
  try {
    const users = await User.find({}).sort({ createdAt: -1 }).select(USER_SELECT);
    const gymsById = await gymMapById(users.map((user) => user.gymId));
    return res.json({
      users: users.map((user) => serializeUser(user, gymsById.get(String(user.gymId)))),
    });
  } catch (error) {
    console.error('Admin list users failed:', error);
    return res.status(500).json({ message: 'Failed to load people.' });
  }
};

exports.updateUser = async (req, res) => {
  try {
    const user = await User.findById(req.params.userId);
    if (!user) return res.status(404).json({ message: 'User not found.' });
    if (String(user._id) === String(req.user._id) && req.body.accountStatus === 'deactivated') {
      return res.status(400).json({ message: 'You cannot deactivate your own admin account.' });
    }

    if (req.body.accountStatus) {
      if (!VALID_USER_STATUSES.has(req.body.accountStatus)) {
        return res.status(400).json({ message: 'Choose a valid account status.' });
      }
      user.accountStatus = req.body.accountStatus;
      user.deactivatedAt = req.body.accountStatus === 'deactivated' ? new Date() : null;
      user.deactivatedBy = req.body.accountStatus === 'deactivated' ? req.user._id : null;
    }

    if (req.body.role) {
      if (!VALID_ROLES.has(req.body.role)) {
        return res.status(400).json({ message: 'Choose a valid role.' });
      }
      user.role = req.body.role;
    }

    if (req.body.gymId !== undefined) {
      user.gymId = req.body.gymId || null;
    }

    await user.save({ validateBeforeSave: false });
    const gym = user.gymId ? await Gym.findById(user.gymId).select('gymName') : null;
    return res.json({ user: serializeUser(user, gym) });
  } catch (error) {
    console.error('Admin update user failed:', error);
    return res.status(500).json({ message: 'Failed to update user.' });
  }
};

exports.listInvites = async (_req, res) => {
  try {
    const invites = await InviteCode.find({}).sort({ updatedAt: -1 }).lean();
    const gymsById = await gymMapById(invites.map((invite) => invite.gymId));
    return res.json({
      invites: invites.map((invite) => ({
        id: invite._id,
        code: invite.code,
        role: invite.role,
        gymId: invite.gymId || null,
        gymName: invite.gymName || gymsById.get(String(invite.gymId))?.gymName || '',
        used: Boolean(invite.used),
        usedBy: invite.usedBy || null,
        inviteeName: invite.inviteeName || '',
        inviteeEmail: invite.inviteeEmail || '',
        inviteePhone: invite.inviteePhone || '',
        createdAt: invite.createdAt,
        usedAt: invite.usedAt || null,
        updatedAt: invite.updatedAt,
      })),
    });
  } catch (error) {
    console.error('Admin list invites failed:', error);
    return res.status(500).json({ message: 'Failed to load invites.' });
  }
};

exports.getServiceAnalytics = async (_req, res) => {
  try {
    const gyms = await Gym.find({}).select('services');
    const counts = new Map();
    gyms.forEach((gym) => {
      normalizeServices(gym.services).forEach((service) => {
        const slug = serviceSlug(service);
        const row = counts.get(slug) || { name: service, slug, gymCount: 0 };
        row.gymCount += 1;
        counts.set(slug, row);
      });
    });

    return res.json({
      services: Array.from(counts.values()).sort((a, b) => b.gymCount - a.gymCount),
    });
  } catch (error) {
    console.error('Admin service analytics failed:', error);
    return res.status(500).json({ message: 'Failed to load service analytics.' });
  }
};
