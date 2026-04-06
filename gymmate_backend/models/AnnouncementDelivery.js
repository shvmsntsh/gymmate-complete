const mongoose = require('mongoose');

const announcementDeliverySchema = new mongoose.Schema(
  {
    announcementId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Announcement',
      required: true,
      index: true,
    },
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
    inAppStatus: {
      type: String,
      enum: ['delivered', 'read'],
      default: 'delivered',
      index: true,
    },
    telegramStatus: {
      type: String,
      enum: ['skipped', 'pending', 'sent', 'failed'],
      default: 'skipped',
    },
    readAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true },
);

announcementDeliverySchema.index({ announcementId: 1, memberId: 1 }, { unique: true });
announcementDeliverySchema.index({ memberId: 1, createdAt: -1 });

module.exports = mongoose.model('AnnouncementDelivery', announcementDeliverySchema);
