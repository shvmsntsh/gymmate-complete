const mongoose = require('mongoose');

const ExerciseSchema = new mongoose.Schema({
  name: { type: String, required: true },
  sets: { type: Number, required: true },
  reps: { type: String, required: true },
  restSeconds: { type: Number, required: true },
  notes: { type: String },
}, { _id: false });

const WorkoutTypeSchema = new mongoose.Schema({
  id: { type: String, required: true },
  name: { type: String, required: true },
  exercises: [ExerciseSchema],
}, { _id: false });

const WeekProgressionSchema = new mongoose.Schema({
  weekNumber: { type: Number },
  focus: { type: String },
  note: { type: String },
}, { _id: false });

const WorkoutPlanTemplateSchema = new mongoose.Schema({
  name: { type: String, required: true, unique: true },
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
  description: { type: String },
  durationWeeks: { type: Number, default: 4 },
  workouts: [WorkoutTypeSchema],
  schedules: { type: Map, of: [String] },
  weeklyProgression: [WeekProgressionSchema],
}, { timestamps: true });

module.exports = mongoose.model('WorkoutPlanTemplate', WorkoutPlanTemplateSchema);
