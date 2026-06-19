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

const MealPlanTemplateSchema = new mongoose.Schema({
  name: { type: String, required: true, unique: true },
  goal: {
    type: String,
    enum: ['lose_fat', 'build_muscle', 'get_fit', 'maintain'],
    required: true,
  },
  dietPref: {
    type: String,
    enum: ['none', 'vegetarian', 'vegan', 'keto', 'high_protein'],
    required: true,
  },
  baseCalories: { type: Number, default: 2000 },
  description: { type: String },
  macros: {
    proteinPct: { type: Number },
    carbsPct: { type: Number },
    fatPct: { type: Number },
  },
  days: [DaySchema],
}, { timestamps: true });

module.exports = mongoose.model('MealPlanTemplate', MealPlanTemplateSchema);
