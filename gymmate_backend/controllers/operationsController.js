const crypto = require('crypto');
const Announcement = require('../models/Announcement');
const AnnouncementDelivery = require('../models/AnnouncementDelivery');
const AttendanceEvent = require('../models/AttendanceEvent');
const BiometricIntegration = require('../models/BiometricIntegration');
const MediaAsset = require('../models/MediaAsset');
const MemberMembership = require('../models/MemberMembership');
const MembershipChangeRequest = require('../models/MembershipChangeRequest');
const MembershipPlanCatalog = require('../models/MembershipPlanCatalog');
const MembershipRequest = require('../models/MembershipRequest');
const MembershipTemplate = require('../models/MembershipTemplate');
const PaymentEntry = require('../models/PaymentEntry');
const User = require('../models/User');
const { serializeActiveMembershipSummary } = require('../utils/membershipSummary');
const { hasPermission, hasRole } = require('../utils/roles');

const BIOMETRIC_PROVIDERS = [
  {
    key: 'identix',
    label: 'Identix',
    mode: 'attendance_sync',
  },
];

const MAX_IMAGE_BYTES = 1024 * 1024;
const IMAGE_TTL_DAYS = 30;
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

function validationError(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

function canManageWorkspace(user) {
  return hasPermission(user, 'workspace.access') || hasRole(user, ['owner']);
}

function canManageAnnouncements(user) {
  return hasPermission(user, 'announcements.manage') || hasRole(user, ['owner']);
}

function canManagePlans(user) {
  return hasPermission(user, 'membership.plans.manage') || hasRole(user, ['owner']);
}

function canManageRequests(user) {
  return hasPermission(user, 'membership.requests.manage') || hasRole(user, ['owner']);
}

function canManagePayments(user) {
  return hasPermission(user, 'payments.manage') || hasRole(user, ['owner']);
}

function canManageBiometric(user) {
  return hasPermission(user, 'biometric.manage') || hasRole(user, ['owner']);
}

function normalizePagination(query) {
  const page = Math.max(1, Number(query.page || 1) || 1);
  const limit = Math.min(50, Math.max(1, Number(query.limit || 25) || 25));
  return { page, limit, skip: (page - 1) * limit };
}

function escapeRegExp(value) {
  return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function parseObjectIdStrings(values) {
  return Array.isArray(values)
    ? values.map((value) => String(value || '').trim()).filter(Boolean)
    : [];
}

async function fetchPlanMap(gymId) {
  const plans = await MembershipPlanCatalog.find({ gymId }).lean();
  return plans.reduce((acc, plan) => {
    acc[String(plan._id)] = plan;
    return acc;
  }, {});
}

async function getMembershipMap(memberIds) {
  const memberships = await MemberMembership.find({
    memberId: { $in: memberIds },
  })
    .populate('membershipTemplateId', 'name category')
    .sort({ isActiveBaseMembership: -1, updatedAt: -1, createdAt: -1 })
    .lean();
  return memberships.reduce((acc, membership) => {
    const key = String(membership.memberId);
    if (!acc[key]) {
      acc[key] = membership;
    }
    return acc;
  }, {});
}

async function getPendingRequestCountMap(memberIds) {
  const [legacyRows, newRows] = await Promise.all([
    MembershipRequest.aggregate([
      {
        $match: {
          memberId: { $in: memberIds },
          status: { $in: ['pending', 'approved', 'payment_pending'] },
        },
      },
      {
        $group: {
          _id: '$memberId',
          count: { $sum: 1 },
        },
      },
    ]),
    MembershipChangeRequest.aggregate([
      {
        $match: {
          memberId: { $in: memberIds },
          status: { $in: ['submitted', 'awaiting_payment', 'payment_under_review'] },
        },
      },
      {
        $group: {
          _id: '$memberId',
          count: { $sum: 1 },
        },
      },
    ]),
  ]);

  return [...legacyRows, ...newRows].reduce((acc, row) => {
    const key = String(row._id);
    acc[key] = (acc[key] || 0) + Number(row.count || 0);
    return acc;
  }, {});
}

async function fetchHybridPlanMap(gymId) {
  const [legacyPlans, newPlans] = await Promise.all([
    MembershipPlanCatalog.find({ gymId }).lean(),
    MembershipTemplate.find({ gymId, active: true }).lean(),
  ]);

  const acc = {};
  for (const plan of legacyPlans) {
    acc[String(plan._id)] = plan;
  }
  for (const plan of newPlans) {
    acc[String(plan._id)] = {
      ...plan,
      includedServices: plan.includedServices || [],
      addOns: {
        training: Boolean(plan.availableAddOns?.personalTraining),
        diet: Boolean(plan.availableAddOns?.dietPlan),
      },
      renewalLeadDays: plan.renewalLeadDays,
    };
  }
  return acc;
}

async function getLatestAttendanceMap(memberIds) {
  const rows = await AttendanceEvent.aggregate([
    {
      $match: {
        memberId: { $in: memberIds },
      },
    },
    {
      $sort: {
        occurredAt: -1,
      },
    },
    {
      $group: {
        _id: '$memberId',
        occurredAt: { $first: '$occurredAt' },
      },
    },
  ]);

  return rows.reduce((acc, row) => {
    acc[String(row._id)] = row.occurredAt;
    return acc;
  }, {});
}

function parseImagePayload({ imageBase64, imageContentType, imageFileName }) {
  if (!imageBase64) {
    return null;
  }

  const contentType = String(imageContentType || 'image/png').toLowerCase();
  if (!ALLOWED_IMAGE_TYPES.has(contentType)) {
    throw validationError('Image must be a JPEG, PNG, or WebP file.');
  }

  const buffer = Buffer.from(String(imageBase64), 'base64');
  if (!buffer.length || buffer.length > MAX_IMAGE_BYTES) {
    throw validationError('Image must be smaller than 1 MB.');
  }

  return {
    buffer,
    contentType,
    fileName: String(imageFileName || 'announcement-image'),
    contentHash: crypto.createHash('sha256').update(buffer).digest('hex'),
  };
}

async function ensureMediaAsset(gymId, userId, payload) {
  if (!payload) {
    return null;
  }

  const existing = await MediaAsset.findOne({
    gymId,
    contentHash: payload.contentHash,
  });

  if (existing) {
    return existing;
  }

  return MediaAsset.create({
    gymId,
    uploadedBy: userId,
    fileName: payload.fileName,
    contentType: payload.contentType,
    contentHash: payload.contentHash,
    sizeBytes: payload.buffer.length,
    data: payload.buffer,
    expiresAt: new Date(Date.now() + IMAGE_TTL_DAYS * 24 * 60 * 60 * 1000),
  });
}

function buildAudienceFilter(scope, memberIds) {
  if (scope === 'selected' && memberIds.length) {
    return { _id: { $in: memberIds } };
  }
  return {};
}

function mergeMembershipStatusFilter(scope) {
  if (scope === 'active') {
    return new Set(['active', 'expiring', 'renewal_due']);
  }
  if (scope === 'inactive') {
    return new Set([
      'inactive',
      'expired',
      'payment_pending',
      'pending_payment',
      'pending_approval',
      'frozen',
      'canceled',
      'rejected',
    ]);
  }
  return null;
}

async function resolveAudienceMembers(gymId, scope, memberIds) {
  const filter = {
    gymId,
    role: 'gym_member',
    ...buildAudienceFilter(scope, memberIds),
  };

  const members = await User.find(filter)
    .select('name email gymId')
    .lean();

  const membershipMap = await getMembershipMap(members.map((member) => member._id));
  const statusFilter = mergeMembershipStatusFilter(scope);

  if (!statusFilter) {
    return members;
  }

  return members.filter((member) => {
    const status = membershipMap[String(member._id)]?.status || 'inactive';
    return statusFilter.has(status);
  });
}

function assetUrlForRole(role, assetId) {
  if (!assetId) return null;
  return role === 'member'
    ? `/api/member/assets/${assetId}`
    : `/api/owner/assets/${assetId}`;
}

exports.getMemberWorkspace = async (req, res) => {
  if (!canManageWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: workspace access required' });
  }

  try {
    const { page, limit, skip } = normalizePagination(req.query);
    const search = String(req.query.search || '').trim();
    const status = String(req.query.status || 'all').trim().toLowerCase();

    const filter = {
      gymId: req.user.gymId,
      role: 'gym_member',
    };

    if (search) {
      const pattern = new RegExp(escapeRegExp(search), 'i');
      filter.$or = [{ name: pattern }, { email: pattern }];
    }

    const [planMap, members, total] = await Promise.all([
      fetchHybridPlanMap(req.user.gymId),
      User.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .select('name email createdAt updatedAt fitnessGoals gymId role')
        .lean(),
      User.countDocuments(filter),
    ]);

    const memberIds = members.map((member) => member._id);
    const [membershipMap, pendingRequestCountMap, attendanceMap] = await Promise.all([
      getMembershipMap(memberIds),
      getPendingRequestCountMap(memberIds),
      getLatestAttendanceMap(memberIds),
    ]);

    const rows = members
      .map((member) => {
        const membership = membershipMap[String(member._id)] || null;
        const serializedMembership = serializeActiveMembershipSummary(membership);
        return {
          id: member._id,
          name: member.name,
          email: member.email,
          role: member.role,
          createdAt: member.createdAt,
          fitnessGoals: member.fitnessGoals || [],
          membership: serializedMembership,
          pendingRequestCount: pendingRequestCountMap[String(member._id)] || 0,
          lastAttendanceAt: attendanceMap[String(member._id)] || null,
          activeState:
            serializedMembership.status === 'active' ||
            serializedMembership.status === 'expiring' ||
            serializedMembership.status === 'renewal_due'
              ? 'active'
              : 'inactive',
        };
      })
      .filter((row) => {
        if (status === 'all') return true;
        if (status === 'active') return row.activeState === 'active';
        if (status === 'inactive') return row.activeState === 'inactive';
        if (status === 'expiring') {
          return ['expiring', 'renewal_due'].includes(row.membership.status);
        }
        return true;
      });

    return res.status(200).json({
      members: rows,
      plans: Object.values(planMap).map((plan) => ({
        id: plan._id,
        name: plan.name,
        durationDays: plan.durationDays,
        includedServices: plan.includedServices || [],
        renewalLeadDays: plan.renewalLeadDays,
        addOns: {
          training: Boolean(plan.addOns?.training),
          diet: Boolean(plan.addOns?.diet),
        },
      })),
      summary: {
        activeCount: rows.filter((row) => row.activeState === 'active').length,
        inactiveCount: rows.filter((row) => row.activeState === 'inactive').length,
        pendingRequestCount: rows.reduce((sum, row) => sum + row.pendingRequestCount, 0),
      },
      pagination: {
        page,
        limit,
        total,
        hasMore: skip + rows.length < total,
      },
    });
  } catch (error) {
    console.error('Error fetching member workspace:', error);
    return res.status(500).json({ message: 'Error fetching member workspace' });
  }
};

exports.assignMemberMembership = async (req, res) => {
  if (!canManageWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: member management required' });
  }

  try {
    const { memberId } = req.params;
    const {
      planId = null,
      status = 'inactive',
      paymentStatus = 'none',
      startDate = null,
      endDate = null,
      renewalDueDate = null,
      addOns = {},
      notes = '',
    } = req.body || {};

    const [member, plan] = await Promise.all([
      User.findOne({ _id: memberId, gymId: req.user.gymId, role: 'gym_member' }),
      planId
        ? MembershipPlanCatalog.findOne({ _id: planId, gymId: req.user.gymId })
        : Promise.resolve(null),
    ]);

    if (!member) {
      return res.status(404).json({ message: 'Member not found' });
    }
    if (planId && !plan) {
      return res.status(404).json({ message: 'Membership plan not found' });
    }

    const membership = await MemberMembership.findOneAndUpdate(
      { memberId: member._id },
      {
        $set: {
          gymId: req.user.gymId,
          memberId: member._id,
          planId: plan?._id || null,
          planName: plan?.name || '',
          status,
          paymentStatus,
          startDate: startDate ? new Date(startDate) : null,
          endDate: endDate ? new Date(endDate) : null,
          renewalDueDate: renewalDueDate
            ? new Date(renewalDueDate)
            : endDate
              ? new Date(endDate)
              : null,
          addOns: {
            training: Boolean(addOns.training),
            diet: Boolean(addOns.diet),
          },
          notes: String(notes || ''),
        },
      },
      {
        new: true,
        upsert: true,
        setDefaultsOnInsert: true,
      },
    ).lean();

    return res.status(200).json({
      message: 'Membership updated successfully.',
      membership: serializeActiveMembershipSummary(membership, plan),
    });
  } catch (error) {
    console.error('Error assigning membership:', error);
    return res.status(500).json({ message: 'Error updating membership' });
  }
};

exports.listAnnouncements = async (req, res) => {
  if (!canManageAnnouncements(req.user)) {
    return res.status(403).json({ message: 'Forbidden: announcements access required' });
  }

  try {
    const { page, limit, skip } = normalizePagination(req.query);
    const announcements = await Announcement.find({ gymId: req.user.gymId })
      .sort({ sentAt: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    return res.status(200).json({
      announcements: announcements.map((announcement) => ({
        id: announcement._id,
        type: announcement.type,
        title: announcement.title,
        body: announcement.body,
        audience: announcement.audience,
        status: announcement.status,
        sentAt: announcement.sentAt,
        deliverySummary: announcement.deliverySummary || {},
        mediaAssetId: announcement.mediaAssetId || null,
        mediaUrl: assetUrlForRole('owner', announcement.mediaAssetId),
      })),
    });
  } catch (error) {
    console.error('Error listing announcements:', error);
    return res.status(500).json({ message: 'Error listing announcements' });
  }
};

exports.createAnnouncement = async (req, res) => {
  if (!canManageAnnouncements(req.user)) {
    return res.status(403).json({ message: 'Forbidden: announcements access required' });
  }

  try {
    const {
      title,
      body,
      type = 'general',
      audienceScope = 'all',
      memberIds = [],
      imageBase64 = null,
      imageContentType = null,
      imageFileName = null,
    } = req.body || {};

    if (!title || !body) {
      return res.status(400).json({ message: 'Title and body are required' });
    }

    const mediaPayload = parseImagePayload({
      imageBase64,
      imageContentType,
      imageFileName,
    });
    const mediaAsset = await ensureMediaAsset(req.user.gymId, req.user._id, mediaPayload);
    const audienceMembers = await resolveAudienceMembers(
      req.user.gymId,
      audienceScope,
      parseObjectIdStrings(memberIds),
    );

    const announcement = await Announcement.create({
      gymId: req.user.gymId,
      createdBy: req.user._id,
      type,
      title: String(title).trim(),
      body: String(body).trim(),
      audience: {
        scope: audienceScope,
        memberIds: audienceScope === 'selected' ? audienceMembers.map((member) => member._id) : [],
      },
      mediaAssetId: mediaAsset?._id || null,
      status: 'sent',
      sentAt: new Date(),
      deliverySummary: {
        targetedCount: audienceMembers.length,
        deliveredCount: audienceMembers.length,
        readCount: 0,
        telegramCount: 0,
      },
    });

    if (audienceMembers.length) {
      await AnnouncementDelivery.insertMany(
        audienceMembers.map((member) => ({
          announcementId: announcement._id,
          gymId: req.user.gymId,
          memberId: member._id,
          inAppStatus: 'delivered',
          telegramStatus: 'skipped',
        })),
      );
    }

    return res.status(201).json({
      message: 'Announcement sent successfully.',
      announcement: {
        id: announcement._id,
        title: announcement.title,
        body: announcement.body,
        type: announcement.type,
        audience: announcement.audience,
        sentAt: announcement.sentAt,
        mediaAssetId: announcement.mediaAssetId,
        mediaUrl: assetUrlForRole('owner', announcement.mediaAssetId),
        deliverySummary: announcement.deliverySummary,
      },
    });
  } catch (error) {
    console.error('Error creating announcement:', error);
    return res.status(error.statusCode || 500).json({
      message: error.message || 'Error creating announcement',
    });
  }
};

exports.listMembershipPlans = async (req, res) => {
  if (!canManageWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: workspace access required' });
  }

  try {
    const plans = await MembershipPlanCatalog.find({ gymId: req.user.gymId })
      .sort({ active: -1, name: 1 })
      .lean();

    return res.status(200).json({
      plans: plans.map((plan) => ({
        id: plan._id,
        name: plan.name,
        description: plan.description || '',
        durationDays: plan.durationDays,
        price: plan.price || 0,
        includedServices: plan.includedServices || [],
        renewalLeadDays: plan.renewalLeadDays,
        active: Boolean(plan.active),
        addOns: {
          training: Boolean(plan.addOns?.training),
          diet: Boolean(plan.addOns?.diet),
        },
      })),
    });
  } catch (error) {
    console.error('Error listing membership plans:', error);
    return res.status(500).json({ message: 'Error listing membership plans' });
  }
};

exports.upsertMembershipPlan = async (req, res) => {
  if (!canManagePlans(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership plan access required' });
  }

  try {
    const {
      name,
      description = '',
      durationDays,
      price = 0,
      includedServices = [],
      renewalLeadDays = 7,
      active = true,
      addOns = {},
    } = req.body || {};

    if (!name || !durationDays) {
      return res.status(400).json({ message: 'Name and duration are required' });
    }

    const payload = {
      gymId: req.user.gymId,
      createdBy: req.user._id,
      name: String(name).trim(),
      description: String(description || '').trim(),
      durationDays: Number(durationDays),
      price: Number(price || 0),
      includedServices: Array.isArray(includedServices)
        ? includedServices.map((entry) => String(entry).trim()).filter(Boolean)
        : [],
      renewalLeadDays: Number(renewalLeadDays || 7),
      active: Boolean(active),
      addOns: {
        training: Boolean(addOns.training),
        diet: Boolean(addOns.diet),
      },
    };

    const plan = req.params.planId
      ? await MembershipPlanCatalog.findOneAndUpdate(
          { _id: req.params.planId, gymId: req.user.gymId },
          { $set: payload },
          { new: true },
        )
      : await MembershipPlanCatalog.create(payload);

    return res.status(200).json({
      message: 'Membership plan saved successfully.',
      plan,
    });
  } catch (error) {
    console.error('Error saving membership plan:', error);
    return res.status(500).json({ message: 'Error saving membership plan' });
  }
};

exports.listMembershipRequests = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const requests = await MembershipRequest.find({ gymId: req.user.gymId })
      .sort({ createdAt: -1 })
      .populate('memberId', 'name email')
      .populate('targetPlanId', 'name')
      .lean();

    return res.status(200).json({
      requests: requests.map((request) => ({
        id: request._id,
        requestType: request.requestType,
        status: request.status,
        note: request.note || '',
        response: request.response || '',
        createdAt: request.createdAt,
        handledAt: request.handledAt || null,
        member: request.memberId
          ? {
              id: request.memberId._id,
              name: request.memberId.name,
              email: request.memberId.email,
            }
          : null,
        targetPlan: request.targetPlanId
          ? {
              id: request.targetPlanId._id,
              name: request.targetPlanId.name,
            }
          : null,
      })),
    });
  } catch (error) {
    console.error('Error listing membership requests:', error);
    return res.status(500).json({ message: 'Error listing membership requests' });
  }
};

exports.getMembershipRequest = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const request = await MembershipRequest.findOne({
      _id: req.params.requestId,
      gymId: req.user.gymId,
    })
      .populate('memberId', 'name email')
      .populate('targetPlanId', 'name description durationDays price includedServices addOns renewalLeadDays')
      .populate('handledBy', 'name')
      .lean();

    if (!request) {
      return res.status(404).json({ message: 'Request not found' });
    }

    let memberMembership = null;
    if (request.memberId) {
      memberMembership = await MemberMembership.findOne({
        gymId: req.user.gymId,
        memberId: request.memberId._id,
      })
        .populate('membershipTemplateId', 'name category')
        .sort({ isActiveBaseMembership: -1, updatedAt: -1, createdAt: -1 })
        .lean();
    }

    return res.status(200).json({
      request: {
        id: request._id,
        requestType: request.requestType,
        status: request.status,
        note: request.note || '',
        response: request.response || '',
        createdAt: request.createdAt,
        handledAt: request.handledAt || null,
        member: request.memberId
          ? {
              id: request.memberId._id,
              name: request.memberId.name,
              email: request.memberId.email,
            }
          : null,
        targetPlan: request.targetPlanId
          ? {
              id: request.targetPlanId._id,
              name: request.targetPlanId.name,
              description: request.targetPlanId.description || '',
              durationDays: request.targetPlanId.durationDays,
              price: request.targetPlanId.price || 0,
              includedServices: request.targetPlanId.includedServices || [],
              addOns: request.targetPlanId.addOns || {},
              renewalLeadDays: request.targetPlanId.renewalLeadDays,
            }
          : null,
        handledBy: request.handledBy
          ? {
              name: request.handledBy.name,
            }
          : null,
      },
      memberMembership: memberMembership ? serializeActiveMembershipSummary(memberMembership) : null,
    });
  } catch (error) {
    console.error('Error fetching membership request:', error);
    return res.status(500).json({ message: 'Error fetching membership request' });
  }
};

exports.updateMembershipRequest = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const { status, response = '' } = req.body || {};
    const request = await MembershipRequest.findOneAndUpdate(
      { _id: req.params.requestId, gymId: req.user.gymId },
      {
        $set: {
          status: String(status || 'pending'),
          response: String(response || ''),
          handledBy: req.user._id,
          handledAt: new Date(),
        },
      },
      { new: true },
    ).lean();

    if (!request) {
      return res.status(404).json({ message: 'Request not found' });
    }

    return res.status(200).json({
      message: 'Membership request updated successfully.',
      request,
    });
  } catch (error) {
    console.error('Error updating membership request:', error);
    return res.status(500).json({ message: 'Error updating membership request' });
  }
};

