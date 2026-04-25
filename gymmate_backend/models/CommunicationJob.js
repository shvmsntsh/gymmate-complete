const mongoose = require('mongoose');

const communicationJobSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    templateId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'CommunicationTemplate',
      default: null,
    },
    channel: {
      type: String,
      enum: ['whatsapp', 'sms', 'email', 'push', 'manual'],
      default: 'manual',
      index: true,
    },
    audienceType: {
      type: String,
      enum: ['members', 'leads', 'staff', 'custom'],
      default: 'custom',
    },
    status: {
      type: String,
      enum: ['draft', 'queued', 'sent', 'failed', 'cancelled'],
      default: 'draft',
      index: true,
    },
    segment: {
      type: Object,
      default: {},
    },
    scheduledAt: {
      type: Date,
      default: null,
      index: true,
    },
    sentAt: {
      type: Date,
      default: null,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true },
);

communicationJobSchema.index({ gymId: 1, status: 1, scheduledAt: 1 });

module.exports = mongoose.model('CommunicationJob', communicationJobSchema);
