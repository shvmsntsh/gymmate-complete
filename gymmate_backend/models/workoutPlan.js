const mongoose = require('mongoose');

const ExerciseSchema = new mongoose.Schema({
  name: { type: String, required: true },
  sets: { type: Number, required: true },
  reps: { type: Number, required: true },
  muscleGroup: { type: String, required: true }
});

const WorkoutPlanSchema = new mongoose.Schema({
  goal: { type: String, required: true, enum: ['muscle_gain', 'fat_loss', 'endurance', 'general_fitness', 'strength', 'performance'] },
  workoutSplit: { type: String, required: true, enum: ['PPL', 'Bro Split', 'Full Body'] },
  bmiCategory: { type: String, required: true, enum: ['underweight', 'normal', 'overweight', 'obese'] },
  day: { type: String, required: true, enum: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'] },
  exercises: [ExerciseSchema]
});

module.exports = mongoose.model('WorkoutPlan', WorkoutPlanSchema);