exports.recordPayment = async (req, res) => {
  if (!canManagePayments(req.user)) {
    return res.status(403).json({ message: 'Forbidden: payment access required' });
  }

  try {
    const {
      memberId,
      membershipId = null,
      membershipRequestId = null,
      amount,
      mode,
      reference = '',
      note = '',
      activate = false,
    } = req.body || {};

    if (!memberId || amount == null || !mode) {
      return res.status(400).json({ message: 'memberId, amount, and mode are required' });
    }

    const payment = await PaymentEntry.create({
      gymId: req.user.gymId,
      memberId,
      membershipId,
      membershipRequestId,
      amount: Number(amount),
      mode: String(mode),
      reference: String(reference || ''),
      note: String(note || ''),
      recordedBy: req.user._id,
      recordedAt: new Date(),
    });

    let membership = null;
    if (membershipId) {
      membership = await MemberMembership.findOneAndUpdate(
        { _id: membershipId, gymId: req.user.gymId },
        {
          $set: {
            paymentStatus: 'paid',
            lastPaymentAt: new Date(),
            ...(activate ? { status: 'active' } : {}),
          },
        },
        { new: true },
      ).lean();
    }

    if (membershipRequestId) {
      await MembershipRequest.updateOne(
        { _id: membershipRequestId, gymId: req.user.gymId },
        {
          $set: {
            status: activate ? 'activated' : 'approved',
            handledBy: req.user._id,
            handledAt: new Date(),
            response: activate
              ? 'Payment confirmed and membership activated.'
              : 'Payment confirmed.',
          },
        },
      );
    }

    return res.status(201).json({
      message: 'Payment recorded successfully.',
      payment,
      membership: membership ? serializeActiveMembershipSummary(membership) : null,
    });
  } catch (error) {
    console.error('Error recording payment:', error);
    return res.status(500).json({ message: 'Error recording payment' });
  }
};

