const mongoose = require('mongoose');

const classTemplateSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    type: {
      type: String,
      enum: ['group_class', 'personal_training', 'workshop', 'assessment'],
      default: 'group_class',
      index: true,
    },
    description: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1200,
    },
    trainerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    defaultCapacity: {
      type: Number,
      default: 10,
      min: 1,
      max: 500,
    },
    durationMinutes: {
      type: Number,
      default: 60,
      min: 5,
      max: 360,
    },
    requiresMembership: {
      type: Boolean,
      default: true,
    },
    deductsEntitlement: {
      type: Boolean,
      default: false,
    },
    active: {
      type: Boolean,
      default: true,
      index: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
  },
  { timestamps: true },
);

classTemplateSchema.index({ gymId: 1, active: 1, name: 1 });

module.exports = mongoose.model('ClassTemplate', classTemplateSchema);
