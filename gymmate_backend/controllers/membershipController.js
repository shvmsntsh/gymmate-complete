const MembershipService = require('../services/membershipService');
const { hasRole, hasPermission } = require('../utils/roles');

function canManageTemplates(user) {
  return hasPermission(user, 'membership.plans.manage') || hasRole(user, ['owner']);
}

function canManageRequests(user) {
  return hasPermission(user, 'membership.requests.manage') || hasRole(user, ['owner']);
}

function canManagePayments(user) {
  return hasPermission(user, 'payments.manage') || hasRole(user, ['owner']);
}

function canManageMembers(user) {
  return hasPermission(user, 'members.manage') || hasRole(user, ['owner']);
}

function canViewMembershipWorkspace(user) {
  return hasPermission(user, 'workspace.access') || canManageMembers(user);
}

function canOwnerOverride(user) {
  return hasRole(user, ['owner']);
}

function membershipClientErrorStatus(error) {
  const message = String(error?.message || '').toLowerCase();
  if (
    message.includes('template not found') ||
    message.includes('member already has a current plan') ||
    message.includes('invalid') ||
    message.includes('required') ||
    message.includes('not found')
  ) {
    return 400;
  }
  return 500;
}

function isActionableRequestStatus(status) {
  return ['submitted', 'awaiting_payment', 'payment_under_review'].includes(status);
}

function serializeTemplate(template, activeMemberCount = 0) {
  if (!template) return null;
  return {
    id: template._id,
    name: template.name,
    shortDescription: template.shortDescription || '',
    fullDescription: template.fullDescription || '',
    durationDays: template.durationDays,
    price: template.price || 0,
    joiningFee: template.joiningFee || 0,
    renewalLeadDays: template.renewalLeadDays || 7,
    active: template.active,
    visibleToMembers: template.visibleToMembers,
    sortOrder: template.sortOrder || 0,
    upgradeRank: template.upgradeRank || 0,
    category: template.category || 'monthly',
    includedFeatures: template.includedFeatures || {},
    availableAddOns: template.availableAddOns || {},
    rules: template.rules || {},
    activeMemberCount,
    createdAt: template.createdAt,
    updatedAt: template.updatedAt,
  };
}

function serializeMembership(membership) {
  if (!membership) return null;
  
  const template = membership.membershipTemplateId;
  const computedStatus = MembershipService.computeStatus(membership, template);
  const isScheduledFuture =
    computedStatus === 'pending_approval' &&
    membership.startDate &&
    new Date(membership.startDate) > new Date();
  
  return {
    id: membership._id,
    membershipTemplateId: membership.membershipTemplateId,
    templateName: template?.name || 'Unknown Plan',
    status: membership.status,
    computedStatus,
    renewalState: isScheduledFuture ? 'scheduled' : computedStatus,
    startDate: membership.startDate,
    endDate: membership.endDate,
    nextRenewalDate: membership.nextRenewalDate,
    activatedAt: membership.activatedAt,
    paymentStatus: membership.paymentStatus,
    paymentMethod: membership.paymentMethod,
    paymentReference: membership.paymentReference || '',
    notes: membership.notes || '',
    entitlementsSnapshot: membership.entitlementsSnapshot || {},
    isFrozen: membership.isFrozen || false,
    frozenUntil: membership.frozenUntil,
    isActiveBaseMembership: membership.isActiveBaseMembership,
    createdAt: membership.createdAt,
    updatedAt: membership.updatedAt,
  };
}

