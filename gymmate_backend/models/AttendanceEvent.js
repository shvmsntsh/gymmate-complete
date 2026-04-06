const mongoose = require('mongoose');

const attendanceEventSchema = new mongoose.Schema(
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
      index: true,
    },
    integrationId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BiometricIntegration',
      default: null,
    },
    source: {
      type: String,
      enum: ['manual', 'biometric_identix'],
      default: 'manual',
      index: true,
    },
    eventType: {
      type: String,
      enum: ['check_in', 'check_out'],
      default: 'check_in',
    },
    externalEventId: {
      type: String,
      default: null,
      sparse: true,
    },
    occurredAt: {
      type: Date,
      required: true,
      index: true,
    },
    metadata: {
      type: Object,
      default: {},
    },
  },
  { timestamps: true },
);

attendanceEventSchema.index({ integrationId: 1, externalEventId: 1 }, { unique: true, sparse: true });
attendanceEventSchema.index({ memberId: 1, occurredAt: -1 });

module.exports = mongoose.model('AttendanceEvent', attendanceEventSchema);
