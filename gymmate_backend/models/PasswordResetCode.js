const mongoose = require('mongoose');

const passwordResetCodeSchema = new mongoose.Schema({
  email: { type: String, required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  codeHash: { type: String, required: true },
  expiresAt: { type: Date, required: true, index: true },
  usedAt: { type: Date, default: null },
  attempts: { type: Number, default: 0 },
  ipAddress: { type: String, default: '' },
  userAgent: { type: String, default: '' },
}, { timestamps: true });

passwordResetCodeSchema.index({ email: 1, createdAt: -1 });
passwordResetCodeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 3600 });

module.exports = mongoose.model('PasswordResetCode', passwordResetCodeSchema);
