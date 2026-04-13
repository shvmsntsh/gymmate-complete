require('dotenv').config();
const mongoose = require('mongoose');

const User = require('../models/User');
const MemberMembership = require('../models/MemberMembership');
const MembershipChangeRequest = require('../models/MembershipChangeRequest');
const PaymentEntry = require('../models/PaymentEntry');
const MembershipService = require('../services/membershipService');

const MONGODB_URI =
  process.env.MONGODB_URI ||
  process.env.MONGO_URI ||
  'mongodb://127.0.0.1:27017/gymmate';

async function main() {
  await mongoose.connect(MONGODB_URI);

  try {
    const owner = await User.findOne({ email: 'owner@testgym.local' });
    const member = await User.findOne({ email: 'member@testgym.local' });

    if (!owner || !member) {
      throw new Error('Seeded owner/member not found. Run reset-and-seed-test-gym.js first.');
    }

    const activeMembership = await MemberMembership.findOne({
      gymId: owner.gymId,
      memberId: member._id,
      isActiveBaseMembership: true,
    }).populate('membershipTemplateId');

    if (!activeMembership) {
      throw new Error('No active membership found for seeded member.');
    }

    const submittedRequest = await MembershipService.createChangeRequest(
      owner.gymId,
      member._id,
      {
        requestType: 'renewal',
        currentMembershipId: activeMembership._id,
        targetMembershipTemplateId: activeMembership.membershipTemplateId?._id,
        paymentMode: 'upi',
        paymentReference: 'TEST-UPI-RENEWAL',
        memberNote: 'Created by automated renewal test.',
      },
    );

    let unpaidApprovalBlocked = false;
    try {
      await MembershipService.approveRequest(
        submittedRequest._id,
        owner.gymId,
        owner._id,
        {},
      );
    } catch (error) {
      unpaidApprovalBlocked = /payment|blocker|pending/i.test(error.message);
    }

    if (!unpaidApprovalBlocked) {
      throw new Error('Unpaid renewal request was not blocked before approval.');
    }

    const verified = await MembershipService.verifyPayment(
      submittedRequest._id,
      owner.gymId,
      owner._id,
      { paymentMethod: 'upi', paymentReference: 'TEST-UPI-RENEWAL-VERIFIED' },
    );

    const approved = await MembershipService.approveRequest(
      verified._id,
      owner.gymId,
      owner._id,
      {},
    );

    const recordedPayment = await PaymentEntry.findOne({
      gymId: owner.gymId,
      memberId: member._id,
      membershipRequestId: submittedRequest._id,
    }).lean();

    if (!recordedPayment || recordedPayment.mode !== 'upi') {
      throw new Error(`Expected UPI payment entry, got ${recordedPayment?.mode || 'none'}.`);
    }

    const renewedMembership = await MemberMembership.findOne({
      gymId: owner.gymId,
      memberId: member._id,
      isActiveBaseMembership: true,
    }).populate('membershipTemplateId');

    const queuedRenewal = await MemberMembership.findOne({
      gymId: owner.gymId,
      memberId: member._id,
      isActiveBaseMembership: false,
      status: 'pending_approval',
    }).populate('membershipTemplateId');

    const rejectableRequest = await MembershipChangeRequest.create({
      gymId: owner.gymId,
      memberId: member._id,
      requestType: 'add_on',
      currentMembershipId: renewedMembership?._id || null,
      requestedAddOns: {
        personalTraining: true,
        dietPlan: false,
      },
      paymentMode: 'cash',
      paymentReference: 'TEST-CASH-REJECT',
      memberNote: 'Created by test script for reject flow.',
      status: 'submitted',
      requestedAt: new Date(),
    });

    const duplicatePaymentRequest = await MembershipChangeRequest.create({
      gymId: owner.gymId,
      memberId: member._id,
      requestType: 'renewal',
      currentMembershipId: renewedMembership?._id || activeMembership._id,
      targetMembershipTemplateId: renewedMembership?.membershipTemplateId?._id || activeMembership.membershipTemplateId?._id,
      paymentMode: 'upi',
      paymentReference: 'TEST-UPI-RENEWAL-VERIFIED',
      memberNote: 'Created by test script for duplicate payment reference check.',
      status: 'payment_under_review',
      verifiedAt: new Date(),
      verifiedBy: owner._id,
      requestedAt: new Date(),
    });

    const duplicatePreview = await MembershipService.computeDecisionPreview({
      gymId: owner.gymId,
      request: duplicatePaymentRequest,
      currentMembership: renewedMembership || activeMembership,
      targetTemplate: renewedMembership?.membershipTemplateId || activeMembership.membershipTemplateId,
    });

    if (!duplicatePreview.blockers.some((item) => item.code === 'duplicate_payment_reference')) {
      throw new Error('Duplicate payment reference was not reported as a blocker.');
    }

    const rejected = await MembershipService.rejectRequest(
      rejectableRequest._id,
      owner.gymId,
      owner._id,
      'Rejected by automated flow test.',
    );

    console.log(
      JSON.stringify(
        {
          verifiedRequestStatus: verified.status,
          unpaidApprovalBlocked,
          recordedPaymentMode: recordedPayment.mode,
          duplicatePaymentBlocker: true,
          approvedRequestStatus: approved.request.status,
          activeMembership: renewedMembership
            ? {
                templateName: renewedMembership.membershipTemplateId?.name,
                paymentStatus: renewedMembership.paymentStatus,
                paymentReference: renewedMembership.paymentReference,
                startDate: renewedMembership.startDate,
                endDate: renewedMembership.endDate,
              }
            : null,
          queuedRenewal: queuedRenewal
            ? {
                templateName: queuedRenewal.membershipTemplateId?.name,
                startDate: queuedRenewal.startDate,
                endDate: queuedRenewal.endDate,
                nextRenewalDate: queuedRenewal.nextRenewalDate,
              }
            : null,
          rejectedRequestStatus: rejected.status,
        },
        null,
        2,
      ),
    );
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
