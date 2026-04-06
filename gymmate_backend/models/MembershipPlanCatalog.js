const mongoose = require('mongoose');

const membershipPlanCatalogSchema = new mongoose.Schema(
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
    description: {
      type: String,
      default: '',
      trim: true,
      maxlength: 800,
    },
    durationDays: {
      type: Number,
      required: true,
      min: 1,
      max: 730,
    },
    includedServices: {
      type: [String],
      default: [],
    },
    renewalLeadDays: {
      type: Number,
      default: 7,
      min: 0,
      max: 90,
    },
    addOns: {
      training: { type: Boolean, default: false },
      diet: { type: Boolean, default: false },
    },
    active: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  { timestamps: true },
);

membershipPlanCatalogSchema.index({ gymId: 1, active: 1, name: 1 });

module.exports = mongoose.model('MembershipPlanCatalog', membershipPlanCatalogSchema);
