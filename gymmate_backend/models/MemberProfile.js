const mongoose = require('mongoose');

const MemberProfileSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  gymId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Gym',
  },
  sex: {
    type: String,
    enum: ['male', 'female'],
    required: true,
  },
  age: {
    type: Number,
    required: true,
    min: 14,
    max: 80,
  },
  weightKg: {
    type: Number,
    required: true,
  },
  heightCm: {
    type: Number,
    required: true,
  },
  goal: {
    type: String,
    enum: ['lose_fat', 'build_muscle', 'get_fit', 'maintain'],
    required: true,
  },
  fitnessLevel: {
    type: String,
    enum: ['beginner', 'intermediate', 'advanced'],
    required: true,
  },
  daysPerWeek: {
    type: Number,
    enum: [3, 4, 5, 6],
    required: true,
  },
  dietPref: {
    type: String,
    enum: ['none', 'vegetarian', 'vegan', 'keto', 'high_protein'],
    default: 'none',
  },
  limitations: { type: String },
  tdeeKcal: { type: Number },
  targetKcal: { type: Number },
  onboardedAt: {
    type: Date,
    default: Date.now,
  },
}, { timestamps: true });

module.exports = mongoose.model('MemberProfile', MemberProfileSchema);
