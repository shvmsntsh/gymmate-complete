const mongoose = require('mongoose');
require('dotenv').config();

const User = require('../models/User');
const MembershipPlanCatalog = require('../models/MembershipPlanCatalog');
const MembershipTemplate = require('../models/MembershipTemplate');
const MemberMembership = require('../models/MemberMembership');
const MembershipChangeRequest = require('../models/MembershipChangeRequest');
const MembershipAuditLog = require('../models/MembershipAuditLog');

const terminalStatuses = new Set(['expired', 'canceled', 'rejected']);
const paymentStatuses = new Set(['unpaid', 'payment_under_review', 'paid', 'waived']);

function mapLegacyStatus(status) {
  const normalized = String(status || '').trim().toLowerCase();
  if (normalized === 'expiring') return 'renewal_due';
  if (normalized === 'payment_pending') return 'pending_payment';
  if (normalized === 'inactive') return 'pending_payment';
  if (normalized === 'cancelled') return 'canceled';
  if (
    [
      'pending_payment',
      'pending_approval',
      'active',
      'renewal_due',
      'expired',
      'frozen',
      'canceled',
      'rejected',
    ].includes(normalized)
  ) {
    return normalized;
  }
  return 'pending_payment';
}

function baseMembershipRank(membership) {
  const status = mapLegacyStatus(membership.status);
  if (status === 'active') return 0;
  if (status === 'renewal_due') return 1;
  if (status === 'frozen') return 2;
  if (status === 'pending_payment') return 3;
  if (status === 'pending_approval') return 4;
  return 10;
}

function toTime(value) {
  const date = value ? new Date(value) : null;
  return date && !Number.isNaN(date.getTime()) ? date.getTime() : 0;
}

function buildTemplatePayload({ gymId, createdBy, legacyPlan, membership }) {
  const planName =
    String(legacyPlan?.name || membership.planName || 'Legacy Membership').trim() ||
    'Legacy Membership';
  const services = Array.isArray(legacyPlan?.includedServices)
    ? legacyPlan.includedServices
    : [];

  return {
    gymId,
    createdBy,
    name: planName,
    shortDescription: legacyPlan?.description || 'Migrated from legacy membership plan.',
    fullDescription: legacyPlan?.description || '',
    durationDays: Number(legacyPlan?.durationDays || 30),
    price: Number(legacyPlan?.price || 0),
    joiningFee: 0,
    renewalLeadDays: Number(legacyPlan?.renewalLeadDays || 7),
    active: legacyPlan?.active !== false,
    visibleToMembers: legacyPlan?.active !== false,
    category: 'monthly',
    includedFeatures: {
      gymAccess: true,
      classAccess: services.some((entry) => /class/i.test(entry)),
      trainerSupport: Boolean(legacyPlan?.addOns?.training || membership.addOns?.training),
      dietSupport: Boolean(legacyPlan?.addOns?.diet || membership.addOns?.diet),
      biometricAccess: services.some((entry) => /biometric/i.test(entry)),
      lockerAccess: services.some((entry) => /locker/i.test(entry)),
      guestPasses: 0,
    },
    availableAddOns: {
      personalTraining: Boolean(legacyPlan?.addOns?.training || membership.addOns?.training),
      dietPlan: Boolean(legacyPlan?.addOns?.diet || membership.addOns?.diet),
    },
    rules: {
      canUpgrade: true,
      canDowngrade: false,
      canFreeze: false,
      freezeLimitDays: 0,
      requiresOwnerApproval: true,
      overlapPolicy: 'warn_and_require_override',
      approvalTimingPolicy: 'by_request_type',
      prorationMode: 'none',
      prorationPolicy: 'none',
      freezePolicy: 'extend_end_date',
      manualOverridePolicy: 'owner_only',
      paymentModesAllowed: ['cash', 'upi', 'card', 'online', 'manual', 'waived'],
    },
  };
}