exports.listBiometricProviders = async (_req, res) => {
  return res.status(200).json({ providers: BIOMETRIC_PROVIDERS });
};

exports.getBiometricSettings = async (req, res) => {
  if (!canManageBiometric(req.user)) {
    return res.status(403).json({ message: 'Forbidden: biometric access required' });
  }

  try {
    const integration = await BiometricIntegration.findOne({
      gymId: req.user.gymId,
    }).lean();

    return res.status(200).json({
      integration: integration || {
        providerKey: 'identix',
        enabled: false,
        config: {},
        lastSyncAt: null,
        lastSyncStatus: 'never',
        lastSyncError: '',
      },
      providers: BIOMETRIC_PROVIDERS,
    });
  } catch (error) {
    console.error('Error loading biometric settings:', error);
    return res.status(500).json({ message: 'Error loading biometric settings' });
  }
};

exports.upsertBiometricSettings = async (req, res) => {
  if (!canManageBiometric(req.user)) {
    return res.status(403).json({ message: 'Forbidden: biometric access required' });
  }

  try {
    const { providerKey = 'identix', enabled = false, config = {} } = req.body || {};
    const integration = await BiometricIntegration.findOneAndUpdate(
      { gymId: req.user.gymId },
      {
        $set: {
          providerKey,
          enabled: Boolean(enabled),
          config,
        },
      },
      {
        new: true,
        upsert: true,
        setDefaultsOnInsert: true,
      },
    ).lean();

    return res.status(200).json({
      message: 'Biometric settings updated successfully.',
      integration,
    });
  } catch (error) {
    console.error('Error saving biometric settings:', error);
    return res.status(500).json({ message: 'Error saving biometric settings' });
  }
};

