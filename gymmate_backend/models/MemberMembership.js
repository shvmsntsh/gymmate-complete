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
      unique: true,
    },
    planId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MembershipPlanCatalog',
      default: null,
    },
    planName: {
      type: String,
      default: '',
      trim: true,
    },
    status: {
      type: String,
      enum: ['inactive', 'active', 'expiring', 'expired', 'payment_pending'],
      default: 'inactive',
      index: true,
    },
    paymentStatus: {
      type: String,
      enum: ['none', 'pending', 'paid'],
      default: 'none',
      index: true,
    },
    startDate: {
      type: Date,
      default: null,
    },
    endDate: {
      type: Date,
      default: null,
    },
    renewalDueDate: {
      type: Date,
      default: null,
      index: true,
    },
    addOns: {
      training: { type: Boolean, default: false },
      diet: { type: Boolean, default: false },
    },
    lastPaymentAt: {
      type: Date,
      default: null,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
      maxlength: 500,
    },
  },
  { timestamps: true },
);

memberMembershipSchema.index({ gymId: 1, status: 1, renewalDueDate: 1 });

module.exports = mongoose.model('MemberMembership', memberMembershipSchema);
