const mongoose = require('mongoose');

const planSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  gymId: { type: mongoose.Schema.Types.ObjectId, ref: 'Gym', default: null },
  onboardingHash: { type: String, required: true },
  plan: { type: Object, required: true },
  updatedAt: { type: Date, default: Date.now },
});

planSchema.index({ user: 1, onboardingHash: 1 }, { unique: true });
planSchema.index({ gymId: 1, user: 1 });

module.exports = mongoose.model('Plan', planSchema); 
