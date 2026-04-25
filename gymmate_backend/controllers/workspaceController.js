const crypto = require('crypto');
const mongoose = require('mongoose');
const AttendanceEvent = require('../models/AttendanceEvent');
const BillingReceipt = require('../models/BillingReceipt');
const ClassBooking = require('../models/ClassBooking');
const ClassSession = require('../models/ClassSession');
const ClassTemplate = require('../models/ClassTemplate');
const Invoice = require('../models/Invoice');
const Lead = require('../models/Lead');
const LeadActivity = require('../models/LeadActivity');
const MemberMembership = require('../models/MemberMembership');
const MembershipChangeRequest = require('../models/MembershipChangeRequest');
const PaymentEntry = require('../models/PaymentEntry');
const StaffActivityLog = require('../models/StaffActivityLog');
const TrainerAssignment = require('../models/TrainerAssignment');
const User = require('../models/User');
const { getPermissions, hasPermission, hasRole } = require('../utils/roles');

const MEMBER_SELECT = 'name email phone_number role gymId accountStatus joinDate profile fitnessGoals dietPreferences customMealPlan customWorkoutPlan createdAt updatedAt';
const STAFF_SELECT = 'name email phone_number role gymId accountStatus staffCapabilities createdAt updatedAt';
const PAYMENT_MODES = new Set(['cash', 'upi', 'card', 'online', 'manual', 'waived']);

function clientError(message, statusCode = 400) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function canAccessWorkspace(user) {
  return (
    hasRole(user, ['admin', 'owner']) ||
    hasPermission(user, 'workspace.access') ||
    hasPermission(user, 'members.view')
  );
}

function canManage(user, permission) {
  return hasRole(user, ['admin', 'owner']) || hasPermission(user, permission);
}

