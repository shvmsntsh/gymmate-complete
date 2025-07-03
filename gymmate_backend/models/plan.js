const mongoose = require('mongoose');

const planSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  onboardingHash: { type: String, required: true },
  plan: { type: Object, required: true },
  updatedAt: { type: Date, default: Date.now },
});

planSchema.index({ user: 1, onboardingHash: 1 }, { unique: true });

module.exports = mongoose.model('Plan', planSchema); 