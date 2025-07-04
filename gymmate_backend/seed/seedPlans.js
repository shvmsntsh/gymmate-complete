const path = require('path');
const mongoose = require('mongoose');
const MealPlan = require(path.join(__dirname, '../models/mealPlan'));
const WorkoutPlan = require(path.join(__dirname, '../models/workoutPlan'));
const mealPlans = require(path.join(__dirname, 'seed_mealPlans.json'));
const workoutPlans = require(path.join(__dirname, 'seed_workoutPlans.json'));

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/gymmate';

async function seed() {
  await mongoose.connect(MONGO_URI);
  console.log('Connected to MongoDB');

  await MealPlan.deleteMany({});
  await WorkoutPlan.deleteMany({});

  await MealPlan.insertMany(mealPlans);
  await WorkoutPlan.insertMany(workoutPlans);

  console.log('Seeded mealPlans and workoutPlans!');
  await mongoose.disconnect();
}

seed().catch(e => { console.error(e); process.exit(1); });