function serializeRequest(request) {
  if (!request) return null;
  
  return {
    id: request._id,
    requestType: request.requestType,
    status: request.status,
    currentMembershipId: request.currentMembershipId,
    targetMembershipTemplateId: request.targetMembershipTemplateId,
    targetPlan: request.targetMembershipTemplateId ? {
      id: request.targetMembershipTemplateId._id,
      name: request.targetMembershipTemplateId.name,
      shortDescription: request.targetMembershipTemplateId.shortDescription,
      fullDescription: request.targetMembershipTemplateId.fullDescription,
      durationDays: request.targetMembershipTemplateId.durationDays,
      price: request.targetMembershipTemplateId.price,
      joiningFee: request.targetMembershipTemplateId.joiningFee,
      category: request.targetMembershipTemplateId.category,
      includedFeatures: request.targetMembershipTemplateId.includedFeatures,
      availableAddOns: request.targetMembershipTemplateId.availableAddOns,
    } : null,
    requestedAddOns: request.requestedAddOns || {},
    paymentMode: request.paymentMode,
    paymentProofUrl: request.paymentProofUrl || '',
    memberNote: request.memberNote || '',
    adminNote: request.adminNote || '',
    requestedAt: request.requestedAt,
    verifiedAt: request.verifiedAt,
    verifiedBy: request.verifiedBy,
    decidedAt: request.decidedAt,
    decidedBy: request.decidedBy,
    effectiveDate: request.effectiveDate,
    createdAt: request.createdAt,
    updatedAt: request.updatedAt,
    member: request.memberId ? {
      id: request.memberId._id,
      name: request.memberId.name,
      email: request.memberId.email,
      phone: request.memberId.phone,
    } : null,
  };
}

function serializePaymentEntry(entry) {
  if (!entry) return null;

  return {
    id: entry._id,
    memberId: entry.memberId,
    membershipId: entry.membershipId,
    membershipRequestId: entry.membershipRequestId,
    amount: entry.amount || 0,
    mode: entry.mode || '',
    reference: entry.reference || '',
    note: entry.note || '',
    recordedAt: entry.recordedAt || entry.createdAt,
    createdAt: entry.createdAt,
    recordedBy: entry.recordedBy
      ? {
          id: entry.recordedBy._id,
          name: entry.recordedBy.name,
          email: entry.recordedBy.email,
        }
      : null,
  };
}

function serializeAuditLog(log) {
  if (!log) return null;
  return {
    id: log._id,
    entityType: log.entityType,
    entityId: log.entityId,
    action: log.action,
    performedBy: log.performedBy ? {
      id: log.performedBy._id,
      name: log.performedBy.name,
    } : null,
    payload: log.payload || {},
    createdAt: log.createdAt,
  };
}

function serializeDecisionPreview(preview) {
  if (!preview) return null;
  return {
    action: preview.action,
    computedDates: preview.computedDates || {},
    paymentSummary: preview.paymentSummary || {},
    warnings: preview.warnings || [],
    blockers: preview.blockers || [],
    overrideRequired: Boolean(preview.overrideRequired),
    overrideAllowed: Boolean(preview.overrideAllowed),
    auditPreview: preview.auditPreview || {},
  };
}

