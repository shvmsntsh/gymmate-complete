const mongoose = require('mongoose');

const membershipRequestSchema = new mongoose.Schema(
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
    membershipId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MemberMembership',
      default: null,
    },
    requestType: {
      type: String,
      enum: ['upgrade', 'renewal', 'training', 'diet'],
      required: true,
      index: true,
    },
    targetPlanId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MembershipPlanCatalog',
      default: null,
    },
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected', 'payment_pending', 'activated'],
      default: 'pending',
      index: true,
    },
    note: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1000,
    },
    response: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1000,
    },
    handledBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    handledAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true },
);

membershipRequestSchema.index({ gymId: 1, status: 1, createdAt: -1 });
membershipRequestSchema.index({ memberId: 1, createdAt: -1 });

module.exports = mongoose.model('MembershipRequest', membershipRequestSchema);
