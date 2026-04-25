const mongoose = require('mongoose');

const staffActivityLogSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    actorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    targetUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    action: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    entityType: {
      type: String,
      default: '',
      trim: true,
      maxlength: 80,
    },
    entityId: {
      type: mongoose.Schema.Types.ObjectId,
      default: null,
    },
    payload: {
      type: Object,
      default: {},
    },
  },
  { timestamps: true },
);

staffActivityLogSchema.index({ gymId: 1, createdAt: -1 });

module.exports = mongoose.model('StaffActivityLog', staffActivityLogSchema);