exports.getTemplates = async (req, res) => {
  if (!canManageTemplates(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership plan access required' });
  }

  try {
    const templates = await MembershipService.getTemplates(req.user.gymId);
    
    return res.status(200).json({
      templates: templates.map(t => serializeTemplate(t)),
    });
  } catch (error) {
    console.error('Error fetching templates:', error);
    return res.status(500).json({ message: 'Error fetching templates' });
  }
};

exports.createTemplate = async (req, res) => {
  if (!canManageTemplates(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership plan access required' });
  }

  try {
    const templateData = req.body;
    
    const template = await MembershipService.createTemplate(
      req.user.gymId,
      req.user._id,
      templateData
    );

    return res.status(201).json({
      message: 'Template created successfully.',
      template: serializeTemplate(template),
    });
  } catch (error) {
    console.error('Error creating template:', error);
    return res.status(500).json({ message: error.message || 'Error creating template' });
  }
};

exports.updateTemplate = async (req, res) => {
  if (!canManageTemplates(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership plan access required' });
  }

  try {
    const { templateId } = req.params;
    const updateData = { ...req.body, updatedBy: req.user._id };
    
    const template = await MembershipService.updateTemplate(
      req.user.gymId,
      templateId,
      updateData
    );

    return res.status(200).json({
      message: 'Template updated successfully.',
      template: serializeTemplate(template),
    });
  } catch (error) {
    console.error('Error updating template:', error);
    return res.status(500).json({ message: error.message || 'Error updating template' });
  }
};

exports.deleteTemplate = async (req, res) => {
  if (!canManageTemplates(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership plan access required' });
  }

  try {
    const { templateId } = req.params;
    
    await MembershipService.deleteTemplate(req.user.gymId, templateId, req.user._id);

    return res.status(200).json({
      message: 'Template archived successfully.',
    });
  } catch (error) {
    console.error('Error deleting template:', error);
    return res.status(500).json({ message: error.message || 'Error deleting template' });
  }
};

exports.getRequests = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const { status, requestType, limit } = req.query;
    
    const requests = await MembershipService.getChangeRequests(req.user.gymId, {
      status,
      requestType,
      limit: parseInt(limit) || 100,
    });

    return res.status(200).json({
      requests: requests.map(r => serializeRequest(r)),
    });
  } catch (error) {
    console.error('Error fetching requests:', error);
    return res.status(500).json({ message: 'Error fetching requests' });
  }
};

exports.getRequestById = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const { requestId } = req.params;
    
    const request = await MembershipService.getChangeRequestById(req.user.gymId, requestId);
    
    if (!request) {
      return res.status(404).json({ message: 'Request not found' });
    }

    const memberMembership = request.memberId
      ? await MembershipService.getActiveMembership(req.user.gymId, request.memberId._id)
      : null;
    const requestPayments = await MembershipService.getPaymentEntriesForRequest(
      req.user.gymId,
      request._id,
    );
    const memberPayments =
      request.memberId && memberMembership
        ? await MembershipService.getPaymentEntriesForMember(req.user.gymId, request.memberId._id)
        : [];
    const membershipPayments = memberMembership
      ? memberPayments.filter((entry) => {
          if (!entry.membershipId) return false;
          return entry.membershipId.toString() === memberMembership._id.toString();
        })
      : [];
    const decisionPreview = isActionableRequestStatus(request.status)
      ? await MembershipService.computeDecisionPreview({
          gymId: req.user.gymId,
          request,
          currentMembership: memberMembership,
        })
      : null;

    return res.status(200).json({
      request: serializeRequest(request),
      memberMembership: memberMembership ? serializeMembership(memberMembership) : null,
      requestPayments: requestPayments.map((entry) => serializePaymentEntry(entry)),
      membershipPayments: membershipPayments.map((entry) => serializePaymentEntry(entry)),
      decisionPreview: serializeDecisionPreview(decisionPreview),
    });
  } catch (error) {
    console.error('Error fetching request:', error);
    return res.status(500).json({ message: 'Error fetching request' });
  }
};

exports.getRequestDecisionPreview = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const { requestId } = req.params;
    const request = await MembershipService.getChangeRequestById(req.user.gymId, requestId);

    if (!request) {
      return res.status(404).json({ message: 'Request not found' });
    }

    if (!isActionableRequestStatus(request.status)) {
      return res.status(409).json({ message: 'Decision preview is only available for actionable requests.' });
    }

    const memberMembership = request.memberId
      ? await MembershipService.getActiveMembership(req.user.gymId, request.memberId._id)
      : null;
    const preview = await MembershipService.computeDecisionPreview({
      gymId: req.user.gymId,
      request,
      currentMembership: memberMembership,
      requestedEffectiveDate: req.query.effectiveDate || null,
      override: {
        overrideMode: req.query.overrideMode || null,
        manualStartDate: req.query.manualStartDate || null,
        manualEndDate: req.query.manualEndDate || null,
        manualNextRenewalDate: req.query.manualNextRenewalDate || null,
      },
    });

    return res.status(200).json({
      request: serializeRequest(request),
      preview: serializeDecisionPreview(preview),
    });
  } catch (error) {
    console.error('Error fetching decision preview:', error);
    return res.status(500).json({ message: error.message || 'Error fetching decision preview' });
  }
};

exports.verifyPayment = async (req, res) => {
  if (!canManagePayments(req.user)) {
    return res.status(403).json({ message: 'Forbidden: payment access required' });
  }

  try {
    const { requestId } = req.params;
    const { paymentMethod, paymentReference } = req.body;
    
    const request = await MembershipService.verifyPayment(
      requestId,
      req.user.gymId,
      req.user._id,
      { paymentMethod, paymentReference }
    );

    return res.status(200).json({
      message: 'Payment verified successfully.',
      request: serializeRequest(request),
    });
  } catch (error) {
    console.error('Error verifying payment:', error);
    return res.status(500).json({ message: error.message || 'Error verifying payment' });
  }
};

