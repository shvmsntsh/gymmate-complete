const mongoose = require('mongoose');

const PlanCacheSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  gymId: { type: mongoose.Schema.Types.ObjectId, ref: 'Gym', default: null },
  onboardingHash: { type: String, required: true },
  plan: { type: Object, required: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

PlanCacheSchema.index({ gymId: 1, userId: 1 });

module.exports = mongoose.model('PlanCache', PlanCacheSchema); 
