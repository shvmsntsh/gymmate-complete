const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  // Full name of the user (owner or member)
  name: {
    type: String,
    required: true,
  },
  // Email used for login
  email: {
    type: String,
    required: true,
    unique: true,
  },
  phone_number: {
    type: String,
    unique: true,
    sparse: true, // Allows multiple documents to have a null value for this field
  },
  // Hashed password
  password: {
    type: String,
    // Not required if user is only invited
    required: function() { return !this.invited && !this.registeredFromInviteAt; },
  },
  // Role determines access level:
  // 'superadmin' = central builder's office (superadmin)
  // 'admin' = central builder's office (admin)
  // 'gym_owner' = society secretary (manages one gym)
  // 'gym_member' = flat owner (can only see own record)
  // 'gym_trainer' = trainer (can edit/view plans for members in their gym)
  role: {
    type: String,
    enum: ['superadmin', 'admin', 'gym_owner', 'gym_staff', 'gym_member', 'gym_trainer'],
    default: 'gym_owner',
  },
  // Reference to associated Gym (for gym_owner, gym_member, gym_trainer)
  gymId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Gym',
    required: function() {
      return this.role === 'gym_member' || this.role === 'gym_trainer' || this.role === 'gym_staff';
    }
  },
  staffCapabilities: {
    'workspace.access': { type: Boolean, default: false },
    'members.manage': { type: Boolean, default: false },
    'announcements.manage': { type: Boolean, default: false },
    'membership.requests.manage': { type: Boolean, default: false },
    'payments.manage': { type: Boolean, default: false },
    'membership.plans.manage': { type: Boolean, default: false },
    'biometric.manage': { type: Boolean, default: false },
  },
  telegramProfile: {
    chatId: { type: String, default: null },
    handle: { type: String, default: null },
    linkedAt: { type: Date, default: null },
  },
  invited: {
    type: Boolean,
    default: false,
  },
  registered: {
    type: Boolean,
    default: false,
  },
  inviteCodeId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'InviteCode',
    default: null,
  },
  inviteCode: {
    type: String,
    default: null,
  },
  registeredFromInviteAt: {
    type: Date,
    default: null,
  },
  registrationMethod: {
    type: String,
    enum: ['invite_registration', 'first_time_invite_access', 'direct', null],
    default: null,
  },
  // Date the user joined
  joinDate: {
    type: Date,
    default: Date.now,
  },

  // 🎮 GAMIFIED ONBOARDING EXTENSIONS
  
  // Onboarding Progress Tracking
  onboardingProgress: {
    isCompleted: { type: Boolean, default: false },
    currentStep: { type: Number, default: 0 },
    stepsCompleted: { type: [Number], default: [] },
    startedAt: { type: Date, default: null },
    completedAt: { type: Date, default: null },
    totalSteps: { type: Number, default: 7 }, // Total onboarding steps
  },
  
  // Extended Profile Information
  profile: {
    age: { type: Number, min: 13, max: 120 },
    gender: { 
      type: String, 
      enum: ['male', 'female', 'other', 'prefer_not_to_say', null],
      default: null 
    },
    weight: { type: Number, min: 20, max: 500 }, // in kg
    height: { type: Number, min: 100, max: 250 }, // in cm
    avatar: { type: String, default: 'default_user.png' },
    bio: { type: String, maxlength: 200 },
    profilePicture: { type: String, default: null },
    phoneNumber: { type: String, default: null },
  },
  
  // Fitness Goals (Multi-select)
  fitnessGoals: [{
    type: String,
    enum: ['muscle_gain', 'fat_loss', 'endurance', 'flexibility', 'strength', 'general_fitness', 'weight_maintenance', 'muscle', 'performance', null]
  }],
  
  // Diet Preferences
  dietPreferences: {
    type: { 
      type: String, 
      enum: ['vegetarian', 'non_vegetarian', 'vegan', 'keto', 'paleo', 'mediterranean', 'other', 'flexible', null],
      default: null 
    },
    allergies: [String], // Common allergies: nuts, dairy, gluten, etc.
    dailyMeals: { type: Number, min: 1, max: 8, default: 3 },
    waterIntake: { type: Number, default: 8 }, // glasses per day
    restrictions: [String], // diabetes, hypertension, etc.
  },
  
  // Workout Habits & Preferences
  workoutHabits: {
    preferredTime: { 
      type: String, 
      enum: ['early_morning', 'morning', 'afternoon', 'evening', 'night', 'flexible', null],
      default: null 
    },
    favoriteExercises: [{ 
      type: String,
      enum: ['cardio', 'weight_training', 'yoga', 'pilates', 'swimming', 'cycling', 'running', 'crossfit', 'martial_arts', 'dance', 'sports', null]
    }],
    currentActivityLevel: { 
      type: String, 
      enum: ['sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extremely_active', null],
      default: null 
    },
    workoutsPerWeek: { type: Number, min: 0, max: 14, default: 0 },
    sessionDuration: { type: Number, default: 60 }, // minutes
    hasInjuries: { type: Boolean, default: false },
    injuryDetails: { type: String, default: null },
  },
  
  // 🎮 Gamification System
  gamification: {
    totalXP: { type: Number, default: 0 },
    level: { type: Number, default: 1 },
    
    // Badge System
    badges: [{
      id: { type: String, required: true }, // badge identifier
      name: { type: String, required: true }, // display name
      description: { type: String, required: true },
      category: { 
        type: String, 
        enum: ['starter', 'milestone', 'special', 'achievement'],
        required: true 
      },
      iconUrl: { type: String, default: null },
      unlockedAt: { type: Date, required: true },
      xpAwarded: { type: Number, default: 0 },
    }],
    
    // Streaks & Engagement
    streaks: {
      current: { type: Number, default: 0 }, // current login streak
      longest: { type: Number, default: 0 }, // longest streak achieved
      lastLoginDate: { type: Date, default: null },
    },
    
    // Achievement Progress
    achievements: {
      profileCompletion: { type: Number, default: 0 }, // percentage
      onboardingProgress: { type: Number, default: 0 }, // percentage
      firstWorkoutLogged: { type: Boolean, default: false },
      firstGoalSet: { type: Boolean, default: false },
    }
  },

  // 🏆 First Challenge System
  firstChallenge: {
    isAccepted: { type: Boolean, default: false },
    type: { 
      type: String,
      enum: ['7_day_checkin', 'first_workout', 'meal_rhythm', 'profile_photo', 'goal_setting', null],
      default: null
    },
    startDate: { type: Date, default: null },
    endDate: { type: Date, default: null },
    progress: { type: Number, default: 0 }, // 0-100
    isCompleted: { type: Boolean, default: false },
    completedAt: { type: Date, default: null },
  },

  // 📱 Device & Preferences
  preferences: {
    theme: { type: String, enum: ['light', 'dark', 'system'], default: 'system' },
    language: { type: String, default: 'en' },
    notifications: {
      workout: { type: Boolean, default: true },
      achievements: { type: Boolean, default: true },
      social: { type: Boolean, default: true },
      marketing: { type: Boolean, default: false },
    },
    units: {
      weight: { type: String, enum: ['kg', 'lbs'], default: 'kg' },
      height: { type: String, enum: ['cm', 'ft'], default: 'cm' },
      distance: { type: String, enum: ['km', 'miles'], default: 'km' },
    }
  },

  hasCompletedOnboarding: {
    type: Boolean,
    default: false,
    required: function() {
      return this.role === 'gym_member';
    }
  },
  // Trainer/owner custom plan overrides
  customMealPlan: { type: Object, default: null },
  customWorkoutPlan: { type: Object, default: null },
}, { timestamps: true });

userSchema.index({ gymId: 1, role: 1 });

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Method to compare password
userSchema.methods.comparePassword = async function(candidatePassword) {
  const isMatch = await bcrypt.compare(candidatePassword, this.password);
  if (!isMatch) {
    console.warn('⚠️ Password mismatch for user:', this.email);
  }
  return isMatch;
};

userSchema.post('save', function(error, doc, next) {
  if (error) {
    console.error('❌ User schema validation error:', error);
  }
  next(error);
});

module.exports = mongoose.model('User', userSchema);
