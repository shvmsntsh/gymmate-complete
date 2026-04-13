const mongoose = require('mongoose');

const memberMembershipSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    memberId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    membershipTemplateId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MembershipTemplate',
      default: null,
    },
    status: {
      type: String,
      enum: [
        'pending_payment',
        'pending_approval',
        'active',
        'renewal_due',
        'expired',
        'frozen',
        'canceled',
        'rejected',
      ],
      default: 'pending_payment',
      index: true,
    },
    startDate: {
      type: Date,
      default: null,
    },
    endDate: {
      type: Date,
      default: null,
      index: true,
    },
    nextRenewalDate: {
      type: Date,
      default: null,
      index: true,
    },
    activatedAt: {
      type: Date,
      default: null,
    },
    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    paymentStatus: {
      type: String,
      enum: ['unpaid', 'payment_under_review', 'paid', 'waived'],
      default: 'unpaid',
      index: true,
    },
    paymentMethod: {
      type: String,
      enum: ['cash', 'upi', 'card', 'online', 'manual', 'waived', null],
      default: null,
    },
    paymentReference: {
      type: String,
      default: '',
      trim: true,
      maxlength: 500,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1000,
    },
    entitlementsSnapshot: {
      gymAccess: { type: Boolean, default: false },
      classAccess: { type: Boolean, default: false },
      trainerSupport: { type: Boolean, default: false },
      dietSupport: { type: Boolean, default: false },
      biometricAccess: { type: Boolean, default: false },
      lockerAccess: { type: Boolean, default: false },
      guestPasses: { type: Number, default: 0 },
      personalTraining: { type: Boolean, default: false },
      dietPlan: { type: Boolean, default: false },
    },
    isFrozen: {
      type: Boolean,
      default: false,
    },
    frozenAt: {
      type: Date,
      default: null,
    },
    frozenUntil: {
      type: Date,
      default: null,
    },
    isActiveBaseMembership: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

memberMembershipSchema.index({ gymId: 1, memberId: 1, status: 1 });
memberMembershipSchema.index({ gymId: 1, isActiveBaseMembership: 1 });
memberMembershipSchema.index({ memberId: 1, status: 1 });

module.exports = mongoose.model('MemberMembership', memberMembershipSchema);
