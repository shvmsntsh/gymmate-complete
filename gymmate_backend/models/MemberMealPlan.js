const mongoose = require('mongoose');

const FoodItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  portion: { type: String, required: true },
  caloriesKcal: { type: Number, required: true },
  proteinG: { type: Number, required: true },
  carbsG: { type: Number, required: true },
  fatG: { type: Number, required: true },
}, { _id: false });

const MealSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['breakfast', 'mid_morning', 'lunch', 'pre_workout', 'dinner'],
    required: true,
  },
  items: [FoodItemSchema],
}, { _id: false });

const DaySchema = new mongoose.Schema({
  dayNumber: { type: Number },
  dayName: { type: String },
  meals: [MealSchema],
}, { _id: false });

const MemberMealPlanSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  gymId: { type: mongoose.Schema.Types.ObjectId },
  templateId: { type: mongoose.Schema.Types.ObjectId },
  isModified: { type: Boolean, default: false },
  modifiedBy: { type: mongoose.Schema.Types.ObjectId },
  modifiedAt: { type: Date },
  assignedAt: { type: Date, default: Date.now },
  goal: { type: String },
  dietPref: { type: String },
  calorieBracket: { type: Number },
  portionScale: { type: Number },
  dailyCalories: { type: Number },
  macros: {
    proteinG: { type: Number },
    carbsG: { type: Number },
    fatG: { type: Number },
  },
  days: [DaySchema],
}, { timestamps: true });

module.exports = mongoose.model('MemberMealPlan', MemberMealPlanSchema);
