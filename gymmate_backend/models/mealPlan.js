const mongoose = require('mongoose');

const MealSchema = new mongoose.Schema({
  name: { type: String, required: true },
  quantity: { type: String, required: true },
  macros: {
    protein: { type: Number, required: true },
    carbs: { type: Number, required: true },
    fats: { type: Number, required: true }
  },
  time: { type: String, required: true }
});

const MealPlanSchema = new mongoose.Schema({
  goal: { type: String, required: true, enum: ['muscle_gain', 'fat_loss', 'endurance', 'general_fitness', 'strength', 'performance'] },
  dietType: { type: String, required: true, enum: ['flexible', 'vegetarian', 'non_vegetarian', 'keto', 'vegan', 'high_protein', 'low_carb'] },
  bmiCategory: { type: String, required: true, enum: ['underweight', 'normal', 'overweight', 'obese'] },
  day: { type: String, required: true, enum: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'] },
  meals: [MealSchema]
});

module.exports = mongoose.model('MealPlan', MealPlanSchema);
