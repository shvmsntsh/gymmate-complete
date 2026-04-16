const BillingReceipt = require('../models/BillingReceipt');
const MemberMembership = require('../models/MemberMembership');
const MembershipService = require('../services/membershipService');
const { hasPermission, hasRole } = require('../utils/roles');

function canViewOwnerReceipt(user) {
  return hasPermission(user, 'members.manage') || hasPermission(user, 'payments.manage') || hasRole(user, ['owner']);
}

function serializeReceipt(receipt) {
  if (!receipt) {
    return null;
  }

  const gym = receipt.gymId && typeof receipt.gymId === 'object' ? receipt.gymId : null;
  const member = receipt.memberId && typeof receipt.memberId === 'object' ? receipt.memberId : null;
  const membership =
    receipt.membershipId && typeof receipt.membershipId === 'object' ? receipt.membershipId : null;

  return {
    id: receipt._id,
    receiptNumber: receipt.receiptNumber,
    publicToken: receipt.publicToken,
    publicPath: `/receipt/${receipt.publicToken}`,
    amount: receipt.amount || 0,
    currency: receipt.currency || 'INR',
    paymentMethod: receipt.paymentMethod || '',
    paymentReference: receipt.paymentReference || '',
    planName: receipt.planName || membership?.membershipTemplateId?.name || 'Membership Plan',
    issuedAt: receipt.issuedAt,
    gym: gym
      ? {
          id: gym._id,
          name: gym.gymName || gym.name || 'GymMate Gym',
          email: gym.email || '',
          address: gym.address || '',
          contactNumber: gym.contactNumber || '',
        }
      : null,
    member: member
      ? {
          id: member._id,
          name: member.name || '',
          email: member.email || '',
          phone_number: member.phone_number || '',
        }
      : null,
    membership: membership
      ? {
          id: membership._id,
          startDate: membership.startDate,
          endDate: membership.endDate,
          status: membership.status,
          paymentStatus: membership.paymentStatus,
        }
      : null,
  };
}

async function fetchReceiptByMembership(membershipId, gymId = null) {
  const membershipFilter = { _id: membershipId };
  if (gymId) {
    membershipFilter.gymId = gymId;
  }

  const membership = await MemberMembership.findOne(membershipFilter).populate('membershipTemplateId');
  if (!membership) {
    return null;
  }

  const receipt = await MembershipService.ensureReceiptForMembership(membership, membership.approvedBy);
  if (!receipt) {
    return null;
  }

  return BillingReceipt.findById(receipt._id)
    .populate('gymId', 'gymName name email address contactNumber')
    .populate('memberId', 'name email phone_number')
    .populate({
      path: 'membershipId',
      populate: { path: 'membershipTemplateId', select: 'name price category' },
    });
}

exports.getOwnerMembershipReceipt = async (req, res) => {
  if (!canViewOwnerReceipt(req.user)) {
    return res.status(403).json({ message: 'Forbidden: receipt access required' });
  }

  try {
    const receipt = await fetchReceiptByMembership(req.params.membershipId, req.user.gymId);
    if (!receipt) {
      return res.status(404).json({ message: 'Receipt not found for this membership.' });
    }
    return res.status(200).json({ receipt: serializeReceipt(receipt) });
  } catch (error) {
    console.error('Error fetching membership receipt:', error);
    return res.status(500).json({ message: 'Error fetching receipt' });
  }
};

exports.getMyMembershipReceipt = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym_member only' });
  }

  try {
    const membership = await MembershipService.getActiveMembership(req.user.gymId, req.user._id);
    if (!membership) {
      return res.status(404).json({ message: 'No active membership found.' });
    }

    const receipt = await fetchReceiptByMembership(membership._id, req.user.gymId);
    if (!receipt) {
      return res.status(404).json({ message: 'Receipt not found for this membership.' });
    }
    return res.status(200).json({ receipt: serializeReceipt(receipt) });
  } catch (error) {
    console.error('Error fetching member receipt:', error);
    return res.status(500).json({ message: 'Error fetching receipt' });
  }
};

exports.getPublicReceipt = async (req, res) => {
  try {
    const receipt = await BillingReceipt.findOne({ publicToken: String(req.params.token || '').trim() })
      .populate('gymId', 'gymName name email address contactNumber')
      .populate('memberId', 'name email phone_number')
      .populate({
        path: 'membershipId',
        populate: { path: 'membershipTemplateId', select: 'name price category' },
      });

    if (!receipt) {
      return res.status(404).json({ message: 'Receipt not found.' });
    }

    return res.status(200).json({ receipt: serializeReceipt(receipt) });
  } catch (error) {
    console.error('Error fetching public receipt:', error);
    return res.status(500).json({ message: 'Error fetching receipt' });
  }
};
