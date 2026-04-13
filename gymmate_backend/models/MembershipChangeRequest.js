const mongoose = require('mongoose');

const membershipChangeRequestSchema = new mongoose.Schema(
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
      index: true,
    },
    requestType: {
      type: String,
      enum: ['new_membership', 'renewal', 'upgrade', 'downgrade', 'freeze', 'cancel', 'add_on'],
      required: true,
      index: true,
    },
    currentMembershipId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MemberMembership',
      default: null,
    },
    targetMembershipTemplateId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MembershipTemplate',
      default: null,
    },
    requestedAddOns: {
      personalTraining: { type: Boolean, default: false },
      dietPlan: { type: Boolean, default: false },
    },
    paymentMode: {
      type: String,
      enum: ['cash', 'upi', 'card', 'online', 'manual', 'waived'],
      default: null,
    },
    paymentProofUrl: {
      type: String,
      default: '',
      trim: true,
    },
    paymentReference: {
      type: String,
      default: '',
      trim: true,
      maxlength: 500,
    },
    memberNote: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1000,
    },
    adminNote: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1000,
    },
    status: {
      type: String,
      enum: ['submitted', 'awaiting_payment', 'payment_under_review', 'approved', 'rejected', 'canceled', 'expired'],
      default: 'submitted',
      index: true,
    },
    requestedAt: {
      type: Date,
      default: Date.now,
    },
    verifiedAt: {
      type: Date,
      default: null,
    },
    verifiedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    decidedAt: {
      type: Date,
      default: null,
    },
    decidedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    effectiveDate: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

membershipChangeRequestSchema.index({ gymId: 1, status: 1, requestedAt: -1 });
membershipChangeRequestSchema.index({ memberId: 1, status: 1, requestedAt: -1 });
membershipChangeRequestSchema.index({ gymId: 1, memberId: 1, status: 1 });

module.exports = mongoose.model('MembershipChangeRequest', membershipChangeRequestSchema);