function escapeRegExp(value) {
  return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function asObjectId(value, label = 'id') {
  if (!value || !mongoose.Types.ObjectId.isValid(value)) {
    throw clientError(`Valid ${label} is required.`);
  }
  return new mongoose.Types.ObjectId(value);
}

function normalizeDate(value, fallback = null) {
  if (!value) {
    return fallback;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? fallback : date;
}

function startOfToday() {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  return date;
}

function endOfToday() {
  const date = startOfToday();
  date.setDate(date.getDate() + 1);
  return date;
}

function resolveReadScope(req) {
  if (hasRole(req.user, ['admin'])) {
    return req.query.gymId ? { gymId: asObjectId(req.query.gymId, 'gymId'), network: false } : { gymId: null, network: true };
  }

  const gymId = req.user.gymId || req.user._id;
  return { gymId: asObjectId(gymId, 'gymId'), network: false };
}

function resolveWriteGymId(req) {
  if (hasRole(req.user, ['admin'])) {
    return asObjectId(req.body.gymId || req.query.gymId, 'gymId');
  }
  return asObjectId(req.user.gymId || req.user._id, 'gymId');
}

function scopeFilter(scope) {
  return scope.network ? {} : { gymId: scope.gymId };
}

function serializeUser(user) {
  if (!user) {
    return null;
  }
  return {
    id: user._id,
    name: user.name,
    email: user.email,
    phone: user.phone_number || user.profile?.phoneNumber || '',
    role: user.role,
    accountStatus: user.accountStatus || 'active',
    gymId: user.gymId || null,
    joinedAt: user.joinDate || user.createdAt,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

function serializeMembership(membership) {
  if (!membership) {
    return null;
  }
  return {
    id: membership._id,
    status: membership.status,
    paymentStatus: membership.paymentStatus,
    startDate: membership.startDate,
    endDate: membership.endDate,
    nextRenewalDate: membership.nextRenewalDate,
    isActiveBaseMembership: membership.isActiveBaseMembership,
    plan: membership.membershipTemplateId
      ? {
          id: membership.membershipTemplateId._id || membership.membershipTemplateId,
          name: membership.membershipTemplateId.name || 'Membership plan',
          category: membership.membershipTemplateId.category || '',
          price: membership.membershipTemplateId.price || 0,
        }
      : null,
    entitlements: membership.entitlementsSnapshot || {},
  };
}

function serializeLead(lead, activities = []) {
  return {
    id: lead._id,
    name: lead.name,
    email: lead.email || '',
    phone: lead.phone || '',
    source: lead.source,
    status: lead.status,
    interest: lead.interest || '',
    goal: lead.goal || '',
    preferredService: lead.preferredService || '',
    trialDate: lead.trialDate,
    nextFollowUpAt: lead.nextFollowUpAt,
    assignedTo: serializeUser(lead.assignedTo),
    convertedMemberId: lead.convertedMemberId || null,
    convertedAt: lead.convertedAt,
    lostReason: lead.lostReason || '',
    notes: lead.notes || '',
    createdAt: lead.createdAt,
    updatedAt: lead.updatedAt,
    activities: activities.map((activity) => ({
      id: activity._id,
      type: activity.type,
      note: activity.note,
      nextFollowUpAt: activity.nextFollowUpAt,
      createdAt: activity.createdAt,
      createdBy: serializeUser(activity.createdBy),
    })),
  };
}

function serializePayment(entry, receipt = null, invoice = null) {
  return {
    id: entry._id,
    amount: entry.amount || 0,
    mode: entry.mode,
    reference: entry.reference || '',
    note: entry.note || '',
    recordedAt: entry.recordedAt || entry.createdAt,
    member: serializeUser(entry.memberId),
    membershipId: entry.membershipId || null,
    membershipRequestId: entry.membershipRequestId || null,
    recordedBy: serializeUser(entry.recordedBy),
    receipt: receipt
      ? {
          id: receipt._id,
          receiptNumber: receipt.receiptNumber,
          publicToken: receipt.publicToken,
          issuedAt: receipt.issuedAt,
        }
      : null,
    invoice: invoice
      ? {
          id: invoice._id,
          invoiceNumber: invoice.invoiceNumber,
          status: invoice.status,
          total: invoice.total,
          gstin: invoice.gstin || '',
          hsnSac: invoice.hsnSac || '',
          issuedAt: invoice.issuedAt,
        }
      : null,
  };
}

function serializeClassTemplate(template) {
  return {
    id: template._id,
    name: template.name,
    type: template.type,
    description: template.description || '',
    trainer: serializeUser(template.trainerId),
    defaultCapacity: template.defaultCapacity,
    durationMinutes: template.durationMinutes,
    requiresMembership: template.requiresMembership,
    deductsEntitlement: template.deductsEntitlement,
    active: template.active,
    createdAt: template.createdAt,
    updatedAt: template.updatedAt,
  };
}

function serializeClassSession(session, bookings = []) {
  const activeBookings = bookings.filter((booking) => booking.status === 'booked' || booking.status === 'attended');
  return {
    id: session._id,
    template: session.templateId
      ? {
          id: session.templateId._id || session.templateId,
          name: session.templateId.name || 'Class',
          type: session.templateId.type || '',
        }
      : null,
    trainer: serializeUser(session.trainerId),
    startsAt: session.startsAt,
    endsAt: session.endsAt,
    capacity: session.capacity,
    bookedCount: activeBookings.length,
    availableSeats: Math.max(0, Number(session.capacity || 0) - activeBookings.length),
    status: activeBookings.length >= Number(session.capacity || 0) && session.status === 'open' ? 'full' : session.status,
    location: session.location || '',
    notes: session.notes || '',
    bookings: bookings.map((booking) => ({
      id: booking._id,
      status: booking.status,
      member: serializeUser(booking.memberId),
      bookedBy: serializeUser(booking.bookedBy),
      cancelledAt: booking.cancelledAt,
      attendedAt: booking.attendedAt,
      notes: booking.notes || '',
      createdAt: booking.createdAt,
    })),
  };
}

async function logStaffActivity(gymId, actorId, action, payload = {}, targetUserId = null, entityType = '', entityId = null) {
  await StaffActivityLog.create({
    gymId,
    actorId,
    targetUserId,
    action,
    entityType,
    entityId,
    payload,
  });
}

exports.getDashboard = async (req, res) => {
  if (!canAccessWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: workspace access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const base = scopeFilter(scope);
    const todayStart = startOfToday();
    const todayEnd = endOfToday();
    const renewalLimit = new Date();
    renewalLimit.setDate(renewalLimit.getDate() + 14);

    const [
      activeMembers,
      openLeads,
      todayCheckIns,
      paymentAgg,
      dueMemberships,
      expiringMemberships,
      pendingRequests,
      staffCount,
      classSessions,
      classBookings,
      recentLeads,
      recentPayments,
    ] = await Promise.all([
      User.countDocuments({ ...base, role: 'gym_member', accountStatus: { $ne: 'deactivated' } }),
      Lead.countDocuments({ ...base, status: { $in: ['new', 'contacted', 'trial_scheduled'] } }),
      AttendanceEvent.countDocuments({ ...base, eventType: 'check_in', occurredAt: { $gte: todayStart, $lt: todayEnd } }),
      PaymentEntry.aggregate([
        { $match: { ...base, recordedAt: { $gte: todayStart, $lt: todayEnd } } },
        { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } },
      ]),
      MemberMembership.countDocuments({ ...base, paymentStatus: { $in: ['unpaid', 'payment_under_review'] } }),
      MemberMembership.countDocuments({
        ...base,
        status: { $in: ['active', 'renewal_due'] },
        endDate: { $gte: todayStart, $lte: renewalLimit },
      }),
      MembershipChangeRequest.countDocuments({ ...base, status: { $in: ['submitted', 'awaiting_payment', 'payment_under_review'] } }),
      User.countDocuments({ ...base, role: { $in: ['gym_staff', 'gym_trainer'] }, accountStatus: { $ne: 'deactivated' } }),
      ClassSession.find({ ...base, startsAt: { $gte: todayStart, $lt: todayEnd } })
        .populate('templateId', 'name type')
        .populate('trainerId', STAFF_SELECT)
        .sort({ startsAt: 1 })
        .lean(),
      ClassBooking.find({ ...base, createdAt: { $gte: todayStart, $lt: todayEnd } }).lean(),
      Lead.find(base)
        .populate('assignedTo', STAFF_SELECT)
        .sort({ updatedAt: -1 })
        .limit(6)
        .lean(),
      PaymentEntry.find(base)
        .populate('memberId', MEMBER_SELECT)
        .populate('recordedBy', STAFF_SELECT)
        .sort({ recordedAt: -1 })
        .limit(6)
        .lean(),
    ]);

    const bookingCountBySession = classBookings.reduce((acc, booking) => {
      const key = String(booking.sessionId);
      acc[key] = (acc[key] || 0) + (['booked', 'attended'].includes(booking.status) ? 1 : 0);
      return acc;
    }, {});

    return res.json({
      scope,
      kpis: {
        activeMembers,
        openLeads,
        todayCheckIns,
        revenueToday: paymentAgg[0]?.total || 0,
        paymentsToday: paymentAgg[0]?.count || 0,
        dues: dueMemberships,
        expiringMemberships,
        pendingRequests,
        staffCount,
        classesToday: classSessions.length,
        classFillRate: classSessions.length
          ? Math.round(
              (classSessions.reduce((sum, session) => sum + (bookingCountBySession[String(session._id)] || 0), 0) /
                classSessions.reduce((sum, session) => sum + Number(session.capacity || 0), 0)) *
                100,
            )
          : 0,
      },
      queues: {
        leads: recentLeads.map((lead) => serializeLead(lead)),
        payments: recentPayments.map((entry) => serializePayment(entry)),
        classes: classSessions.map((session) =>
          serializeClassSession(
            session,
            classBookings.filter((booking) => String(booking.sessionId) === String(session._id)),
          ),
        ),
      },
    });
  } catch (error) {
    console.error('Workspace dashboard failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load workspace dashboard.' });
  }
};

exports.listLeads = async (req, res) => {
  if (!canManage(req.user, 'leads.manage')) {
    return res.status(403).json({ message: 'Forbidden: lead access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const filter = scopeFilter(scope);
    if (req.query.status) {
      filter.status = req.query.status;
    }
    if (req.query.q) {
      const regex = new RegExp(escapeRegExp(req.query.q), 'i');
      filter.$or = [{ name: regex }, { phone: regex }, { email: regex }, { goal: regex }];
    }

    const leads = await Lead.find(filter)
      .populate('assignedTo', STAFF_SELECT)
      .sort({ nextFollowUpAt: 1, updatedAt: -1 })
      .limit(100)
      .lean();
    const activities = await LeadActivity.find({ leadId: { $in: leads.map((lead) => lead._id) } })
      .populate('createdBy', STAFF_SELECT)
      .sort({ createdAt: -1 })
      .lean();
    const activityMap = activities.reduce((acc, activity) => {
      const key = String(activity.leadId);
      acc[key] = acc[key] || [];
      if (acc[key].length < 3) {
        acc[key].push(activity);
      }
      return acc;
    }, {});

    return res.json({ leads: leads.map((lead) => serializeLead(lead, activityMap[String(lead._id)] || [])) });
  } catch (error) {
    console.error('Workspace lead list failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load leads.' });
  }
};

exports.createLead = async (req, res) => {
  if (!canManage(req.user, 'leads.manage')) {
    return res.status(403).json({ message: 'Forbidden: lead access required.' });
  }

  try {
    const gymId = resolveWriteGymId(req);
    const name = String(req.body.name || '').trim();
    if (!name) {
      throw clientError('Lead name is required.');
    }

    const lead = await Lead.create({
      gymId,
      name,
      email: req.body.email || '',
      phone: req.body.phone || '',
      source: req.body.source || 'manual',
      status: req.body.status || 'new',
      interest: req.body.interest || '',
      goal: req.body.goal || '',
      preferredService: req.body.preferredService || '',
      trialDate: normalizeDate(req.body.trialDate),
      nextFollowUpAt: normalizeDate(req.body.nextFollowUpAt),
      assignedTo: req.body.assignedTo ? asObjectId(req.body.assignedTo, 'assignedTo') : null,
      notes: req.body.notes || '',
      createdBy: req.user._id,
      updatedBy: req.user._id,
    });

    await LeadActivity.create({
      gymId,
      leadId: lead._id,
      type: 'note',
      note: req.body.notes || 'Lead created.',
      nextFollowUpAt: lead.nextFollowUpAt,
      createdBy: req.user._id,
    });
    await logStaffActivity(gymId, req.user._id, 'lead.created', { leadId: lead._id }, null, 'lead', lead._id);

    return res.status(201).json({ lead: serializeLead(lead.toObject()) });
  } catch (error) {
    console.error('Workspace lead create failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to create lead.' });
  }
};

exports.updateLead = async (req, res) => {
  if (!canManage(req.user, 'leads.manage')) {
    return res.status(403).json({ message: 'Forbidden: lead access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const lead = await Lead.findOne({ _id: req.params.leadId, ...scopeFilter(scope) });
    if (!lead) {
      return res.status(404).json({ message: 'Lead not found.' });
    }

    const fields = ['name', 'email', 'phone', 'source', 'status', 'interest', 'goal', 'preferredService', 'lostReason', 'notes'];
    fields.forEach((field) => {
      if (req.body[field] !== undefined) {
        lead[field] = req.body[field];
      }
    });
    if (req.body.trialDate !== undefined) {
      lead.trialDate = normalizeDate(req.body.trialDate);
    }
    if (req.body.nextFollowUpAt !== undefined) {
      lead.nextFollowUpAt = normalizeDate(req.body.nextFollowUpAt);
    }
    if (req.body.assignedTo !== undefined) {
      lead.assignedTo = req.body.assignedTo ? asObjectId(req.body.assignedTo, 'assignedTo') : null;
    }
    if (req.body.convertedMemberId) {
      lead.convertedMemberId = asObjectId(req.body.convertedMemberId, 'convertedMemberId');
      lead.convertedAt = new Date();
      lead.status = 'won';
    }
    lead.updatedBy = req.user._id;
    await lead.save();

    await LeadActivity.create({
      gymId: lead.gymId,
      leadId: lead._id,
      type: req.body.convertedMemberId ? 'conversion' : 'status_change',
      note: req.body.activityNote || `Lead updated to ${lead.status}.`,
      nextFollowUpAt: lead.nextFollowUpAt,
      createdBy: req.user._id,
    });
    await logStaffActivity(lead.gymId, req.user._id, 'lead.updated', { leadId: lead._id, status: lead.status }, null, 'lead', lead._id);

    const populated = await Lead.findById(lead._id).populate('assignedTo', STAFF_SELECT).lean();
    return res.json({ lead: serializeLead(populated) });
  } catch (error) {
    console.error('Workspace lead update failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to update lead.' });
  }
};

exports.addLeadActivity = async (req, res) => {
  if (!canManage(req.user, 'leads.manage')) {
    return res.status(403).json({ message: 'Forbidden: lead access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const lead = await Lead.findOne({ _id: req.params.leadId, ...scopeFilter(scope) });
    if (!lead) {
      return res.status(404).json({ message: 'Lead not found.' });
    }
    const note = String(req.body.note || '').trim();
    if (!note) {
      throw clientError('Activity note is required.');
    }

    const nextFollowUpAt = normalizeDate(req.body.nextFollowUpAt);
    if (req.body.nextFollowUpAt !== undefined) {
      lead.nextFollowUpAt = nextFollowUpAt;
      await lead.save();
    }

    const activity = await LeadActivity.create({
      gymId: lead.gymId,
      leadId: lead._id,
      type: req.body.type || 'note',
      note,
      nextFollowUpAt,
      createdBy: req.user._id,
    });

    await logStaffActivity(lead.gymId, req.user._id, 'lead.activity_created', { leadId: lead._id }, null, 'lead', lead._id);
    const populated = await LeadActivity.findById(activity._id).populate('createdBy', STAFF_SELECT).lean();
    return res.status(201).json({ activity: serializeLead({ ...lead.toObject(), assignedTo: null }, [populated]).activities[0] });
  } catch (error) {
    console.error('Workspace lead activity failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to add lead activity.' });
  }
};

exports.listMembers = async (req, res) => {
  if (!canAccessWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: member access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const filter = { ...scopeFilter(scope), role: 'gym_member' };
    if (req.query.status) {
      filter.accountStatus = req.query.status;
    }
    if (req.query.q) {
      const regex = new RegExp(escapeRegExp(req.query.q), 'i');
      filter.$or = [{ name: regex }, { email: regex }, { phone_number: regex }];
    }

    const members = await User.find(filter).select(MEMBER_SELECT).sort({ updatedAt: -1 }).limit(100).lean();
    const memberIds = members.map((member) => member._id);
    const [memberships, payments, attendance, assignments] = await Promise.all([
      MemberMembership.find({ memberId: { $in: memberIds } })
        .populate('membershipTemplateId', 'name category price')
        .sort({ isActiveBaseMembership: -1, updatedAt: -1 })
        .lean(),
      PaymentEntry.aggregate([
        { $match: { memberId: { $in: memberIds } } },
        { $group: { _id: '$memberId', totalPaid: { $sum: '$amount' }, lastPaymentAt: { $max: '$recordedAt' } } },
      ]),
      AttendanceEvent.aggregate([
        { $match: { memberId: { $in: memberIds }, eventType: 'check_in' } },
        { $group: { _id: '$memberId', visits: { $sum: 1 }, lastCheckInAt: { $max: '$occurredAt' } } },
      ]),
      TrainerAssignment.find({ memberId: { $in: memberIds }, status: 'active' }).populate('trainerId', STAFF_SELECT).lean(),
    ]);

    const membershipMap = memberships.reduce((acc, membership) => {
      const key = String(membership.memberId);
      if (!acc[key]) {
        acc[key] = membership;
      }
      return acc;
    }, {});
    const paymentMap = Object.fromEntries(payments.map((row) => [String(row._id), row]));
    const attendanceMap = Object.fromEntries(attendance.map((row) => [String(row._id), row]));
    const assignmentMap = Object.fromEntries(assignments.map((row) => [String(row.memberId), row]));

    return res.json({
      members: members.map((member) => {
        const key = String(member._id);
        return {
          ...serializeUser(member),
          membership: serializeMembership(membershipMap[key]),
          totalPaid: paymentMap[key]?.totalPaid || 0,
          lastPaymentAt: paymentMap[key]?.lastPaymentAt || null,
          visits: attendanceMap[key]?.visits || 0,
          lastCheckInAt: attendanceMap[key]?.lastCheckInAt || null,
          trainer: serializeUser(assignmentMap[key]?.trainerId),
        };
      }),
    });
  } catch (error) {
    console.error('Workspace member list failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load members.' });
  }
};

exports.getMemberDetail = async (req, res) => {
  if (!canAccessWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: member access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const member = await User.findOne({ _id: req.params.memberId, ...scopeFilter(scope), role: 'gym_member' }).select(MEMBER_SELECT).lean();
    if (!member) {
      return res.status(404).json({ message: 'Member not found.' });
    }

    const [memberships, payments, receipts, attendance, assignment] = await Promise.all([
      MemberMembership.find({ memberId: member._id })
        .populate('membershipTemplateId', 'name category price')
        .sort({ updatedAt: -1 })
        .lean(),
      PaymentEntry.find({ memberId: member._id }).populate('recordedBy', STAFF_SELECT).sort({ recordedAt: -1 }).limit(30).lean(),
      BillingReceipt.find({ memberId: member._id }).sort({ issuedAt: -1 }).limit(30).lean(),
      AttendanceEvent.find({ memberId: member._id }).sort({ occurredAt: -1 }).limit(30).lean(),
      TrainerAssignment.findOne({ memberId: member._id, status: 'active' }).populate('trainerId', STAFF_SELECT).lean(),
    ]);
    const receiptByMembership = Object.fromEntries(receipts.map((receipt) => [String(receipt.membershipId), receipt]));

    return res.json({
      member: {
        ...serializeUser(member),
        profile: member.profile || {},
        fitnessGoals: member.fitnessGoals || [],
        dietPreferences: member.dietPreferences || {},
        customMealPlan: member.customMealPlan || null,
        customWorkoutPlan: member.customWorkoutPlan || null,
        trainer: serializeUser(assignment?.trainerId),
      },
      memberships: memberships.map(serializeMembership),
      payments: payments.map((entry) => serializePayment(entry, receiptByMembership[String(entry.membershipId)] || null)),
      receipts: receipts.map((receipt) => ({
        id: receipt._id,
        receiptNumber: receipt.receiptNumber,
        publicToken: receipt.publicToken,
        planName: receipt.planName,
        amount: receipt.amount,
        issuedAt: receipt.issuedAt,
      })),
      attendance: attendance.map((event) => ({
        id: event._id,
        eventType: event.eventType,
        source: event.source,
        occurredAt: event.occurredAt,
        metadata: event.metadata || {},
      })),
    });
  } catch (error) {
    console.error('Workspace member detail failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load member.' });
  }
};

exports.listPayments = async (req, res) => {
  if (!canManage(req.user, 'billing.manage') && !canManage(req.user, 'payments.manage')) {
    return res.status(403).json({ message: 'Forbidden: billing access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const filter = scopeFilter(scope);
    if (req.query.memberId) {
      filter.memberId = asObjectId(req.query.memberId, 'memberId');
    }
    if (req.query.mode) {
      filter.mode = req.query.mode;
    }

    const payments = await PaymentEntry.find(filter)
      .populate('memberId', MEMBER_SELECT)
      .populate('recordedBy', STAFF_SELECT)
      .sort({ recordedAt: -1 })
      .limit(100)
      .lean();
    const invoices = await Invoice.find({ paymentEntryId: { $in: payments.map((payment) => payment._id) } }).lean();
    const invoiceByPayment = Object.fromEntries(invoices.map((invoice) => [String(invoice.paymentEntryId), invoice]));

    return res.json({ payments: payments.map((entry) => serializePayment(entry, null, invoiceByPayment[String(entry._id)] || null)) });
  } catch (error) {
    console.error('Workspace payments failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load payments.' });
  }
};

exports.recordPayment = async (req, res) => {
  if (!canManage(req.user, 'billing.manage') && !canManage(req.user, 'payments.manage')) {
    return res.status(403).json({ message: 'Forbidden: billing access required.' });
  }

  try {
    const gymId = resolveWriteGymId(req);
    const memberId = asObjectId(req.body.memberId, 'memberId');
    const amount = Number(req.body.amount);
    const mode = String(req.body.mode || '').trim();
    if (!Number.isFinite(amount) || amount < 0) {
      throw clientError('Payment amount must be a valid number.');
    }
    if (!PAYMENT_MODES.has(mode)) {
      throw clientError('Choose a supported payment mode.');
    }

    const member = await User.findOne({ _id: memberId, gymId, role: 'gym_member' });
    if (!member) {
      return res.status(404).json({ message: 'Member not found.' });
    }

    const payment = await PaymentEntry.create({
      gymId,
      memberId,
      membershipId: req.body.membershipId ? asObjectId(req.body.membershipId, 'membershipId') : null,
      membershipRequestId: req.body.membershipRequestId ? asObjectId(req.body.membershipRequestId, 'membershipRequestId') : null,
      amount,
      mode,
      reference: req.body.reference || '',
      note: req.body.note || 'Manual workspace payment.',
      recordedBy: req.user._id,
      recordedAt: normalizeDate(req.body.recordedAt, new Date()),
    });

    let invoice = null;
    if (req.body.issueInvoice) {
      invoice = await Invoice.create({
        gymId,
        memberId,
        paymentEntryId: payment._id,
        invoiceNumber: `GM-INV-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
        status: 'paid',
        subtotal: amount,
        taxAmount: Number(req.body.taxAmount || 0),
        total: amount + Number(req.body.taxAmount || 0),
        gstin: req.body.gstin || '',
        hsnSac: req.body.hsnSac || '',
        createdBy: req.user._id,
      });
    }

    await logStaffActivity(gymId, req.user._id, 'payment.recorded', { paymentEntryId: payment._id, amount, mode }, memberId, 'payment_entry', payment._id);
    const populated = await PaymentEntry.findById(payment._id).populate('memberId', MEMBER_SELECT).populate('recordedBy', STAFF_SELECT).lean();
    return res.status(201).json({ payment: serializePayment(populated, null, invoice) });
  } catch (error) {
    console.error('Workspace payment record failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to record payment.' });
  }
};

exports.listAttendance = async (req, res) => {
  if (!canManage(req.user, 'attendance.manage')) {
    return res.status(403).json({ message: 'Forbidden: attendance access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const filter = scopeFilter(scope);
    const from = normalizeDate(req.query.from, startOfToday());
    const to = normalizeDate(req.query.to, endOfToday());
    filter.occurredAt = { $gte: from, $lte: to };
    if (req.query.memberId) {
      filter.memberId = asObjectId(req.query.memberId, 'memberId');
    }

    const events = await AttendanceEvent.find(filter)
      .populate('memberId', MEMBER_SELECT)
      .sort({ occurredAt: -1 })
      .limit(200)
      .lean();
    const todayMemberIds = new Set(events.filter((event) => event.eventType === 'check_in').map((event) => String(event.memberId?._id || event.memberId)));
    const activeMembers = await User.countDocuments({ ...scopeFilter(scope), role: 'gym_member', accountStatus: { $ne: 'deactivated' } });

    return res.json({
      summary: {
        checkIns: events.filter((event) => event.eventType === 'check_in').length,
        checkOuts: events.filter((event) => event.eventType === 'check_out').length,
        uniqueMembers: todayMemberIds.size,
        activeMembers,
        absentMembers: Math.max(0, activeMembers - todayMemberIds.size),
      },
      events: events.map((event) => ({
        id: event._id,
        member: serializeUser(event.memberId),
        eventType: event.eventType,
        source: event.source,
        occurredAt: event.occurredAt,
        metadata: event.metadata || {},
      })),
    });
  } catch (error) {
    console.error('Workspace attendance failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load attendance.' });
  }
};

exports.recordAttendance = async (req, res) => {
  if (!canManage(req.user, 'attendance.manage')) {
    return res.status(403).json({ message: 'Forbidden: attendance access required.' });
  }

  try {
    const gymId = resolveWriteGymId(req);
    const memberId = asObjectId(req.body.memberId, 'memberId');
    const eventType = req.body.eventType === 'check_out' ? 'check_out' : 'check_in';
    const occurredAt = normalizeDate(req.body.occurredAt, new Date());
    const duplicateWindowStart = new Date(occurredAt.getTime() - 5 * 60 * 1000);
    const duplicate = await AttendanceEvent.findOne({
      gymId,
      memberId,
      eventType,
      occurredAt: { $gte: duplicateWindowStart, $lte: occurredAt },
    }).lean();

    if (duplicate) {
      return res.status(200).json({
        duplicate: true,
        event: {
          id: duplicate._id,
          memberId: duplicate.memberId,
          eventType: duplicate.eventType,
          source: duplicate.source,
          occurredAt: duplicate.occurredAt,
          metadata: duplicate.metadata || {},
        },
      });
    }

    const member = await User.findOne({ _id: memberId, gymId, role: 'gym_member' });
    if (!member) {
      return res.status(404).json({ message: 'Member not found.' });
    }

    const event = await AttendanceEvent.create({
      gymId,
      memberId,
      source: 'manual',
      eventType,
      occurredAt,
      metadata: {
        note: req.body.note || '',
        recordedBy: req.user._id,
      },
    });
    await logStaffActivity(gymId, req.user._id, `attendance.${eventType}`, { attendanceEventId: event._id }, memberId, 'attendance_event', event._id);

    return res.status(201).json({
      duplicate: false,
      event: {
        id: event._id,
        member: serializeUser(member),
        eventType: event.eventType,
        source: event.source,
        occurredAt: event.occurredAt,
        metadata: event.metadata || {},
      },
    });
  } catch (error) {
    console.error('Workspace attendance record failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to record attendance.' });
  }
};

exports.listClasses = async (req, res) => {
  if (!canManage(req.user, 'classes.manage')) {
    return res.status(403).json({ message: 'Forbidden: class access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const base = scopeFilter(scope);
    const from = normalizeDate(req.query.from, startOfToday());
    const to = normalizeDate(req.query.to, (() => {
      const date = new Date();
      date.setDate(date.getDate() + 14);
      return date;
    })());

    const [templates, sessions] = await Promise.all([
      ClassTemplate.find(base).populate('trainerId', STAFF_SELECT).sort({ active: -1, name: 1 }).lean(),
      ClassSession.find({ ...base, startsAt: { $gte: from, $lte: to } })
        .populate('templateId')
        .populate('trainerId', STAFF_SELECT)
        .sort({ startsAt: 1 })
        .lean(),
    ]);
    const bookings = await ClassBooking.find({ sessionId: { $in: sessions.map((session) => session._id) } })
      .populate('memberId', MEMBER_SELECT)
      .populate('bookedBy', STAFF_SELECT)
      .sort({ createdAt: -1 })
      .lean();
    const bookingMap = bookings.reduce((acc, booking) => {
      const key = String(booking.sessionId);
      acc[key] = acc[key] || [];
      acc[key].push(booking);
      return acc;
    }, {});

    return res.json({
      templates: templates.map(serializeClassTemplate),
      sessions: sessions.map((session) => serializeClassSession(session, bookingMap[String(session._id)] || [])),
    });
  } catch (error) {
    console.error('Workspace classes failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load classes.' });
  }
};

exports.createClassTemplate = async (req, res) => {
  if (!canManage(req.user, 'classes.manage')) {
    return res.status(403).json({ message: 'Forbidden: class access required.' });
  }

  try {
    const gymId = resolveWriteGymId(req);
    const name = String(req.body.name || '').trim();
    if (!name) {
      throw clientError('Class name is required.');
    }
    const template = await ClassTemplate.create({
      gymId,
      name,
      type: req.body.type || 'group_class',
      description: req.body.description || '',
      trainerId: req.body.trainerId ? asObjectId(req.body.trainerId, 'trainerId') : null,
      defaultCapacity: Number(req.body.defaultCapacity || 10),
      durationMinutes: Number(req.body.durationMinutes || 60),
      requiresMembership: req.body.requiresMembership !== false,
      deductsEntitlement: Boolean(req.body.deductsEntitlement),
      active: req.body.active !== false,
      createdBy: req.user._id,
      updatedBy: req.user._id,
    });
    await logStaffActivity(gymId, req.user._id, 'class_template.created', { classTemplateId: template._id }, null, 'class_template', template._id);
    return res.status(201).json({ template: serializeClassTemplate(template.toObject()) });
  } catch (error) {
    console.error('Workspace class template create failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to create class template.' });
  }
};

exports.createClassSession = async (req, res) => {
  if (!canManage(req.user, 'classes.manage')) {
    return res.status(403).json({ message: 'Forbidden: class access required.' });
  }

  try {
    const gymId = resolveWriteGymId(req);
    const template = await ClassTemplate.findOne({ _id: req.body.templateId, gymId });
    if (!template) {
      return res.status(404).json({ message: 'Class template not found.' });
    }
    const startsAt = normalizeDate(req.body.startsAt);
    if (!startsAt) {
      throw clientError('Session start time is required.');
    }
    const endsAt = normalizeDate(req.body.endsAt, new Date(startsAt.getTime() + Number(template.durationMinutes || 60) * 60 * 1000));
    const session = await ClassSession.create({
      gymId,
      templateId: template._id,
      trainerId: req.body.trainerId ? asObjectId(req.body.trainerId, 'trainerId') : template.trainerId,
      startsAt,
      endsAt,
      capacity: Number(req.body.capacity || template.defaultCapacity || 10),
      status: req.body.status || 'open',
      location: req.body.location || '',
      notes: req.body.notes || '',
      createdBy: req.user._id,
      updatedBy: req.user._id,
    });
    await logStaffActivity(gymId, req.user._id, 'class_session.created', { classSessionId: session._id }, null, 'class_session', session._id);
    const populated = await ClassSession.findById(session._id).populate('templateId').populate('trainerId', STAFF_SELECT).lean();
    return res.status(201).json({ session: serializeClassSession(populated, []) });
  } catch (error) {
    console.error('Workspace class session create failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to create class session.' });
  }
};

exports.createClassBooking = async (req, res) => {
  if (!canManage(req.user, 'classes.manage') && !canManage(req.user, 'bookings.manage')) {
    return res.status(403).json({ message: 'Forbidden: booking access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const session = await ClassSession.findOne({ _id: req.params.sessionId, ...scopeFilter(scope) });
    if (!session) {
      return res.status(404).json({ message: 'Class session not found.' });
    }
    const memberId = asObjectId(req.body.memberId, 'memberId');
    const activeBookingCount = await ClassBooking.countDocuments({
      sessionId: session._id,
      status: { $in: ['booked', 'attended'] },
    });
    if (activeBookingCount >= session.capacity) {
      throw clientError('Class session is already full.');
    }

    const member = await User.findOne({ _id: memberId, gymId: session.gymId, role: 'gym_member' });
    if (!member) {
      return res.status(404).json({ message: 'Member not found.' });
    }

    const booking = await ClassBooking.create({
      gymId: session.gymId,
      sessionId: session._id,
      memberId,
      status: 'booked',
      bookedBy: req.user._id,
      notes: req.body.notes || '',
    });
    await logStaffActivity(session.gymId, req.user._id, 'class_booking.created', { classBookingId: booking._id }, memberId, 'class_booking', booking._id);
    const populated = await ClassBooking.findById(booking._id).populate('memberId', MEMBER_SELECT).populate('bookedBy', STAFF_SELECT).lean();
    return res.status(201).json({
      booking: serializeClassSession(session.toObject(), [populated]).bookings[0],
    });
  } catch (error) {
    console.error('Workspace class booking create failed:', error);
    return res.status(error.code === 11000 ? 409 : error.statusCode || 500).json({
      message: error.code === 11000 ? 'Member is already booked for this session.' : error.message || 'Failed to create booking.',
    });
  }
};

exports.updateClassBooking = async (req, res) => {
  if (!canManage(req.user, 'classes.manage') && !canManage(req.user, 'bookings.manage')) {
    return res.status(403).json({ message: 'Forbidden: booking access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const booking = await ClassBooking.findOne({ _id: req.params.bookingId, ...scopeFilter(scope) });
    if (!booking) {
      return res.status(404).json({ message: 'Booking not found.' });
    }
    const status = String(req.body.status || booking.status);
    if (!['booked', 'cancelled', 'attended', 'no_show'].includes(status)) {
      throw clientError('Choose a valid booking status.');
    }
    booking.status = status;
    booking.notes = req.body.notes !== undefined ? req.body.notes : booking.notes;
    booking.cancelledAt = status === 'cancelled' ? new Date() : booking.cancelledAt;
    booking.attendedAt = status === 'attended' ? new Date() : booking.attendedAt;
    await booking.save();
    await logStaffActivity(booking.gymId, req.user._id, 'class_booking.updated', { classBookingId: booking._id, status }, booking.memberId, 'class_booking', booking._id);

    const populated = await ClassBooking.findById(booking._id).populate('memberId', MEMBER_SELECT).populate('bookedBy', STAFF_SELECT).lean();
    return res.json({ booking: serializeClassSession({ _id: booking.sessionId, capacity: 1, status: 'open' }, [populated]).bookings[0] });
  } catch (error) {
    console.error('Workspace class booking update failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to update booking.' });
  }
};

exports.listStaff = async (req, res) => {
  if (!canManage(req.user, 'staff.manage') && !canAccessWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: staff access required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const filter = { ...scopeFilter(scope), role: { $in: ['gym_owner', 'gym_staff', 'gym_trainer'] } };
    const [staff, activities] = await Promise.all([
      User.find(filter).select(STAFF_SELECT).sort({ role: 1, name: 1 }).lean(),
      StaffActivityLog.find(scopeFilter(scope)).populate('actorId', STAFF_SELECT).populate('targetUserId', STAFF_SELECT).sort({ createdAt: -1 }).limit(25).lean(),
    ]);
    const workload = await TrainerAssignment.aggregate([
      { $match: { ...scopeFilter(scope), status: 'active' } },
      { $group: { _id: '$trainerId', clientCount: { $sum: 1 } } },
    ]);
    const workloadMap = Object.fromEntries(workload.map((row) => [String(row._id), row.clientCount]));

    return res.json({
      staff: staff.map((user) => ({
        ...serializeUser(user),
        staffCapabilities: user.staffCapabilities || {},
        permissions: getPermissions(user),
        clientCount: workloadMap[String(user._id)] || 0,
      })),
      presets: {
        manager: ['workspace.access', 'members.view', 'members.manage', 'leads.manage', 'billing.manage', 'attendance.manage', 'classes.manage', 'reports.view'],
        front_desk: ['workspace.access', 'members.view', 'leads.manage', 'billing.manage', 'attendance.manage', 'classes.manage'],
        trainer: ['workspace.access', 'members.view', 'classes.manage'],
        billing: ['workspace.access', 'members.view', 'billing.manage', 'payments.manage', 'receipts.view', 'reports.view'],
        marketing: ['workspace.access', 'leads.manage', 'campaigns.manage', 'announcements.manage', 'reports.view'],
      },
      activities: activities.map((activity) => ({
        id: activity._id,
        action: activity.action,
        entityType: activity.entityType,
        actor: serializeUser(activity.actorId),
        targetUser: serializeUser(activity.targetUserId),
        payload: activity.payload || {},
        createdAt: activity.createdAt,
      })),
    });
  } catch (error) {
    console.error('Workspace staff failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to load staff.' });
  }
};

exports.updateStaffCapabilities = async (req, res) => {
  if (!canManage(req.user, 'staff.manage')) {
    return res.status(403).json({ message: 'Forbidden: staff management required.' });
  }

  try {
    const scope = resolveReadScope(req);
    const user = await User.findOne({ _id: req.params.userId, ...scopeFilter(scope), role: { $in: ['gym_staff', 'gym_trainer'] } });
    if (!user) {
      return res.status(404).json({ message: 'Staff member not found.' });
    }
    user.staffCapabilities = {
      ...(user.staffCapabilities || {}),
      ...(req.body.staffCapabilities || {}),
    };
    await user.save({ validateBeforeSave: false });
    await logStaffActivity(user.gymId, req.user._id, 'staff.capabilities_updated', { staffCapabilities: user.staffCapabilities }, user._id, 'user', user._id);

    return res.json({
      staff: {
        ...serializeUser(user),
        staffCapabilities: user.staffCapabilities || {},
        permissions: getPermissions(user),
      },
    });
  } catch (error) {
    console.error('Workspace staff update failed:', error);
    return res.status(error.statusCode || 500).json({ message: error.message || 'Failed to update staff permissions.' });
  }
};
