const mongoose = require('mongoose');

const biometricIdentitySchema = new mongoose.Schema(
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
      required: true,
    },
    externalMemberKey: {
      type: String,
      required: true,
      trim: true,
    },
    status: {
      type: String,
      enum: ['active', 'inactive'],
      default: 'active',
    },
  },
  { timestamps: true },
);

biometricIdentitySchema.index({ integrationId: 1, externalMemberKey: 1 }, { unique: true });

module.exports = mongoose.model('BiometricIdentity', biometricIdentitySchema);