function mapPaymentStatus(paymentStatus, status) {
  const normalized = String(paymentStatus || '').trim().toLowerCase();
  if (normalized === 'none') return 'unpaid';
  if (normalized === 'pending') return 'payment_under_review';
  if (paymentStatuses.has(normalized)) return normalized;
  return status === 'active' ? 'paid' : 'unpaid';
}

async function resolveTemplate({ gymId, createdBy, membership, legacyPlan, stats }) {
  if (membership.membershipTemplateId) {
    const existing = await MembershipTemplate.findOne({
      _id: membership.membershipTemplateId,
      gymId,
    }).lean();
    if (existing) {
      stats.templatesReused += 1;
      return existing._id;
    }
  }

  if (membership.planId && mongoose.Types.ObjectId.isValid(String(membership.planId))) {
    const existingByLegacyId = await MembershipTemplate.findOne({
      _id: membership.planId,
      gymId,
    }).lean();
    if (existingByLegacyId) {
      stats.templatesReused += 1;
      return existingByLegacyId._id;
    }
  }

  const name = String(legacyPlan?.name || membership.planName || 'Legacy Membership').trim();
  if (name) {
    const existingByName = await MembershipTemplate.findOne({ gymId, name }).lean();
    if (existingByName) {
      stats.templatesReused += 1;
      return existingByName._id;
    }
  }

  if (!createdBy) {
    stats.skipped += 1;
    console.log(`Skipping membership ${membership._id}: no user available for template createdBy`);
    return null;
  }

  const payload = buildTemplatePayload({ gymId, createdBy, legacyPlan, membership });
  if (membership.planId && mongoose.Types.ObjectId.isValid(String(membership.planId))) {
    const conflictingTemplate = await MembershipTemplate.findById(membership.planId).lean();
    if (!conflictingTemplate) {
      payload._id = membership.planId;
    }
  }

  const template = await MembershipTemplate.create(payload);
  stats.templatesCreated += 1;
  return template._id;
}

function buildEntitlements(membership, legacyPlan) {
  return {
    gymAccess: membership.entitlementsSnapshot?.gymAccess ?? true,
    classAccess:
      membership.entitlementsSnapshot?.classAccess ??
      Boolean(legacyPlan?.includedServices?.some((entry) => /class/i.test(entry))),
    trainerSupport:
      membership.entitlementsSnapshot?.trainerSupport ??
      Boolean(legacyPlan?.addOns?.training || membership.addOns?.training),
    dietSupport:
      membership.entitlementsSnapshot?.dietSupport ??
      Boolean(legacyPlan?.addOns?.diet || membership.addOns?.diet),
    biometricAccess: membership.entitlementsSnapshot?.biometricAccess ?? false,
    lockerAccess: membership.entitlementsSnapshot?.lockerAccess ?? false,
    guestPasses: membership.entitlementsSnapshot?.guestPasses ?? 0,
    personalTraining:
      membership.entitlementsSnapshot?.personalTraining ??
      Boolean(legacyPlan?.addOns?.training || membership.addOns?.training),
    dietPlan:
      membership.entitlementsSnapshot?.dietPlan ??
      Boolean(legacyPlan?.addOns?.diet || membership.addOns?.diet),
  };
}