exports.syncBiometricPilot = async (req, res) => {
  if (!canManageBiometric(req.user)) {
    return res.status(403).json({ message: 'Forbidden: biometric access required' });
  }

  try {
    const integration = await BiometricIntegration.findOneAndUpdate(
      { gymId: req.user.gymId },
      {
        $set: {
          lastSyncAt: new Date(),
          lastSyncStatus: 'success',
          lastSyncError: '',
        },
      },
      {
        new: true,
        upsert: true,
        setDefaultsOnInsert: true,
      },
    ).lean();

    return res.status(200).json({
      message: 'Pilot biometric sync completed.',
      integration,
      importedCount: 0,
    });
  } catch (error) {
    console.error('Error syncing biometric pilot:', error);
    return res.status(500).json({ message: 'Error syncing biometric pilot' });
  }
};

exports.streamMediaAssetForOwner = async (req, res) => {
  if (!canManageWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: workspace access required' });
  }

  try {
    const asset = await MediaAsset.findOne({
      _id: req.params.assetId,
      gymId: req.user.gymId,
    }).select('+data');

    if (!asset) {
      return res.status(404).json({ message: 'Asset not found' });
    }

    res.setHeader('Content-Type', asset.contentType);
    res.setHeader('Content-Length', asset.sizeBytes);
    return res.status(200).send(asset.data);
  } catch (error) {
    console.error('Error streaming media asset:', error);
    return res.status(500).json({ message: 'Error loading asset' });
  }
};

