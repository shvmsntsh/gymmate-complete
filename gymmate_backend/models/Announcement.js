const mongoose = require('mongoose');

const announcementSchema = new mongoose.Schema(
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
    type: {
      type: String,
      enum: ['general', 'offer', 'holiday'],
      default: 'general',
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    body: {
      type: String,
      required: true,
      trim: true,
      maxlength: 4000,
    },
    audience: {
      scope: {
        type: String,
        enum: ['all', 'active', 'inactive', 'selected'],
        default: 'all',
      },
      memberIds: [
        {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'User',
        },
      ],
    },
    mediaAssetId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MediaAsset',
      default: null,
    },
    status: {
      type: String,
      enum: ['draft', 'sent', 'archived'],
      default: 'sent',
      index: true,
    },
    sentAt: {
      type: Date,
      default: Date.now,
    },
    deliverySummary: {
      targetedCount: { type: Number, default: 0 },
      deliveredCount: { type: Number, default: 0 },
      readCount: { type: Number, default: 0 },
      telegramCount: { type: Number, default: 0 },
    },
  },
  { timestamps: true },
);

announcementSchema.index({ gymId: 1, sentAt: -1 });

module.exports = mongoose.model('Announcement', announcementSchema);
