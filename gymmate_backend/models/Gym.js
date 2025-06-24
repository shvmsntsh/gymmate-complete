const mongoose = require('mongoose');

const gymSchema = new mongoose.Schema({
  gymName: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: String,
  address: String,
  contactNumber: String,
  services: [String],
  role: {
    type: String,
    enum: ['superadmin', 'gym_owner', 'gym_member'],
    default: 'gym_owner'
  },
  lastLoginAt: {
    type: Date,
    default: null
  },
  loginTimestamps: [{
    type: Date,
    default: Date.now
  }],
  profile: {
    name: { type: String },
    age: { type: Number },
    gender: { type: String, enum: ['Male', 'Female', 'Other'] },
    height: { type: Number }, // in cm
    weight: { type: Number }  // in kg
  },
  diet: {
    type: String,
    enum: ['Vegetarian', 'Vegan', 'Non-Vegetarian', 'Keto', 'Paleo', 'Other'],
    default: undefined
  },
  workout: {
    type: String,
    enum: ['Strength', 'Cardio', 'Yoga', 'CrossFit', 'Mixed', 'Other'],
    default: undefined
  },
  fitnessGoals: [String],
  onboardingStep: {
    type: Number,
    default: 0
  }
}, { timestamps: true });

gymSchema.post('save', function(error, doc, next) {
  if (error) {
    console.error('❌ Gym schema validation error:', error);
  }
  next(error);
});

module.exports = mongoose.model('Gym', gymSchema);