exports.listMemberAnnouncements = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const { page, limit, skip } = normalizePagination(req.query);
    const deliveries = await AnnouncementDelivery.find({
      memberId: req.user._id,
      gymId: req.user.gymId,
    })
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .populate('announcementId')
      .lean();

    return res.status(200).json({
      deliveries: deliveries
        .filter((delivery) => delivery.announcementId)
        .map((delivery) => ({
          id: delivery._id,
          inAppStatus: delivery.inAppStatus,
          readAt: delivery.readAt,
          createdAt: delivery.createdAt,
          announcement: {
            id: delivery.announcementId._id,
            type: delivery.announcementId.type,
            title: delivery.announcementId.title,
            body: delivery.announcementId.body,
            sentAt: delivery.announcementId.sentAt,
            mediaAssetId: delivery.announcementId.mediaAssetId || null,
            mediaUrl: assetUrlForRole('member', delivery.announcementId.mediaAssetId),
          },
        })),
    });
  } catch (error) {
    console.error('Error listing member announcements:', error);
    return res.status(500).json({ message: 'Error loading announcements' });
  }
};

exports.markAnnouncementRead = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const delivery = await AnnouncementDelivery.findOneAndUpdate(
      {
        _id: req.params.deliveryId,
        memberId: req.user._id,
        gymId: req.user.gymId,
      },
      {
        $set: {
          inAppStatus: 'read',
          readAt: new Date(),
        },
      },
      { new: true },
    ).lean();

    if (!delivery) {
      return res.status(404).json({ message: 'Announcement not found' });
    }

    await Announcement.updateOne(
      { _id: delivery.announcementId },
      { $inc: { 'deliverySummary.readCount': 1 } },
    );

    return res.status(200).json({ message: 'Announcement marked as read.' });
  } catch (error) {
    console.error('Error marking announcement as read:', error);
    return res.status(500).json({ message: 'Error updating announcement status' });
  }
};

