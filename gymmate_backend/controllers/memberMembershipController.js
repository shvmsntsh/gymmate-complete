const MembershipService = require('../services/membershipService');
const { hasRole } = require('../utils/roles');
const receiptController = require('./receiptController');

function serializeMembershipWithEntitlements(membership) {
  if (!membership) return null;
  
  const template = membership.membershipTemplateId;
  
  return {
    id: membership._id,
    membershipTemplateId: membership.membershipTemplateId,
    templateName: template?.name || 'Unknown Plan',
    status: membership.status,
    computedStatus: MembershipService.computeStatus(membership, template),
    startDate: membership.startDate,
    endDate: membership.endDate,
    nextRenewalDate: membership.nextRenewalDate,
    activatedAt: membership.activatedAt,
    paymentStatus: membership.paymentStatus,
    paymentMethod: membership.paymentMethod,
    paymentReference: membership.paymentReference || '',
    notes: membership.notes || '',
    entitlements: membership.entitlementsSnapshot || {},
    isFrozen: membership.isFrozen || false,
    frozenUntil: membership.frozenUntil,
    createdAt: membership.createdAt,
    updatedAt: membership.updatedAt,
  };
}

function serializePlan(plan) {
  return {
    id: plan._id,
    name: plan.name,
    shortDescription: plan.shortDescription || '',
    fullDescription: plan.fullDescription || '',
    durationDays: plan.durationDays,
    price: plan.price || 0,
    joiningFee: plan.joiningFee || 0,
    category: plan.category || 'monthly',
    includedFeatures: plan.includedFeatures || {},
    availableAddOns: plan.availableAddOns || {},
    rules: plan.rules || {},
    upgradeRank: plan.upgradeRank || 0,
    isCurrent: plan.isCurrent || false,
    canUpgrade: plan.canUpgrade || false,
    canDowngrade: plan.canDowngrade || false,
    canRenew: plan.canRenew !== false,
  };
}

function serializeRequest(request) {
  if (!request) return null;
  
  return {
    id: request._id,
    requestType: request.requestType,
    status: request.status,
    targetPlan: request.targetMembershipTemplateId ? {
      id: request.targetMembershipTemplateId._id,
      name: request.targetMembershipTemplateId.name,
      shortDescription: request.targetMembershipTemplateId.shortDescription,
      durationDays: request.targetMembershipTemplateId.durationDays,
      price: request.targetMembershipTemplateId.price,
    } : null,
    requestedAddOns: request.requestedAddOns || {},
    paymentMode: request.paymentMode,
    memberNote: request.memberNote || '',
    adminNote: request.adminNote || '',
    requestedAt: request.requestedAt,
    decidedAt: request.decidedAt,
    createdAt: request.createdAt,
    updatedAt: request.updatedAt,
  };
}

exports.getMyMembership = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const membership = await MembershipService.getActiveMembership(req.user.gymId, req.user._id);
    
    return res.status(200).json({
      membership: membership ? serializeMembershipWithEntitlements(membership) : null,
    });
  } catch (error) {
    console.error('Error fetching membership:', error);
    return res.status(500).json({ message: 'Error fetching membership' });
  }
};

exports.getMyMembershipOptions = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const result = await MembershipService.getAvailablePlans(req.user.gymId, req.user._id);
    
    return res.status(200).json({
      currentMembership: result.currentMembership ? serializeMembershipWithEntitlements(result.currentMembership) : null,
      plans: result.plans.map(p => serializePlan(p)),
    });
  } catch (error) {
    console.error('Error fetching membership options:', error);
    return res.status(500).json({ message: 'Error fetching membership options' });
  }
};

exports.getMyMembershipRequests = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const { status, limit } = req.query;
    
    const requests = await MembershipService.getMemberChangeRequests(req.user._id, {
      status,
      limit: parseInt(limit) || 50,
    });
    
    return res.status(200).json({
      requests: requests.map(r => serializeRequest(r)),
    });
  } catch (error) {
    console.error('Error fetching membership requests:', error);
    return res.status(500).json({ message: 'Error fetching membership requests' });
  }
};

exports.createMembershipRequest = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    return res.status(403).json({
      message:
        'Membership changes now happen only through your gym team. Please visit the front desk for renewals, upgrades, add-ons, or payment updates.',
    });
  } catch (error) {
    console.error('Error creating membership request:', error);
    return res.status(500).json({ message: error.message || 'Error creating membership request' });
  }
};

exports.getMyEntitlements = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const entitlements = await MembershipService.getMemberEntitlements(req.user.gymId, req.user._id);
    
    return res.status(200).json({
      entitlements: entitlements ? {
        membership: entitlements.membership,
        features: entitlements.entitlements,
      } : null,
    });
  } catch (error) {
    console.error('Error fetching entitlements:', error);
    return res.status(500).json({ message: 'Error fetching entitlements' });
  }
};

exports.getMyMembershipReceipt = receiptController.getMyMembershipReceipt;