exports.approveRequest = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const { requestId } = req.params;
    const {
      adminNote,
      effectiveDate,
      freezeDays,
      overrideMode,
      overrideReason,
      manualStartDate,
      manualEndDate,
      manualNextRenewalDate,
      acknowledgedWarnings,
    } = req.body;

    if ((overrideMode || manualStartDate || manualEndDate) && !canOwnerOverride(req.user)) {
      return res.status(403).json({ message: 'Owner override required' });
    }

    if ((overrideMode || manualStartDate || manualEndDate) && !overrideReason) {
      return res.status(400).json({ message: 'overrideReason is required for manual override' });
    }
    
    const result = await MembershipService.approveRequest(
      requestId,
      req.user.gymId,
      req.user._id,
      {
        adminNote,
        effectiveDate,
        freezeDays,
        overrideMode,
        overrideReason,
        manualStartDate,
        manualEndDate,
        manualNextRenewalDate,
        acknowledgedWarnings,
      }
    );

    return res.status(200).json({
      message: 'Request approved successfully.',
      request: serializeRequest(result.request),
      membership: result.membership ? serializeMembership(result.membership) : null,
    });
  } catch (error) {
    console.error('Error approving request:', error);
    return res.status(500).json({ message: error.message || 'Error approving request' });
  }
};