exports.getMemberMembershipSummary = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const [membership, plans, requests] = await Promise.all([
      MemberMembership.findOne({
        memberId: req.user._id,
        $or: [
          { isActiveBaseMembership: true },
          { status: { $in: ['active', 'renewal_due', 'scheduled'] }, paymentStatus: { $in: ['paid', 'waived'] } },
        ],
      })
        .sort({ isActiveBaseMembership: -1, activatedAt: -1, updatedAt: -1 })
        .populate('membershipTemplateId', 'name category price')
        .lean(),
      MembershipPlanCatalog.find({ gymId: req.user.gymId, active: true })
        .sort({ name: 1 })
        .lean(),
      MembershipRequest.find({ memberId: req.user._id })
        .sort({ createdAt: -1 })
        .limit(10)
        .populate('targetPlanId', 'name')
        .lean(),
    ]);

    const planMap = plans.reduce((acc, plan) => {
      acc[String(plan._id)] = plan;
      return acc;
    }, {});

    return res.status(200).json({
      membership: serializeActiveMembershipSummary(
        membership,
        membership?.planId ? planMap[String(membership.planId)] : null,
      ),
      availablePlans: plans.map((plan) => ({
        id: plan._id,
        name: plan.name,
        description: plan.description || '',
        durationDays: plan.durationDays,
        includedServices: plan.includedServices || [],
        renewalLeadDays: plan.renewalLeadDays,
        addOns: {
          training: Boolean(plan.addOns?.training),
          diet: Boolean(plan.addOns?.diet),
        },
      })),
      requests: requests.map((request) => ({
        id: request._id,
        requestType: request.requestType,
        status: request.status,
        note: request.note || '',
        response: request.response || '',
        createdAt: request.createdAt,
        targetPlan: request.targetPlanId
          ? {
              id: request.targetPlanId._id,
              name: request.targetPlanId.name,
            }
          : null,
      })),
    });
  } catch (error) {
    console.error('Error loading member membership summary:', error);
    return res.status(500).json({ message: 'Error loading membership summary' });
  }
};

