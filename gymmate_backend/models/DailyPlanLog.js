const mongoose = require('mongoose');

const dailyPlanLogSchema = new mongoose.Schema(
  {
    memberId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    date: {
      type: String,
      required: true,
    },
    loggedMealItems: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    loggedWorkoutItems: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    water: {
      type: Number,
      default: 0,
      min: 0,
    },
    steps: {
      type: Number,
      default: 0,
      min: 0,
    },
    caloriesLogged: {
      type: Number,
      default: 0,
      min: 0,
    },
    proteinLogged: {
      type: Number,
      default: 0,
      min: 0,
    },
    carbsLogged: {
      type: Number,
      default: 0,
      min: 0,
    },
    fatLogged: {
      type: Number,
      default: 0,
      min: 0,
    },
    completionScore: {
      type: Number,
      default: 0,
      min: 0,
      max: 1,
    },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true },
);

dailyPlanLogSchema.index({ memberId: 1, date: 1 }, { unique: true });
dailyPlanLogSchema.index({ gymId: 1, date: 1 });

module.exports = mongoose.model('DailyPlanLog', dailyPlanLogSchema);