exports.rejectRequest = async (req, res) => {
  if (!canManageRequests(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership request access required' });
  }

  try {
    const { requestId } = req.params;
    const { reason } = req.body;
    
    if (!reason) {
      return res.status(400).json({ message: 'Rejection reason is required' });
    }
    
    const request = await MembershipService.rejectRequest(
      requestId,
      req.user.gymId,
      req.user._id,
      reason
    );

    return res.status(200).json({
      message: 'Request rejected.',
      request: serializeRequest(request),
    });
  } catch (error) {
    console.error('Error rejecting request:', error);
    return res.status(500).json({ message: error.message || 'Error rejecting request' });
  }
};

exports.getMemberMemberships = async (req, res) => {
  if (!canViewMembershipWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership workspace access required' });
  }

  try {
    const { memberId } = req.params;

    const [memberships, paymentEntries] = await Promise.all([
      MembershipService.getMemberMemberships(req.user.gymId, memberId),
      MembershipService.getPaymentEntriesForMember(req.user.gymId, memberId),
    ]);

    const paymentEntriesByMembershipId = paymentEntries.reduce((acc, entry) => {
      if (!entry.membershipId) return acc;
      const key = entry.membershipId.toString();
      if (!acc[key]) acc[key] = [];
      acc[key].push(serializePaymentEntry(entry));
      return acc;
    }, {});

    return res.status(200).json({
      memberships: memberships.map((membership) => ({
        ...serializeMembership(membership),
        paymentHistory: paymentEntriesByMembershipId[membership._id.toString()] || [],
      })),
    });
  } catch (error) {
    console.error('Error fetching member memberships:', error);
    return res.status(500).json({ message: 'Error fetching memberships' });
  }
};

exports.getAllMemberMemberships = async (req, res) => {
  if (!canViewMembershipWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership workspace access required' });
  }

  try {
    const MemberMembership = require('../models/MemberMembership');
    
    const memberships = await MemberMembership.find({ gymId: req.user.gymId })
      .populate('memberId', 'name email')
      .populate('membershipTemplateId', 'name category')
      .lean();

    return res.status(200).json({
      memberships: memberships.map(m => ({
        ...serializeMembership(m),
        member: m.memberId ? {
          id: m.memberId._id,
          name: m.memberId.name,
          email: m.memberId.email,
        } : null,
        template: m.membershipTemplateId ? {
          id: m.membershipTemplateId._id,
          name: m.membershipTemplateId.name,
          category: m.membershipTemplateId.category,
        } : null,
      })),
    });
  } catch (error) {
    console.error('Error fetching all memberships:', error);
    return res.status(500).json({ message: 'Error fetching memberships' });
  }
};

exports.assignMembership = async (req, res) => {
  if (!canManageMembers(req.user)) {
    return res.status(403).json({ message: 'Forbidden: member membership access required' });
  }

  try {
    const { memberId } = req.params;
    const {
      templateId,
      paymentStatus,
      paymentMethod,
      paymentReference,
      paymentAmount,
      notes,
      startDate,
      addOns,
      overrideMode,
      overrideReason,
      manualStartDate,
      manualEndDate,
      manualNextRenewalDate,
      acknowledgedWarnings,
      flowType,
    } = req.body;
    
    const membership = await MembershipService.assignMembership(
      req.user.gymId,
      memberId,
      templateId,
      req.user._id,
      {
        paymentStatus,
        paymentMethod,
        paymentReference,
        paymentAmount,
        notes,
        startDate,
        addOns,
        overrideMode,
        overrideReason,
        manualStartDate,
        manualEndDate,
        manualNextRenewalDate,
        acknowledgedWarnings,
        flowType,
      }
    );

    return res.status(201).json({
      message: 'Membership assigned successfully.',
      membership: serializeMembership(membership),
    });
  } catch (error) {
    console.error('Error assigning membership:', error);
    return res
      .status(membershipClientErrorStatus(error))
      .json({ message: error.message || 'Error assigning membership' });
  }
};

exports.adjustMembership = async (req, res) => {
  if (!canManageMembers(req.user)) {
    return res.status(403).json({ message: 'Member membership access required for manual membership adjustments' });
  }

  try {
    const { membershipId } = req.params;
    const {
      changeType,
      reason,
      extensionDays,
      startDate,
      endDate,
      nextRenewalDate,
      acknowledgedWarnings,
    } = req.body || {};

    if (!reason) {
      return res.status(400).json({ message: 'reason is required' });
    }

    const membership = await MembershipService.adjustMembershipDates(
      req.user.gymId,
      membershipId,
      req.user._id,
      {
        changeType,
        reason,
        extensionDays,
        startDate,
        endDate,
        nextRenewalDate,
        acknowledgedWarnings,
      },
    );

    return res.status(200).json({
      message: 'Membership adjusted successfully.',
      membership: serializeMembership(membership),
    });
  } catch (error) {
    console.error('Error adjusting membership:', error);
    return res
      .status(membershipClientErrorStatus(error))
      .json({ message: error.message || 'Error adjusting membership' });
  }
};

exports.unfreezeMembership = async (req, res) => {
  if (!canManageMembers(req.user)) {
    return res.status(403).json({ message: 'Forbidden: member membership access required' });
  }

  try {
    const { membershipId } = req.params;
    
    const membership = await MembershipService.unfreezeMembership(
      req.user.gymId,
      membershipId,
      req.user._id
    );

    return res.status(200).json({
      message: 'Membership unfrozen.',
      membership: serializeMembership(membership),
    });
  } catch (error) {
    console.error('Error unfreezing membership:', error);
    return res.status(500).json({ message: error.message || 'Error unfreezing membership' });
  }
};

exports.cancelMembership = async (req, res) => {
  if (!canManageMembers(req.user)) {
    return res.status(403).json({ message: 'Forbidden: member membership access required' });
  }

  try {
    const { membershipId } = req.params;
    const { reason } = req.body;
    
    const membership = await MembershipService.cancelMembership(
      req.user.gymId,
      membershipId,
      req.user._id,
      reason
    );

    return res.status(200).json({
      message: 'Membership canceled.',
      membership: serializeMembership(membership),
    });
  } catch (error) {
    console.error('Error canceling membership:', error);
    return res.status(500).json({ message: error.message || 'Error canceling membership' });
  }
};

exports.getAuditLogs = async (req, res) => {
  if (!canViewMembershipWorkspace(req.user)) {
    return res.status(403).json({ message: 'Forbidden: membership workspace access required' });
  }

  try {
    const { memberId, limit } = req.query;
    
    const logs = await MembershipService.getAuditLogs(req.user.gymId, memberId, {
      limit: parseInt(limit) || 100,
    });

    return res.status(200).json({
      logs: logs.map(l => serializeAuditLog(l)),
    });
  } catch (error) {
    console.error('Error fetching audit logs:', error);
    return res.status(500).json({ message: 'Error fetching audit logs' });
  }
};