async function backfillMemberships(db) {
  const stats = {
    membershipsScanned: 0,
    membershipsConverted: 0,
    templatesCreated: 0,
    templatesReused: 0,
    skipped: 0,
    activeBaseAssigned: 0,
  };

  const memberships = await db.collection('membermemberships').find({}).toArray();
  const legacyPlans = await MembershipPlanCatalog.find({}).lean();
  const legacyPlanById = legacyPlans.reduce((acc, plan) => {
    acc[String(plan._id)] = plan;
    return acc;
  }, {});

  const ownerByGym = {};
  const owners = await User.find({ role: 'gym_owner' }).select('_id gymId').lean();
  for (const owner of owners) {
    if (owner.gymId && !ownerByGym[String(owner.gymId)]) {
      ownerByGym[String(owner.gymId)] = owner._id;
    }
  }

  const convertedByMember = new Map();

  for (const membership of memberships) {
    stats.membershipsScanned += 1;
    if (!membership.gymId || !membership.memberId) {
      stats.skipped += 1;
      continue;
    }

    const gymId = membership.gymId;
    const legacyPlan = membership.planId ? legacyPlanById[String(membership.planId)] : null;
    const createdBy =
      legacyPlan?.createdBy ||
      membership.approvedBy ||
      ownerByGym[String(gymId)] ||
      null;
    const membershipTemplateId = await resolveTemplate({
      gymId,
      createdBy,
      membership,
      legacyPlan,
      stats,
    });

    if (!membershipTemplateId) continue;

    const status = mapLegacyStatus(membership.status);
    const paymentStatus = mapPaymentStatus(membership.paymentStatus, status);
    const nextRenewalDate = membership.nextRenewalDate || membership.renewalDueDate || membership.endDate || null;

    await db.collection('membermemberships').updateOne(
      { _id: membership._id },
      {
        $set: {
          membershipTemplateId,
          status,
          paymentStatus,
          nextRenewalDate,
          entitlementsSnapshot: buildEntitlements(membership, legacyPlan),
          isActiveBaseMembership: false,
        },
        $unset: {
          planId: '',
          planName: '',
          renewalDueDate: '',
          addOns: '',
          lastPaymentAt: '',
        },
      },
    );

    stats.membershipsConverted += 1;

    if (!terminalStatuses.has(status)) {
      const memberKey = `${gymId}:${membership.memberId}`;
      if (!convertedByMember.has(memberKey)) convertedByMember.set(memberKey, []);
      convertedByMember.get(memberKey).push({
        ...membership,
        status,
      });
    }
  }

  for (const candidates of convertedByMember.values()) {
    const [winner] = candidates.sort((a, b) => {
      const rankDiff = baseMembershipRank(a) - baseMembershipRank(b);
      if (rankDiff !== 0) return rankDiff;
      return toTime(b.updatedAt || b.createdAt) - toTime(a.updatedAt || a.createdAt);
    });
    if (!winner) continue;
    await db.collection('membermemberships').updateOne(
      { _id: winner._id },
      { $set: { isActiveBaseMembership: true } },
    );
    stats.activeBaseAssigned += 1;
  }

  return stats;
}

async function migrate() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/gymmate';
  await mongoose.connect(mongoUri);
  console.log('Connected to MongoDB');

  try {
    const db = mongoose.connection.db;

    const collections = await db.listCollections().toArray();
    const colNames = collections.map((collection) => collection.name);

    if (colNames.includes('membermemberships')) {
      const indexes = await db.collection('membermemberships').indexes();
      for (const idx of indexes) {
        if (idx.name !== '_id_' && idx.unique && idx.key.memberId) {
          await db.collection('membermemberships').dropIndex(idx.name);
          console.log('Dropped old unique index on MemberMembership.memberId');
        }
      }
    }

    console.log('Backfilling legacy memberships...');
    const stats = await backfillMemberships(db);
    console.log('Membership backfill summary:', stats);

    console.log('Creating indexes...');

    try { await MembershipTemplate.createIndexes(); } catch (e) { console.log('MembershipTemplate:', e.message); }
    console.log('MembershipTemplate indexes created');

    try { await MemberMembership.createIndexes(); } catch (e) { console.log('MemberMembership:', e.message); }
    console.log('MemberMembership indexes created');

    try { await MembershipChangeRequest.createIndexes(); } catch (e) { console.log('MembershipChangeRequest:', e.message); }
    console.log('MembershipChangeRequest indexes created');

    try { await MembershipAuditLog.createIndexes(); } catch (e) { console.log('MembershipAuditLog:', e.message); }
    console.log('MembershipAuditLog indexes created');

    console.log('Migration completed successfully!');
  } catch (error) {
    console.error('Migration error:', error);
    throw error;
  } finally {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  }
}

migrate().catch((error) => {
  console.error(error);
  process.exit(1);
});
