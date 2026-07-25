const Gym = require('../models/Gym');
const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const PlatformPlanPayment = require('../models/PlatformPlanPayment');
const { PLATFORM_PLAN_TIERS, getPlanCap, getPlanTier, getMonthlyAmountDue } = require('../utils/platformPlans');
const { getGymMemberUsage } = require('../utils/gymLimits');
const { normalizeServices, serviceSlug } = require('../utils/serviceCatalog');

const VALID_PAYMENT_METHODS = new Set(['cash', 'upi', 'bank_transfer', 'cheque', 'other']);

const USER_SELECT = 'name email phone_number role gymId accountStatus deactivatedAt createdAt updatedAt registered invited';
const VALID_USER_STATUSES = new Set(['active', 'deactivated']);
const VALID_GYM_STATUSES = new Set(['active', 'inactive']);
const VALID_PLAN_STATUSES = new Set(['active', 'locked']);
const VALID_ROLES = new Set(['superadmin', 'admin', 'gym_owner', 'gym_staff', 'gym_trainer', 'gym_member']);

function serializeGym(gym, usage = null, owner = null) {
  const planKey = gym.platformPlan || 'starter';
  const plan = getPlanTier(planKey);
  const usagePayload = usage
    ? {
        activeMembers: usage.activeMembers,
        openMemberInvites: usage.openMemberInvites,
        usedSeats: usage.usedSeats,
        memberCap: usage.memberCap,
        remainingSeats: usage.remainingSeats,
        overCap: usage.overCap,
        isLocked: usage.isLocked,
        isOnTrial: usage.isOnTrial,
        isTrialExpired: usage.isTrialExpired,
        trialEndsAt: usage.trialEndsAt,
      }
    : null;
  const monthlyAmountDue = getMonthlyAmountDue(
    planKey,
    usage ? usage.activeMembers : 0,
    gym.customPricePerMember,
    gym.customFloorPrice,
  );
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
    pricePerMember: plan.key === 'custom' ? (gym.customPricePerMember ?? null) : plan.pricePerMember,
    floorPrice: plan.key === 'custom' ? (gym.customFloorPrice ?? null) : plan.floorPrice,
    monthlyAmountDue,
    planPaidUntil: gym.planPaidUntil || null,
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

// GET /api/admin/gyms/:gymId/billing — current tier, live-computed amount
// due, planPaidUntil, planStatus, and the full manual-payment history.
exports.getGymBilling = async (req, res) => {
  try {
    const gym = await Gym.findById(req.params.gymId);
    if (!gym) return res.status(404).json({ message: 'Gym not found.' });

    const owner = await User.findOne({ gymId: gym._id, role: 'gym_owner' }).select(USER_SELECT);
    const usage = await getGymMemberUsage(gym._id);
    const payments = await PlatformPlanPayment.find({ gymId: gym._id })
      .sort({ createdAt: -1 })
      .populate('recordedBy', 'name email')
      .lean();

    return res.json({
      gym: serializeGym(gym, usage, owner),
      planTiers: PLATFORM_PLAN_TIERS,
      payments: payments.map((p) => ({
        id: p._id,
        planKey: p.planKey,
        amount: p.amount,
        currency: p.currency,
        paymentMethod: p.paymentMethod,
        periodStart: p.periodStart,
        periodEnd: p.periodEnd,
        reference: p.reference,
        notes: p.notes,
        recordedBy: p.recordedBy ? { id: p.recordedBy._id, name: p.recordedBy.name, email: p.recordedBy.email } : null,
        createdAt: p.createdAt,
      })),
    });
  } catch (error) {
    console.error('Admin get gym billing failed:', error);
    return res.status(500).json({ message: 'Failed to load billing info.' });
  }
};

// POST /api/admin/gyms/:gymId/plan-payment — "assign a plan after
// manually collecting payment." Records an immutable payment row and
// activates the gym on the chosen tier through planPaidUntil.
exports.recordPlanPayment = async (req, res) => {
  try {
    const { planKey, amount, paymentMethod, periodStart, periodEnd, reference, notes,
      customMemberCap, customPricePerMember, customFloorPrice } = req.body;

    if (!PLATFORM_PLAN_TIERS.some((tier) => tier.key === planKey)) {
      return res.status(400).json({ message: 'Choose a valid platform plan.' });
    }
    const amountNum = Number(amount);
    if (!Number.isFinite(amountNum) || amountNum < 0) {
      return res.status(400).json({ message: 'Amount must be a non-negative number.' });
    }
    if (!VALID_PAYMENT_METHODS.has(paymentMethod)) {
      return res.status(400).json({ message: 'Choose a valid payment method.' });
    }
    const start = new Date(periodStart);
    const end = new Date(periodEnd);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      return res.status(400).json({ message: 'Period end must be a valid date after period start.' });
    }

    const gym = await Gym.findById(req.params.gymId);
    if (!gym) return res.status(404).json({ message: 'Gym not found.' });

    const gymUpdates = {
      platformPlan: planKey,
      planStatus: 'active',
      planPaidUntil: end,
      // A recorded payment graduates a gym off its free trial permanently
      // (even a Rs 0 "comped" payment counts as a deliberate superadmin
      // decision to extend/convert it) — the trial's hard cap and
      // auto-expiry no longer apply once this is cleared.
      trialEndsAt: null,
      planUpdatedAt: new Date(),
      planUpdatedBy: req.user._id,
    };
    if (planKey === 'custom') {
      if (customMemberCap !== undefined) {
        const cap = Number(customMemberCap);
        if (!Number.isFinite(cap) || cap < 1) {
          return res.status(400).json({ message: 'Custom member cap must be a positive number.' });
        }
        gymUpdates.memberCap = Math.floor(cap);
      }
      if (customPricePerMember !== undefined) {
        const rate = Number(customPricePerMember);
        gymUpdates.customPricePerMember = Number.isFinite(rate) && rate >= 0 ? rate : null;
      }
      if (customFloorPrice !== undefined) {
        const floor = Number(customFloorPrice);
        gymUpdates.customFloorPrice = Number.isFinite(floor) && floor >= 0 ? floor : null;
      }
    } else {
      gymUpdates.memberCap = getPlanCap(planKey);
    }

    await Gym.updateOne({ _id: gym._id }, { $set: gymUpdates });

    const payment = await PlatformPlanPayment.create({
      gymId: gym._id,
      planKey,
      amount: amountNum,
      paymentMethod,
      periodStart: start,
      periodEnd: end,
      reference: reference || '',
      notes: notes || '',
      recordedBy: req.user._id,
    });

    const updatedGym = await Gym.findById(gym._id);
    const paymentOwner = await User.findOne({ gymId: gym._id, role: 'gym_owner' }).select(USER_SELECT);
    const usage = await getGymMemberUsage(gym._id);
    return res.status(201).json({
      gym: serializeGym(updatedGym, usage, paymentOwner),
      payment: {
        id: payment._id,
        planKey: payment.planKey,
        amount: payment.amount,
        paymentMethod: payment.paymentMethod,
        periodStart: payment.periodStart,
        periodEnd: payment.periodEnd,
      },
    });
  } catch (error) {
    console.error('Admin record plan payment failed:', error);
    return res.status(500).json({ message: 'Failed to record payment.' });
  }
};

// POST /api/admin/gyms/:gymId/plan-unassign — "unassign" a plan. Locks
// seat growth WITHOUT touching platformPlan/memberCap/planPaidUntil or
// deleting payment history, so the gym resumes instantly on next payment.
exports.unassignPlan = async (req, res) => {
  try {
    const gym = await Gym.findByIdAndUpdate(
      req.params.gymId,
      { $set: { planStatus: 'locked', planUpdatedAt: new Date(), planUpdatedBy: req.user._id } },
      { new: true },
    );
    if (!gym) return res.status(404).json({ message: 'Gym not found.' });

    const unassignOwner = await User.findOne({ gymId: gym._id, role: 'gym_owner' }).select(USER_SELECT);
    const usage = await getGymMemberUsage(gym._id);
    return res.json({ gym: serializeGym(gym, usage, unassignOwner) });
  } catch (error) {
    console.error('Admin unassign plan failed:', error);
    return res.status(500).json({ message: 'Failed to unassign plan.' });
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
