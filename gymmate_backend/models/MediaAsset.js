const mongoose = require('mongoose');

const mediaAssetSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    uploadedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    fileName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },
    contentType: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    contentHash: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    sizeBytes: {
      type: Number,
      required: true,
      min: 1,
    },
    data: {
      type: Buffer,
      required: true,
      select: false,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: { expires: 0 },
    },
  },
  { timestamps: true },
);

mediaAssetSchema.index({ gymId: 1, contentHash: 1 }, { unique: true });

module.exports = mongoose.model('MediaAsset', mediaAssetSchema);