exports.createMemberMembershipRequest = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const { requestType, targetPlanId = null, note = '' } = req.body || {};
    if (!requestType) {
      return res.status(400).json({ message: 'requestType is required' });
    }

    const membership = await MemberMembership.findOne({ memberId: req.user._id }).lean();
    const request = await MembershipRequest.create({
      gymId: req.user.gymId,
      memberId: req.user._id,
      membershipId: membership?._id || null,
      requestType,
      targetPlanId,
      note: String(note || '').trim(),
      status: 'pending',
    });

    return res.status(201).json({
      message: 'Request submitted successfully.',
      request,
    });
  } catch (error) {
    console.error('Error creating member request:', error);
    return res.status(500).json({ message: 'Error creating request' });
  }
};

exports.streamMediaAssetForMember = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const delivery = await AnnouncementDelivery.findOne({
      memberId: req.user._id,
      gymId: req.user.gymId,
    })
      .populate('announcementId', 'mediaAssetId')
      .lean();

    const allowedAssetIds = new Set(
      delivery?.announcementId?.mediaAssetId
        ? [String(delivery.announcementId.mediaAssetId)]
        : [],
    );

    if (!allowedAssetIds.has(String(req.params.assetId))) {
      const matchingDelivery = await AnnouncementDelivery.findOne({
        memberId: req.user._id,
        gymId: req.user.gymId,
      })
        .populate({
          path: 'announcementId',
          match: { mediaAssetId: req.params.assetId },
          select: 'mediaAssetId',
        })
        .lean();

      if (!matchingDelivery?.announcementId) {
        return res.status(404).json({ message: 'Asset not found' });
      }
    }

    const asset = await MediaAsset.findOne({
      _id: req.params.assetId,
      gymId: req.user.gymId,
    }).select('+data');

    if (!asset) {
      return res.status(404).json({ message: 'Asset not found' });
    }

    res.setHeader('Content-Type', asset.contentType);
    res.setHeader('Content-Length', asset.sizeBytes);
    return res.status(200).send(asset.data);
  } catch (error) {
    console.error('Error streaming member media asset:', error);
    return res.status(500).json({ message: 'Error loading asset' });
  }
};
