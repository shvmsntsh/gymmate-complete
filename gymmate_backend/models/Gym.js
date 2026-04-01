const mongoose = require('mongoose');

const gymSchema = new mongoose.Schema({
  gymName: { type: String, required: true },
  slug: { type: String, unique: true, sparse: true },
  email: { type: String, required: true, unique: true },
  password: String,
  address: String,
  contactNumber: String,
  services: [String],
  status: {
    type: String,
    enum: ['active', 'inactive'],
    default: 'active'
  },
  branding: {
    logoUrl: { type: String, default: null },
    primaryColor: { type: String, default: '#4A90E2' },
    secondaryColor: { type: String, default: '#03DAC6' },
    logoScale: { type: Number, default: 1 },
    logoOffsetX: { type: Number, default: 0 },
    logoOffsetY: { type: Number, default: 0 }
  },
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
  },
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: false
  }
}, { timestamps: true });

module.exports = mongoose.model('Gym', gymSchema);
