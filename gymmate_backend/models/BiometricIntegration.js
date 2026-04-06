const mongoose = require('mongoose');

const biometricIntegrationSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      unique: true,
    },
    providerKey: {
      type: String,
      default: 'identix',
      trim: true,
    },
    enabled: {
      type: Boolean,
      default: false,
    },
    config: {
      type: Object,
      default: {},
    },
    lastSyncAt: {
      type: Date,
      default: null,
    },
    lastSyncStatus: {
      type: String,
      enum: ['never', 'success', 'failed'],
      default: 'never',
    },
    lastSyncError: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1000,
    },
  },
  { timestamps: true },
);

module.exports = mongoose.model('BiometricIntegration', biometricIntegrationSchema);
