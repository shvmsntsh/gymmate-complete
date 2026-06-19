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

const MemberWorkoutPlanSchema = new mongoose.Schema({
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
  fitnessLevel: { type: String },
  daysPerWeek: { type: Number },
  workouts: [WorkoutTypeSchema],
  schedules: { type: Map, of: [String] },
  weeklyProgression: [WeekProgressionSchema],
}, { timestamps: true });

module.exports = mongoose.model('MemberWorkoutPlan', MemberWorkoutPlanSchema);
