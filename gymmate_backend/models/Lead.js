const mongoose = require('mongoose');

const leadSchema = new mongoose.Schema(
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
    email: {
      type: String,
      default: '',
      trim: true,
      lowercase: true,
      maxlength: 160,
    },
    phone: {
      type: String,
      default: '',
      trim: true,
      maxlength: 40,
      index: true,
    },
    source: {
      type: String,
      enum: ['walk_in', 'website', 'whatsapp', 'instagram', 'facebook', 'referral', 'campaign', 'manual', 'other'],
      default: 'manual',
      index: true,
    },
    status: {
      type: String,
      enum: ['new', 'contacted', 'trial_scheduled', 'trial_done', 'won', 'lost', 'dormant'],
      default: 'new',
      index: true,
    },
    interest: {
      type: String,
      default: '',
      trim: true,
      maxlength: 160,
    },
    goal: {
      type: String,
      default: '',
      trim: true,
      maxlength: 260,
    },
    preferredService: {
      type: String,
      default: '',
      trim: true,
      maxlength: 120,
    },
    trialDate: {
      type: Date,
      default: null,
      index: true,
    },
    nextFollowUpAt: {
      type: Date,
      default: null,
      index: true,
    },
    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    convertedMemberId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    convertedAt: {
      type: Date,
      default: null,
    },
    lostReason: {
      type: String,
      default: '',
      trim: true,
      maxlength: 260,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1200,
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

leadSchema.index({ gymId: 1, status: 1, nextFollowUpAt: 1 });
leadSchema.index({ gymId: 1, createdAt: -1 });

module.exports = mongoose.model('Lead', leadSchema);
