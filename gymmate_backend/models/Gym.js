const mongoose = require('mongoose');

const gymSchema = new mongoose.Schema({
  gymName: { type: String, required: true },
  slug: { type: String, unique: true, sparse: true },
  email: { type: String, required: true, unique: true },
  password: String,
  address: String,
  contactNumber: String,
  services: [String],
  serviceSlugs: [String],
  status: {
    type: String,
    enum: ['active', 'inactive'],
    default: 'active'
  },
  platformPlan: {
    type: String,
    enum: ['starter', 'growth', 'pro', 'elite', 'custom'],
    default: 'starter',
  },
  memberCap: {
    type: Number,
    default: 100,
  },
  planStatus: {
    type: String,
    enum: ['active', 'locked'],
    default: 'active',
  },
  planUpdatedAt: {
    type: Date,
    default: null,
  },
  planUpdatedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  // Only used when platformPlan === 'custom' — negotiated per gym rather
  // than fixed in utils/platformPlans.js's tier table.
  customPricePerMember: {
    type: Number,
    default: null,
  },
  customFloorPrice: {
    type: Number,
    default: null,
  },
  // Every NEW gym starts on a 1-month free trial automatically (function
  // default runs at document-creation time, so it applies uniformly across
  // every registration path without each one needing its own code).
  // Existing gyms created before this field existed have no trialEndsAt at
  // all — they are NOT retroactively put on a trial. See
  // utils/gymLimits.js for the lazy (no cron) expiry check, and
  // adminController.recordPlanPayment for how a superadmin graduates a
  // gym off trial by recording its first real payment.
  trialEndsAt: {
    type: Date,
    default: function trialDefault() {
      const d = new Date();
      d.setMonth(d.getMonth() + 1);
      return d;
    },
  },
  // Informational: end date of the most recently recorded platform
  // payment. Set only by the superadmin plan-payment flow — there is no
  // automatic expiry job, this never self-updates or self-locks.
  planPaidUntil: {
    type: Date,
    default: null,
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
