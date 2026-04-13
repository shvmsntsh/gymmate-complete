const mongoose = require('mongoose');

const membershipTemplateSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    shortDescription: {
      type: String,
      default: '',
      trim: true,
      maxlength: 200,
    },
    fullDescription: {
      type: String,
      default: '',
      trim: true,
      maxlength: 2000,
    },
    durationDays: {
      type: Number,
      required: true,
      min: 1,
      max: 730,
    },
    price: {
      type: Number,
      default: 0,
      min: 0,
    },
    joiningFee: {
      type: Number,
      default: 0,
      min: 0,
    },
    renewalLeadDays: {
      type: Number,
      default: 7,
      min: 0,
      max: 90,
    },
    active: {
      type: Boolean,
      default: true,
      index: true,
    },
    visibleToMembers: {
      type: Boolean,
      default: true,
      index: true,
    },
    sortOrder: {
      type: Number,
      default: 0,
    },
    upgradeRank: {
      type: Number,
      default: 0,
    },
    category: {
      type: String,
      enum: ['trial', 'monthly', 'quarterly', 'yearly', 'add_on'],
      default: 'monthly',
      index: true,
    },
    includedFeatures: {
      gymAccess: { type: Boolean, default: false },
      classAccess: { type: Boolean, default: false },
      trainerSupport: { type: Boolean, default: false },
      dietSupport: { type: Boolean, default: false },
      biometricAccess: { type: Boolean, default: false },
      lockerAccess: { type: Boolean, default: false },
      guestPasses: { type: Number, default: 0 },
    },
    availableAddOns: {
      personalTraining: { type: Boolean, default: false },
      dietPlan: { type: Boolean, default: false },
    },
    rules: {
      canUpgrade: { type: Boolean, default: true },
      canDowngrade: { type: Boolean, default: false },
      canFreeze: { type: Boolean, default: false },
      freezeLimitDays: { type: Number, default: 0 },
      requiresOwnerApproval: { type: Boolean, default: true },
      overlapPolicy: {
        type: String,
        enum: ['allow_overlap', 'queue_after_current', 'replace_immediately', 'warn_and_require_override'],
        default: 'warn_and_require_override',
      },
      approvalTimingPolicy: {
        type: String,
        enum: ['activate_immediately', 'queue_after_current', 'by_request_type'],
        default: 'by_request_type',
      },
      prorationMode: {
        type: String,
        enum: ['none', 'credit_remaining_days', 'restart_full_term'],
        default: 'none',
      },
      prorationPolicy: {
        type: String,
        enum: ['none', 'credit_remaining_days', 'charge_full_amount'],
        default: 'none',
      },
      freezePolicy: {
        type: String,
        enum: ['none', 'extend_end_date', 'manual_only'],
        default: 'extend_end_date',
      },
      manualOverridePolicy: {
        type: String,
        enum: ['owner_only', 'manager_allowed'],
        default: 'owner_only',
      },
      paymentModesAllowed: {
        type: [String],
        default: ['cash', 'upi', 'card', 'online', 'manual', 'waived'],
      },
    },
  },
  { timestamps: true }
);

membershipTemplateSchema.index({ gymId: 1, active: 1, sortOrder: 1, name: 1 });
membershipTemplateSchema.index({ gymId: 1, visibleToMembers: 1, category: 1 });

module.exports = mongoose.model('MembershipTemplate', membershipTemplateSchema);
