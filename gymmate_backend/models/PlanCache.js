const mongoose = require('mongoose');

const PlanCacheSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  onboardingHash: { type: String, required: true },
  plan: { type: Object, required: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('PlanCache', PlanCacheSchema); 