const mongoose = require('mongoose');

const communicationTemplateSchema = new mongoose.Schema(
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
    channel: {
      type: String,
      enum: ['whatsapp', 'sms', 'email', 'push', 'manual'],
      default: 'whatsapp',
      index: true,
    },
    trigger: {
      type: String,
      enum: ['renewal_reminder', 'payment_due', 'birthday', 'welcome', 'lead_follow_up', 'class_reminder', 'custom'],
      default: 'custom',
      index: true,
    },
    body: {
      type: String,
      required: true,
      trim: true,
      maxlength: 2000,
    },
    active: {
      type: Boolean,
      default: false,
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

communicationTemplateSchema.index({ gymId: 1, trigger: 1, active: 1 });

module.exports = mongoose.model('CommunicationTemplate', communicationTemplateSchema);
