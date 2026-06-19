require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const WorkoutPlanTemplate = require('../models/WorkoutPlanTemplate');
const MealPlanTemplate = require('../models/MealPlanTemplate');

const URI = process.env.MONGODB_URI;
if (!URI) { console.error('MONGODB_URI not set'); process.exit(1); }

// ─── helpers ───────────────────────────────────────────────────────────────
const DAYS = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
const day  = (n, meals) => ({ dayNumber: n, dayName: DAYS[n-1], meals });
const B  = items => ({ type: 'breakfast',   items });
const MM = items => ({ type: 'mid_morning', items });
const L  = items => ({ type: 'lunch',       items });
const PW = items => ({ type: 'pre_workout', items });
const DN = items => ({ type: 'dinner',      items });
const f  = (name, portion, kcal, p, c, fat) =>
  ({ name, portion, caloriesKcal: kcal, proteinG: p, carbsG: c, fatG: fat });

// ─── WORKOUT TEMPLATES (12) ────────────────────────────────────────────────
const WORKOUT_TEMPLATES = [
  // ── LOSE FAT ──────────────────────────────────────────────────────────────
  {
    name: 'Full Body Fat Loss - Beginner',
    goal: 'lose_fat', fitnessLevel: 'beginner',
    description: 'Three full-body sessions per week using compound movements and bodyweight cardio to burn fat while preserving muscle.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Full Body Strength', exercises: [
        { name:'Goblet Squat',              sets:3, reps:'12-15',       restSeconds:60,  notes:'Keep chest up, knees over toes' },
        { name:'Push-up',                   sets:3, reps:'8-12',        restSeconds:60,  notes:'Knee push-up if needed' },
        { name:'Dumbbell Bent-over Row',    sets:3, reps:'12-15',       restSeconds:60,  notes:'Squeeze shoulder blades' },
        { name:'Glute Bridge',              sets:3, reps:'15-20',       restSeconds:45,  notes:'Drive hips up, squeeze glutes at top' },
        { name:'Plank',                     sets:3, reps:'30-45s',      restSeconds:45,  notes:'Keep hips level' },
        { name:'Jumping Jacks',             sets:3, reps:'30s',         restSeconds:30,  notes:'Cardio finisher burst' },
      ]},
      { id:'B', name:'Day B – Full Body Circuit', exercises: [
        { name:'Romanian Deadlift (DBs)',   sets:3, reps:'12-15',       restSeconds:60,  notes:'Back flat, hinge at hips' },
        { name:'Incline Push-up',           sets:3, reps:'10-15',       restSeconds:60,  notes:'Use a bench or step' },
        { name:'Lat Pulldown (Machine)',    sets:3, reps:'12-15',       restSeconds:60,  notes:'Pull to upper chest' },
        { name:'Reverse Lunge',             sets:3, reps:'10 each leg', restSeconds:60,  notes:'Keep front knee stable' },
        { name:'Mountain Climbers',         sets:3, reps:'20 each side',restSeconds:30,  notes:'Hips stay down' },
        { name:'High Knees',               sets:3, reps:'30s',         restSeconds:30,  notes:'Drive knees to chest' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','A','rest','rest']],['4',['A','rest','B','rest','A','rest','B']],['5',['A','B','rest','A','B','rest','rest']],['6',['A','B','A','rest','B','A','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Form & Technique',    note:'Light weight, perfect every rep' },
      { weekNumber:2, focus:'Building Volume',      note:'Add one set to key exercises' },
      { weekNumber:3, focus:'Progressive Overload', note:'Increase weight 5% or add 2 reps' },
      { weekNumber:4, focus:'Peak Effort',          note:'Push intensity, recover next week' },
    ],
  },
  {
    name: 'HIIT Shred - Intermediate',
    goal: 'lose_fat', fitnessLevel: 'intermediate',
    description: 'Upper/Lower split with dedicated HIIT sessions to maximise fat burn and preserve lean muscle.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Lower Strength', exercises: [
        { name:'Barbell Back Squat',        sets:4, reps:'8-10',        restSeconds:90,  notes:'Full depth, brace core' },
        { name:'Romanian Deadlift',         sets:4, reps:'10-12',       restSeconds:90,  notes:'Controlled eccentric' },
        { name:'Leg Press',                 sets:3, reps:'12-15',       restSeconds:75,  notes:'Full range of motion' },
        { name:'Walking Lunges',            sets:3, reps:'12 each leg', restSeconds:60,  notes:'Hold dumbbells' },
        { name:'Standing Calf Raise',       sets:4, reps:'15-20',       restSeconds:45,  notes:'Full stretch at bottom' },
      ]},
      { id:'B', name:'Day B – Upper Strength', exercises: [
        { name:'Barbell Bench Press',       sets:4, reps:'8-10',        restSeconds:90,  notes:'Controlled descent' },
        { name:'Barbell Row',               sets:4, reps:'8-10',        restSeconds:90,  notes:'Drive elbows back' },
        { name:'Dumbbell Shoulder Press',   sets:3, reps:'10-12',       restSeconds:75,  notes:'Don\'t flare elbows' },
        { name:'Lat Pulldown',              sets:3, reps:'10-12',       restSeconds:75,  notes:'Pull to collarbone' },
        { name:'Dumbbell Curl',             sets:3, reps:'12-15',       restSeconds:60,  notes:'Supinate at top' },
        { name:'Tricep Pushdown',           sets:3, reps:'12-15',       restSeconds:60,  notes:'Lock elbows at sides' },
      ]},
      { id:'C', name:'Day C – HIIT Cardio', exercises: [
        { name:'Burpees',                   sets:4, reps:'10',          restSeconds:40,  notes:'20s on, 40s off' },
        { name:'Box Jumps',                 sets:4, reps:'8',           restSeconds:40,  notes:'Soft landing, step down' },
        { name:'Kettlebell Swings',         sets:4, reps:'15',          restSeconds:40,  notes:'Hip hinge power' },
        { name:'Jump Rope',                 sets:4, reps:'45s',         restSeconds:30,  notes:'Double unders if possible' },
        { name:'Treadmill Sprint Intervals',sets:6, reps:'20s on / 40s walk', restSeconds:0, notes:'Max effort on sprints' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','C','rest','rest']],['4',['A','C','rest','B','rest','C','rest']],['5',['A','B','C','rest','A','C','rest']],['6',['A','B','C','rest','A','B','C']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Aerobic Base',  note:'HIIT at 70% effort, build capacity' },
      { weekNumber:2, focus:'Intensity Up',  note:'Push HIIT to 80%, add sets on strength' },
      { weekNumber:3, focus:'Peak Burn',     note:'90% HIIT, heavier on strength days' },
      { weekNumber:4, focus:'Final Push',    note:'Max intensity week, deload after' },
    ],
  },
  {
    name: 'Advanced Cut Circuit - Advanced',
    goal: 'lose_fat', fitnessLevel: 'advanced',
    description: 'High-frequency PPL combined with metabolic conditioning for aggressive fat loss while maintaining advanced strength.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Push Strength', exercises: [
        { name:'Barbell Bench Press',       sets:5, reps:'5',           restSeconds:120, notes:'85%+ of 1RM' },
        { name:'Incline Dumbbell Press',    sets:4, reps:'8-10',        restSeconds:90,  notes:'Stretch chest at bottom' },
        { name:'Overhead Press',            sets:4, reps:'8',           restSeconds:90,  notes:'Strict, no leg drive' },
        { name:'Cable Lateral Raise',       sets:3, reps:'15-20',       restSeconds:45,  notes:'Light, constant tension' },
        { name:'Weighted Tricep Dip',       sets:4, reps:'10-12',       restSeconds:60,  notes:'Lean forward slightly' },
      ]},
      { id:'B', name:'Day B – Pull Strength', exercises: [
        { name:'Deadlift',                  sets:4, reps:'5',           restSeconds:120, notes:'Max effort, perfect form' },
        { name:'Weighted Pull-up',          sets:4, reps:'6-8',         restSeconds:90,  notes:'Full hang at bottom' },
        { name:'Barbell Row',               sets:4, reps:'6-8',         restSeconds:90,  notes:'Chest to bar' },
        { name:'Seated Cable Row',          sets:3, reps:'12',          restSeconds:60,  notes:'Drive elbows behind torso' },
        { name:'Face Pull',                 sets:4, reps:'15-20',       restSeconds:45,  notes:'External rotation at end' },
        { name:'Hammer Curl',               sets:3, reps:'12',          restSeconds:45,  notes:'Neutral grip, controlled' },
      ]},
      { id:'C', name:'Day C – Legs Strength', exercises: [
        { name:'Barbell Back Squat',        sets:5, reps:'5',           restSeconds:120, notes:'Below parallel, brace hard' },
        { name:'Romanian Deadlift',         sets:4, reps:'8-10',        restSeconds:90,  notes:'Bar close to legs' },
        { name:'Bulgarian Split Squat',     sets:3, reps:'10 each',     restSeconds:90,  notes:'Dumbbell or barbell' },
        { name:'Leg Curl (Machine)',         sets:4, reps:'12-15',       restSeconds:60,  notes:'Slow eccentric' },
        { name:'Standing Calf Raise',       sets:5, reps:'15-20',       restSeconds:45,  notes:'Full range' },
      ]},
      { id:'D', name:'Day D – Metabolic Conditioning', exercises: [
        { name:'Assault Bike',              sets:5, reps:'1 min max effort', restSeconds:60, notes:'Track calories, all out' },
        { name:'Barbell Complex (6 moves)', sets:4, reps:'6 each',      restSeconds:90,  notes:'DL→Row→Clean→Front Squat→Press→Back Squat' },
        { name:'Battle Ropes',              sets:4, reps:'30s',         restSeconds:30,  notes:'Alternating waves' },
        { name:'Sled Push',                 sets:4, reps:'20m',         restSeconds:60,  notes:'Moderate load, max speed' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','C','rest','rest']],['4',['A','B','rest','C','D','rest','rest']],['5',['A','B','C','rest','D','A','rest']],['6',['A','B','C','D','A','B','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Technique & Volume',  note:'Heavy but controlled; establish baselines' },
      { weekNumber:2, focus:'Volume Up',           note:'Add one set to compound lifts' },
      { weekNumber:3, focus:'Intensity Peak',      note:'Load +5%, push conditioning hard' },
      { weekNumber:4, focus:'Deload & Assess',     note:'60% volume; measure body composition' },
    ],
  },
  // ── BUILD MUSCLE ──────────────────────────────────────────────────────────
  {
    name: 'Hypertrophy Foundation - Beginner',
    goal: 'build_muscle', fitnessLevel: 'beginner',
    description: 'Full-body 3-day program covering all major muscle groups for beginners focused on building lean mass.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Push Pattern', exercises: [
        { name:'Dumbbell Bench Press',      sets:3, reps:'10-12',       restSeconds:75,  notes:'Control the weight down' },
        { name:'Dumbbell Shoulder Press',   sets:3, reps:'10-12',       restSeconds:75,  notes:'Press to lockout' },
        { name:'Push-up',                   sets:3, reps:'max',         restSeconds:60,  notes:'Progress to weighted' },
        { name:'Goblet Squat',              sets:3, reps:'12-15',       restSeconds:75,  notes:'Depth over load' },
        { name:'Tricep Overhead Extension', sets:3, reps:'12-15',       restSeconds:60,  notes:'Elbow stays still' },
        { name:'Calf Raise',                sets:3, reps:'20',          restSeconds:45,  notes:'Full stretch at bottom' },
      ]},
      { id:'B', name:'Day B – Pull Pattern', exercises: [
        { name:'Lat Pulldown',              sets:3, reps:'10-12',       restSeconds:75,  notes:'Wide grip, full stretch' },
        { name:'Seated Cable Row',          sets:3, reps:'10-12',       restSeconds:75,  notes:'Tall posture' },
        { name:'Dumbbell Bicep Curl',       sets:3, reps:'12-15',       restSeconds:60,  notes:'Full range' },
        { name:'Romanian Deadlift (DBs)',   sets:3, reps:'12',          restSeconds:75,  notes:'Feel the hamstring stretch' },
        { name:'Glute Bridge',              sets:3, reps:'15-20',       restSeconds:60,  notes:'Pause at top' },
        { name:'Face Pull',                 sets:3, reps:'15',          restSeconds:45,  notes:'Shoulder health' },
      ]},
      { id:'C', name:'Day C – Full Body Hypertrophy', exercises: [
        { name:'Leg Press',                 sets:4, reps:'12-15',       restSeconds:75,  notes:'Drive through heels' },
        { name:'Incline Dumbbell Press',    sets:3, reps:'10-12',       restSeconds:75,  notes:'Upper chest focus' },
        { name:'Dumbbell Row',              sets:3, reps:'12 each',     restSeconds:60,  notes:'Elbow close to body' },
        { name:'Lateral Raise',             sets:3, reps:'15',          restSeconds:45,  notes:'Light weight, full arc' },
        { name:'Leg Curl (Machine)',         sets:3, reps:'12-15',       restSeconds:60,  notes:'Hamstring contraction' },
        { name:'Plank',                     sets:3, reps:'30-45s',      restSeconds:45,  notes:'Core stays tight' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','C','rest','rest']],['4',['A','B','rest','C','A','rest','rest']],['5',['A','B','C','rest','A','B','rest']],['6',['A','B','C','rest','A','B','C']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Mind-Muscle Connection', note:'Feel each rep, light weights' },
      { weekNumber:2, focus:'Add Sets',               note:'Go from 3 to 4 sets on main lifts' },
      { weekNumber:3, focus:'Add Load',               note:'Increase dumbbell weight by 2-5 kg' },
      { weekNumber:4, focus:'Volume Peak',            note:'Highest total sets, push hard' },
    ],
  },
  {
    name: 'PPL Muscle Builder - Intermediate',
    goal: 'build_muscle', fitnessLevel: 'intermediate',
    description: 'Classic Push-Pull-Legs 6-day program with progressive overload for intermediate lifters to maximise hypertrophy.',
    durationWeeks: 4,
    workouts: [
      { id:'P', name:'Push Day', exercises: [
        { name:'Barbell Bench Press',       sets:4, reps:'6-8',         restSeconds:120, notes:'Primary strength movement' },
        { name:'Incline Dumbbell Press',    sets:4, reps:'8-10',        restSeconds:90,  notes:'Upper chest emphasis' },
        { name:'Overhead Barbell Press',    sets:3, reps:'8-10',        restSeconds:90,  notes:'Strict press' },
        { name:'Cable Lateral Raise',       sets:4, reps:'12-15',       restSeconds:45,  notes:'Mid-deltoid pump' },
        { name:'Skull Crushers (EZ bar)',   sets:3, reps:'10-12',       restSeconds:60,  notes:'Control at bottom' },
        { name:'Tricep Pushdown',           sets:3, reps:'15',          restSeconds:45,  notes:'Squeeze at lockout' },
      ]},
      { id:'L', name:'Pull Day', exercises: [
        { name:'Barbell Row',               sets:4, reps:'6-8',         restSeconds:120, notes:'Overhand grip, chest to bar' },
        { name:'Weighted Pull-up',          sets:4, reps:'6-8',         restSeconds:90,  notes:'Add belt weight' },
        { name:'Seated Cable Row',          sets:3, reps:'10-12',       restSeconds:75,  notes:'Full stretch forward' },
        { name:'Incline Dumbbell Curl',     sets:3, reps:'10-12',       restSeconds:60,  notes:'Full stretch' },
        { name:'Hammer Curl',               sets:3, reps:'12',          restSeconds:45,  notes:'Brachialis emphasis' },
        { name:'Face Pull',                 sets:4, reps:'15-20',       restSeconds:45,  notes:'Rear delt and external rotation' },
      ]},
      { id:'G', name:'Legs Day', exercises: [
        { name:'Barbell Back Squat',        sets:4, reps:'6-8',         restSeconds:120, notes:'Below parallel' },
        { name:'Romanian Deadlift',         sets:4, reps:'8-10',        restSeconds:90,  notes:'Bar drags down leg' },
        { name:'Leg Press',                 sets:3, reps:'10-12',       restSeconds:90,  notes:'High foot for glutes' },
        { name:'Leg Curl (Machine)',         sets:4, reps:'12-15',       restSeconds:60,  notes:'Slow eccentric' },
        { name:'Leg Extension',             sets:3, reps:'15-20',       restSeconds:45,  notes:'Quad isolation' },
        { name:'Standing Calf Raise',       sets:5, reps:'15-20',       restSeconds:45,  notes:'Full range' },
      ]},
    ],
    schedules: new Map([['3',['P','rest','L','rest','G','rest','rest']],['4',['P','L','rest','G','P','rest','rest']],['5',['P','L','G','rest','P','L','rest']],['6',['P','L','G','P','L','G','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Volume Foundation', note:'3 sets per exercise, moderate weight' },
      { weekNumber:2, focus:'Volume Increase',   note:'Add a set to each compound lift' },
      { weekNumber:3, focus:'Intensity Increase',note:'Load +5%, drop one set if needed' },
      { weekNumber:4, focus:'Peak & Deload',     note:'Max effort, then 50% volume next week' },
    ],
  },
  {
    name: 'Advanced Hypertrophy PPL - Advanced',
    goal: 'build_muscle', fitnessLevel: 'advanced',
    description: '6-day double PPL with periodised loading for advanced lifters ready to break plateaus.',
    durationWeeks: 4,
    workouts: [
      { id:'P1', name:'Push A – Strength', exercises: [
        { name:'Barbell Bench Press',       sets:5, reps:'4-5',         restSeconds:150, notes:'87.5%+ of 1RM' },
        { name:'Incline Barbell Press',     sets:4, reps:'6-8',         restSeconds:120, notes:'Tempo 3-0-1' },
        { name:'Overhead Press',            sets:4, reps:'6-8',         restSeconds:90,  notes:'Strict form' },
        { name:'Cable Lateral Raise',       sets:5, reps:'12-15',       restSeconds:45,  notes:'Drop set last set' },
        { name:'Close-Grip Bench Press',    sets:3, reps:'8',           restSeconds:75,  notes:'Tricep compound' },
        { name:'Overhead Tricep Extension', sets:3, reps:'12',          restSeconds:45,  notes:'Long head stretch' },
      ]},
      { id:'L1', name:'Pull A – Strength', exercises: [
        { name:'Deadlift',                  sets:4, reps:'4-5',         restSeconds:150, notes:'87.5%+ of 1RM' },
        { name:'Weighted Pull-up',          sets:5, reps:'5-6',         restSeconds:120, notes:'BW + 10-20 kg' },
        { name:'Pendlay Row',               sets:4, reps:'5-6',         restSeconds:120, notes:'Explosive pull from floor' },
        { name:'Single-Arm Cable Row',      sets:3, reps:'10',          restSeconds:60,  notes:'Full rotation' },
        { name:'Incline Curl',              sets:4, reps:'8-10',        restSeconds:60,  notes:'Full stretch at bottom' },
        { name:'Face Pull',                 sets:4, reps:'15-20',       restSeconds:45,  notes:'Shoulder health priority' },
      ]},
      { id:'G1', name:'Legs A – Strength', exercises: [
        { name:'Barbell Back Squat',        sets:5, reps:'4-5',         restSeconds:150, notes:'87.5%+ of 1RM' },
        { name:'Romanian Deadlift',         sets:4, reps:'8',           restSeconds:90,  notes:'Loaded with plates' },
        { name:'Bulgarian Split Squat',     sets:4, reps:'8 each',      restSeconds:90,  notes:'Drive front heel' },
        { name:'Leg Curl (Machine)',         sets:4, reps:'10-12',       restSeconds:60,  notes:'3s eccentric' },
        { name:'Seated Calf Raise',         sets:5, reps:'12-15',       restSeconds:45,  notes:'Slow and deep' },
      ]},
      { id:'P2', name:'Push B – Volume', exercises: [
        { name:'Incline Dumbbell Press',    sets:5, reps:'10-12',       restSeconds:75,  notes:'70% 1RM, higher reps' },
        { name:'Cable Crossover',           sets:4, reps:'15',          restSeconds:45,  notes:'Constant tension on pecs' },
        { name:'Arnold Press',              sets:4, reps:'12',          restSeconds:60,  notes:'Full rotation' },
        { name:'Machine Lateral Raise',     sets:4, reps:'15-20',       restSeconds:30,  notes:'Superset with rear delts' },
        { name:'Rope Pushdown',             sets:4, reps:'15-20',       restSeconds:30,  notes:'Superset with lateral raise' },
        { name:'Skull Crushers',            sets:3, reps:'12',          restSeconds:60,  notes:'EZ bar' },
      ]},
      { id:'L2', name:'Pull B – Volume', exercises: [
        { name:'Lat Pulldown (Wide)',        sets:5, reps:'10-12',       restSeconds:75,  notes:'Full stretch at top' },
        { name:'Chest-Supported Row',       sets:4, reps:'12',          restSeconds:75,  notes:'Chest on pad' },
        { name:'Cable Pullover',            sets:3, reps:'15',          restSeconds:45,  notes:'Lat stretch' },
        { name:'Reverse Cable Curl',        sets:3, reps:'15',          restSeconds:45,  notes:'Brachialis & forearm' },
        { name:'Spider Curl',               sets:3, reps:'12',          restSeconds:45,  notes:'Peak bicep contraction' },
        { name:'Rear Delt Flye',            sets:4, reps:'15',          restSeconds:30,  notes:'Supinate at end' },
      ]},
      { id:'G2', name:'Legs B – Volume', exercises: [
        { name:'Leg Press',                 sets:5, reps:'12-15',       restSeconds:90,  notes:'Multiple foot positions' },
        { name:'Hack Squat',                sets:4, reps:'10-12',       restSeconds:75,  notes:'Quad dominant' },
        { name:'Walking Lunge',             sets:3, reps:'15 each',     restSeconds:75,  notes:'Hold dumbbells' },
        { name:'Leg Extension',             sets:4, reps:'15-20',       restSeconds:45,  notes:'Drop set on last set' },
        { name:'Lying Leg Curl',            sets:4, reps:'12-15',       restSeconds:45,  notes:'Hamstring pump' },
        { name:'Smith Machine Calf Raise',  sets:6, reps:'15-20',       restSeconds:30,  notes:'Max range' },
      ]},
    ],
    schedules: new Map([['3',['P1','rest','L1','rest','G1','rest','rest']],['4',['P1','L1','rest','G1','P2','rest','rest']],['5',['P1','L1','G1','rest','P2','L2','rest']],['6',['P1','L1','G1','P2','L2','G2','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Adaptation',     note:'Learn the program structure' },
      { weekNumber:2, focus:'Volume Peak',    note:'Max sets at moderate load' },
      { weekNumber:3, focus:'Intensity Peak', note:'Reduce volume, load to 90%+' },
      { weekNumber:4, focus:'Deload',         note:'50% volume and intensity; reset' },
    ],
  },
  // ── GET FIT ───────────────────────────────────────────────────────────────
  {
    name: 'Total Body Fitness - Beginner',
    goal: 'get_fit', fitnessLevel: 'beginner',
    description: 'Balanced full-body program combining strength, cardio, and core work for beginners wanting overall fitness.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Strength & Conditioning', exercises: [
        { name:'Bodyweight Squat',          sets:3, reps:'15-20',       restSeconds:45,  notes:'Perfect form first' },
        { name:'Push-up',                   sets:3, reps:'8-12',        restSeconds:45,  notes:'Knee push-up if needed' },
        { name:'Dumbbell Row',              sets:3, reps:'12 each',     restSeconds:45,  notes:'Elbow to ceiling' },
        { name:'Glute Bridge',              sets:3, reps:'20',          restSeconds:30,  notes:'Squeeze glutes at top' },
        { name:'Step-up',                   sets:3, reps:'10 each',     restSeconds:45,  notes:'Use a 30cm box' },
        { name:'Brisk Walk (Treadmill)',    sets:1, reps:'10 min',      restSeconds:0,   notes:'Incline 3-5%, 5 kmph' },
      ]},
      { id:'B', name:'Day B – Cardio & Core', exercises: [
        { name:'Stationary Bike',           sets:1, reps:'15 min',      restSeconds:0,   notes:'Cadence > 70 rpm, moderate' },
        { name:'Plank',                     sets:3, reps:'20-30s',      restSeconds:30,  notes:'Build to 60s over 4 weeks' },
        { name:'Dead Bug',                  sets:3, reps:'8 each side', restSeconds:30,  notes:'Lower back stays flat' },
        { name:'Bird Dog',                  sets:3, reps:'10 each',     restSeconds:30,  notes:'Slow and controlled' },
        { name:'Superman Hold',             sets:3, reps:'30s',         restSeconds:30,  notes:'Lower back extension' },
        { name:'Cat-Cow Stretch',           sets:1, reps:'10 rounds',   restSeconds:0,   notes:'Cool-down mobility' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','A','rest','rest']],['4',['A','B','rest','A','B','rest','rest']],['5',['A','B','A','rest','B','A','rest']],['6',['A','B','A','B','A','B','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Getting Started',  note:'Low intensity, build the habit' },
      { weekNumber:2, focus:'Consistency',      note:'Add 5 min to each cardio session' },
      { weekNumber:3, focus:'Build Intensity',  note:'Increase weights by 10-15%' },
      { weekNumber:4, focus:'Challenge Week',   note:'Add circuits or extra cardio' },
    ],
  },
  {
    name: 'Athletic Performance - Intermediate',
    goal: 'get_fit', fitnessLevel: 'intermediate',
    description: 'Sport-inspired training combining strength, endurance, and agility for complete fitness.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Strength', exercises: [
        { name:'Barbell Squat',             sets:4, reps:'8',           restSeconds:90,  notes:'Athletic depth' },
        { name:'Weighted Push-up',          sets:4, reps:'12',          restSeconds:75,  notes:'Plate on back' },
        { name:'Inverted Row',              sets:4, reps:'12',          restSeconds:75,  notes:'Horizontal pull' },
        { name:'Overhead Dumbbell Press',   sets:3, reps:'10',          restSeconds:60,  notes:'Seated for stability' },
        { name:"Farmer's Walk",             sets:4, reps:'30m',         restSeconds:60,  notes:'Heavy DBs, tall posture' },
        { name:'Copenhagen Plank',          sets:3, reps:'20s each',    restSeconds:45,  notes:'Adductor strength' },
      ]},
      { id:'B', name:'Day B – Power & Agility', exercises: [
        { name:'Box Jump',                  sets:4, reps:'6',           restSeconds:60,  notes:'Max height, soft landing' },
        { name:'Medicine Ball Slam',        sets:4, reps:'10',          restSeconds:45,  notes:'Full body power' },
        { name:'Lateral Bounds',            sets:4, reps:'8 each',      restSeconds:45,  notes:'Stick the landing' },
        { name:'T-Drill Agility Run',       sets:5, reps:'1 run',       restSeconds:60,  notes:'Time yourself, target sub-10s' },
        { name:'Broad Jump',                sets:4, reps:'5',           restSeconds:60,  notes:'Max distance' },
        { name:'Tuck Jump',                 sets:3, reps:'8',           restSeconds:45,  notes:'Knees to chest' },
      ]},
      { id:'C', name:'Day C – Endurance & Core', exercises: [
        { name:'Rowing Ergometer',          sets:1, reps:'2000m',       restSeconds:0,   notes:'Target sub-8 min, rate 22-26' },
        { name:'Ab Wheel Rollout',          sets:3, reps:'8-12',        restSeconds:45,  notes:'From knees first' },
        { name:'Hanging Leg Raise',         sets:3, reps:'10-12',       restSeconds:45,  notes:'Control the swing' },
        { name:'Russian Twist (Weighted)',  sets:3, reps:'20',          restSeconds:30,  notes:'Hold plate or med ball' },
        { name:'Cable Wood Chop',           sets:3, reps:'12 each',     restSeconds:45,  notes:'Rotational power' },
        { name:'Hollow Body Hold',          sets:3, reps:'30s',         restSeconds:30,  notes:'Gymnastic core pattern' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','C','rest','rest']],['4',['A','B','rest','C','A','rest','rest']],['5',['A','B','C','rest','A','B','rest']],['6',['A','B','C','A','B','rest','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Movement Quality', note:'Nail technique on power movements' },
      { weekNumber:2, focus:'Volume Build',     note:'Add a set; track agility times' },
      { weekNumber:3, focus:'Speed & Intensity',note:'Beat last week\'s times, heavier strength' },
      { weekNumber:4, focus:'Competition Week', note:'Test your maxes and personal bests' },
    ],
  },
  {
    name: 'Functional Fitness Pro - Advanced',
    goal: 'get_fit', fitnessLevel: 'advanced',
    description: 'CrossFit-inspired high-intensity functional program for advanced athletes wanting peak all-round fitness.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Olympic Lifts & Strength', exercises: [
        { name:'Power Clean (Hang)',         sets:5, reps:'3',           restSeconds:120, notes:'Explosive hip drive' },
        { name:'Barbell Front Squat',       sets:4, reps:'5',           restSeconds:120, notes:'Elbows high' },
        { name:'Strict Press',              sets:4, reps:'5',           restSeconds:90,  notes:'No leg drive' },
        { name:'Weighted Pull-up',          sets:5, reps:'5',           restSeconds:90,  notes:'Add 10-15 kg belt' },
        { name:'Ring Dip',                  sets:4, reps:'8-10',        restSeconds:75,  notes:'Full lockout at top' },
      ]},
      { id:'B', name:'Day B – WOD (Cindy)', exercises: [
        { name:'AMRAP: Pull-up / Push-up / Squat (Cindy)', sets:1, reps:'20 min AMRAP', restSeconds:0, notes:'5/10/15; log total rounds' },
        { name:'GHD Sit-up',                sets:3, reps:'15',          restSeconds:30,  notes:'Full extension at bottom' },
        { name:'Back Extension (GHD)',      sets:3, reps:'15',          restSeconds:30,  notes:'Hamstrings active' },
      ]},
      { id:'C', name:'Day C – Gymnastics & Endurance', exercises: [
        { name:'Handstand Push-up',         sets:4, reps:'5-8',         restSeconds:90,  notes:'Kick up to wall' },
        { name:'Muscle-up (Ring or Bar)',   sets:4, reps:'3-5',         restSeconds:90,  notes:'Full transition' },
        { name:'L-Sit Hold (Parallettes)',  sets:4, reps:'20s',         restSeconds:45,  notes:'Legs parallel to ground' },
        { name:'Double Unders',             sets:5, reps:'50',          restSeconds:30,  notes:'Consistent rhythm' },
        { name:'400m Run',                  sets:4, reps:'1 lap',       restSeconds:90,  notes:'Near-max effort each' },
      ]},
      { id:'D', name:'Day D – Benchmark (Fran)', exercises: [
        { name:'Fran: Thrusters + Pull-ups', sets:1, reps:'21-15-9 For Time', restSeconds:0, notes:'Rx 43 kg; target sub-5 min' },
        { name:'Tempo Air Squat',           sets:3, reps:'10',          restSeconds:30,  notes:'3-1-1-0 tempo' },
        { name:'Banded Shoulder Distraction',sets:2, reps:'30s each',   restSeconds:0,   notes:'Mobility cool-down' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','C','rest','rest']],['4',['A','B','rest','C','D','rest','rest']],['5',['A','B','C','rest','D','A','rest']],['6',['A','B','C','D','A','B','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Benchmark Week',  note:'Test Fran and Cindy for baselines' },
      { weekNumber:2, focus:'Volume Up',       note:'Add a WOD, increase barbell loads' },
      { weekNumber:3, focus:'Max Intensity',   note:'95%+ every session' },
      { weekNumber:4, focus:'Retest Week',     note:'Redo benchmarks; measure improvement' },
    ],
  },
  // ── MAINTAIN ──────────────────────────────────────────────────────────────
  {
    name: 'Active Maintenance - Beginner',
    goal: 'maintain', fitnessLevel: 'beginner',
    description: 'Low-pressure full-body routine for beginners who want to stay active and healthy with 3 sessions per week.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Whole Body Move', exercises: [
        { name:'Bodyweight Squat',          sets:3, reps:'15',          restSeconds:45,  notes:'Controlled and steady' },
        { name:'Wall Push-up',              sets:3, reps:'15',          restSeconds:45,  notes:'Great for shoulder health' },
        { name:'Resistance Band Row',       sets:3, reps:'15',          restSeconds:45,  notes:'Squeeze shoulder blades' },
        { name:'Hip Hinge (Bodyweight)',    sets:3, reps:'15',          restSeconds:45,  notes:'Pattern for daily movement' },
        { name:'Brisk Walk',                sets:1, reps:'15 min',      restSeconds:0,   notes:'5-6 kmph' },
        { name:'Stretch Routine',           sets:1, reps:'5 min',       restSeconds:0,   notes:'Hip flexors, chest, hamstrings' },
      ]},
      { id:'B', name:'Day B – Mobility & Light Cardio', exercises: [
        { name:'Sun Salutation (Yoga)',     sets:3, reps:'5 rounds',    restSeconds:30,  notes:'Follow a video if needed' },
        { name:'Stationary Bike (Easy)',    sets:1, reps:'20 min',      restSeconds:0,   notes:'Conversational pace' },
        { name:'Foam Rolling',              sets:1, reps:'5 min',       restSeconds:0,   notes:'Quads, IT band, upper back' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','A','rest','rest']],['4',['A','B','rest','A','B','rest','rest']],['5',['A','B','A','rest','B','A','rest']],['6',['A','B','A','B','A','B','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Habit Formation', note:'Show up every session regardless of intensity' },
      { weekNumber:2, focus:'Consistency',     note:'Add 1-2 reps to each set' },
      { weekNumber:3, focus:'Slight Challenge',note:'Increase walk pace or bike resistance' },
      { weekNumber:4, focus:'Reassess',        note:'Ready to level up, or stay and maintain?' },
    ],
  },
  {
    name: 'Maintenance Strength - Intermediate',
    goal: 'maintain', fitnessLevel: 'intermediate',
    description: 'Upper/Lower split to preserve hard-earned muscle and strength without a full building cycle.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Upper Maintenance', exercises: [
        { name:'Barbell Bench Press',       sets:3, reps:'6-8',         restSeconds:90,  notes:'Maintain strength, don\'t max' },
        { name:'Barbell Row',               sets:3, reps:'6-8',         restSeconds:90,  notes:'Control the descent' },
        { name:'Overhead Press',            sets:3, reps:'8',           restSeconds:75,  notes:'Shoulder health focus' },
        { name:'Pull-up',                   sets:3, reps:'max',         restSeconds:75,  notes:'Stop 2 reps before failure' },
        { name:'Dumbbell Curl',             sets:2, reps:'12',          restSeconds:45,  notes:'Maintain arm size' },
        { name:'Tricep Pushdown',           sets:2, reps:'15',          restSeconds:45,  notes:'Pump work' },
      ]},
      { id:'B', name:'Day B – Lower Maintenance', exercises: [
        { name:'Barbell Squat',             sets:3, reps:'6-8',         restSeconds:90,  notes:'Moderate weight' },
        { name:'Romanian Deadlift',         sets:3, reps:'8-10',        restSeconds:90,  notes:'Preserve hip hinge pattern' },
        { name:'Leg Press',                 sets:3, reps:'12',          restSeconds:75,  notes:'Moderate load' },
        { name:'Leg Curl (Machine)',         sets:3, reps:'12',          restSeconds:60,  notes:'Hamstring maintenance' },
        { name:'Calf Raise',                sets:3, reps:'15-20',       restSeconds:45,  notes:'Full range' },
        { name:'Plank',                     sets:2, reps:'45s',         restSeconds:30,  notes:'Core stability' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','A','rest','rest']],['4',['A','B','rest','A','B','rest','rest']],['5',['A','B','A','rest','B','A','rest']],['6',['A','B','A','B','A','rest','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Set Baseline',      note:'Find comfortable maintenance loads' },
      { weekNumber:2, focus:'Consistency',       note:'Same loads, perfect execution' },
      { weekNumber:3, focus:'Optional Push',     note:'Add 2.5-5 kg if feeling strong' },
      { weekNumber:4, focus:'Active Recovery',   note:'Drop volume 20%, add mobility work' },
    ],
  },
  {
    name: 'Elite Maintenance - Advanced',
    goal: 'maintain', fitnessLevel: 'advanced',
    description: 'Autoregulated maintenance program for advanced lifters preserving strength and muscle through a calorie-neutral phase.',
    durationWeeks: 4,
    workouts: [
      { id:'A', name:'Day A – Heavy Strength', exercises: [
        { name:'Barbell Bench Press',       sets:4, reps:'4-6',         restSeconds:120, notes:'RPE 8, leave 2 reps in tank' },
        { name:'Deadlift',                  sets:3, reps:'4-5',         restSeconds:120, notes:'RPE 8, not max' },
        { name:'Barbell Row',               sets:4, reps:'5-6',         restSeconds:90,  notes:'Match bench press load' },
        { name:'Overhead Press',            sets:3, reps:'6',           restSeconds:90,  notes:'Strict form' },
        { name:'Weighted Pull-up',          sets:3, reps:'6',           restSeconds:75,  notes:'Belt or vest' },
      ]},
      { id:'B', name:'Day B – Hypertrophy & Conditioning', exercises: [
        { name:'Squat (Front or Back)',     sets:3, reps:'8-10',        restSeconds:90,  notes:'Moderate, full range' },
        { name:'Incline Dumbbell Press',    sets:3, reps:'10-12',       restSeconds:75,  notes:'Lighter than max' },
        { name:'Seated Row',                sets:3, reps:'10-12',       restSeconds:75,  notes:'Full stretch' },
        { name:'Bulgarian Split Squat',     sets:3, reps:'10 each',     restSeconds:75,  notes:'Unilateral balance' },
        { name:'Assault Bike Intervals',    sets:5, reps:'30s hard / 90s easy', restSeconds:0, notes:'Cardio maintenance' },
        { name:'Ab Complex',                sets:3, reps:'10-15',       restSeconds:30,  notes:'Hollow → Dead Bug → Plank' },
      ]},
    ],
    schedules: new Map([['3',['A','rest','B','rest','A','rest','rest']],['4',['A','B','rest','A','B','rest','rest']],['5',['A','B','A','rest','B','A','rest']],['6',['A','B','A','B','A','B','rest']]]),
    weeklyProgression: [
      { weekNumber:1, focus:'Load Calibration', note:'Find RPE 8 for each lift' },
      { weekNumber:2, focus:'Consistency',      note:'Same loads, full sessions' },
      { weekNumber:3, focus:'Small Increases',  note:'Add 2.5 kg if RPE dropped to 7' },
      { weekNumber:4, focus:'Deload',           note:'RPE 6 throughout; prioritise sleep' },
    ],
  },
];

// ─── MEAL TEMPLATES (20 = 4 goals × 5 diet prefs) ─────────────────────────
// All base at 2000 kcal/day. 7 days of Indian meals.
// Macros target per goal:
//   lose_fat:    35%P / 35%C / 30%F  (175g / 175g / 67g)
//   build_muscle:30%P / 45%C / 25%F  (150g / 225g / 56g)
//   get_fit:     25%P / 45%C / 30%F  (125g / 225g / 67g)
//   maintain:    25%P / 45%C / 30%F  (125g / 225g / 67g)

// ── Shared food building blocks ────────────────────────────────────────────
// Breakfast blocks
const oatsBreakfast      = [f('Rolled oats (dry)','50g',190,6,34,3.5),f('Low-fat milk','200ml',80,8,10,1),f('Banana','1 medium',90,1,23,0.3),f('Almonds','10 nuts',70,2.5,2.5,6)];
const eggWheatBreakfast  = [f('Whole eggs','3',210,18,1.5,15),f('Whole wheat roti','2',180,6,36,2),f('Mixed veg sabzi','100g',55,2,9,1.5),f('Black tea (no sugar)','1 cup',5,0.2,0.8,0)];
const dalChillaBreakfast = [f('Moong dal chilla','3 medium',210,12,30,3),f('Low-fat curd','150g',80,7,8,1.5),f('Green chutney','2 tbsp',20,0.5,3,0.3)];
const pohaBreakfast      = [f('Poha (cooked)','200g',240,5,50,3),f('Peanuts','20g',115,5,3.5,10),f('Low-fat milk','150ml',60,6,7.5,0.8),f('Seasonal fruit','100g',60,0.5,15,0.2)];
const idliBreakfast      = [f('Idli','4 medium',220,7,44,1),f('Sambar','200ml',90,5,14,2),f('Coconut chutney','2 tbsp',60,1,3,5)];
const upmaBreakfast      = [f('Semolina upma (cooked)','200g',260,7,42,6),f('Mixed vegetables','50g',25,1,5,0.2),f('Low-fat curd','100g',55,5,6,1)];
const paratheBreakfast   = [f('Whole wheat paratha','2',320,9,52,9),f('Low-fat curd','150g',80,7,8,1.5),f('Pickle','1 tsp',5,0.1,1,0.2)];

// Mid-morning blocks
const fruitNuts   = [f('Seasonal fruit','1 medium',80,0.5,21,0.3),f('Walnuts','5 halves',65,1.5,1.5,6.5)];
const fruitCurd   = [f('Apple','1 medium',80,0.4,21,0.2),f('Low-fat curd','100g',55,5,6,1)];
const sproutsSalad= [f('Moong sprouts','100g',30,3,5,0.2),f('Lemon juice','1 tbsp',4,0,1,0)];
const peanutFruit  = [f('Banana','1 small',70,0.9,18,0.2),f('Peanut butter','1 tbsp',95,4,3,8)];
const masalaChai   = [f('Masala chai (low-fat milk, no sugar)','1 cup',60,3,9,1.5),f('Roasted makhana','25g',85,3,18,0.2)];

// Lunch blocks – omnivore
const chickenRotiLunch  = [f('Chicken breast (cooked)','120g',198,37,0,4),f('Whole wheat roti','3',270,9,54,3),f('Toor dal','150ml',115,8,18,1),f('Salad (cucumber, tomato, onion)','100g',30,1,6,0.2)];
const chickenRiceLunch  = [f('Chicken breast (cooked)','120g',198,37,0,4),f('Brown rice (cooked)','180g',200,4,42,1.5),f('Rajma curry','150g',190,12,34,2),f('Salad','100g',30,1,6,0.2)];
const eggRotiLunch      = [f('Boiled eggs','3',210,18,1.5,15),f('Whole wheat roti','3',270,9,54,3),f('Mixed veg sabzi','150g',80,3,12,2),f('Buttermilk (low-fat)','200ml',40,3,5,0.5)];

// Lunch blocks – vegetarian
const paneerRotiLunch   = [f('Low-fat paneer','100g',180,22,3,9),f('Whole wheat roti','3',270,9,54,3),f('Dal tadka','200ml',155,11,24,2),f('Salad','100g',30,1,6,0.2)];
const paneerRiceLunch   = [f('Paneer curry (low-fat)','150g',265,28,8,13),f('Brown rice (cooked)','180g',200,4,42,1.5),f('Mixed veg sabzi','150g',80,3,12,2)];
const rajmaRotiLunch    = [f('Rajma curry','200g',254,16,46,2),f('Whole wheat roti','3',270,9,54,3),f('Low-fat curd','150g',80,7,8,1.5)];

// Lunch blocks – vegan
const dalRiceLunch      = [f('Toor dal','200ml',155,11,24,2),f('Brown rice (cooked)','200g',222,4.5,46,1.5),f('Mixed veg sabzi','150g',80,3,12,2),f('Salad','100g',30,1,6,0.2)];
const chanaRotiLunch    = [f('Chana masala','200g',328,18,54,5),f('Jowar roti','2',240,7,50,2),f('Raw salad','150g',45,1.5,9,0.3)];
const tofuRiceLunch     = [f('Tofu stir-fry','150g',113,12,4,6),f('Brown rice (cooked)','200g',222,4.5,46,1.5),f('Dal','150ml',115,8,18,1),f('Salad','100g',30,1,6,0.2)];

// Pre-workout blocks
const bananaCurd   = [f('Banana','1 medium',90,1,23,0.3),f('Low-fat curd','150g',80,7,8,1.5)];
const breadPeanut  = [f('Whole wheat bread','2 slices',160,6,30,2),f('Peanut butter','1 tbsp',95,4,3,8)];
const fruitProtein = [f('Banana','1 medium',90,1,23,0.3),f('Boiled egg','2',140,12,1,10)];
const dryFruits    = [f('Dates','4',110,1,29,0.2),f('Cashews','15g',85,2.8,5,6.7)];
const oatsBanana   = [f('Oats (cooked)','100g',70,2.5,12,1.5),f('Banana','1 small',70,0.9,18,0.2)];

// Dinner blocks – omnivore
const chickenSabziDinner= [f('Chicken breast (cooked)','120g',198,37,0,4),f('Whole wheat roti','3',270,9,54,3),f('Palak sabzi','150g',70,4,8,3),f('Low-fat curd','100g',55,5,6,1)];
const fishRotiDinner    = [f('Grilled fish (rohu/surmai)','150g',185,35,0,4),f('Whole wheat roti','2',180,6,36,2),f('Mixed veg sabzi','150g',80,3,12,2),f('Dal','150ml',115,8,18,1)];
const eggCurryDinner    = [f('Egg curry (3 eggs)','200g',310,21,8,22),f('Whole wheat roti','3',270,9,54,3),f('Salad','100g',30,1,6,0.2)];

// Dinner blocks – vegetarian
const paneerSabziDinner = [f('Low-fat paneer','100g',180,22,3,9),f('Whole wheat roti','3',270,9,54,3),f('Mixed dal','150ml',130,9,20,1.5),f('Low-fat curd','100g',55,5,6,1)];
const dalMakhniDinner   = [f('Dal makhni (light)','200g',230,13,35,5),f('Whole wheat roti','3',270,9,54,3),f('Salad','100g',30,1,6,0.2)];

// Dinner blocks – vegan
const chanaRiceDinner   = [f('Chana masala','200g',328,18,54,5),f('Brown rice (cooked)','150g',167,3.5,35,1),f('Salad','100g',30,1,6,0.2)];
const dalVegDinner      = [f('Moong dal','200ml',125,9,20,0.5),f('Jowar roti','3',360,10.5,75,3),f('Palak sabzi','150g',70,4,8,3)];

// Keto-specific blocks
const eggBaconBreakfastK   = [f('Whole eggs','3',210,18,1.5,15),f('Paneer (full-fat)','50g',133,9,1.7,10),f('Sautéed spinach with ghee','100g',65,3,4,4),f('Black coffee','1 cup',5,0.3,0.8,0)];
const avocadoEggBreakfastK = [f('Boiled eggs','3',210,18,1.5,15),f('Nuts mix (almonds + walnuts)','30g',187,5.5,5.5,16),f('Green tea','1 cup',3,0.3,0.5,0)];
const paneerKetoLunch      = [f('Paneer (full-fat)','150g',398,27,5,30),f('Palak cooked with ghee','200g',120,5,10,6),f('Salad with olive oil','150g',80,1.5,8,5)];
const chickenKetoLunch     = [f('Chicken thigh (cooked)','150g',250,28,0,15),f('Stir-fried vegetables with butter','200g',130,3,12,8),f('Paneer','50g',133,9,1.7,10)];
const eggKetoLunch         = [f('Scrambled eggs (4)','4',280,24,2,20),f('Paneer (full-fat)','50g',133,9,1.7,10),f('Sautéed mushrooms with butter','100g',65,2,4,5),f('Salad','100g',30,1,6,0.2)];
const paneerKetoDinner     = [f('Paneer tikka (full-fat)','150g',398,27,5,30),f('Stir-fried broccoli with ghee','150g',105,4,8,5),f('Cucumber raita (full-fat curd)','100g',80,4,5,5)];
const chickenKetoDinner    = [f('Grilled chicken thigh','150g',250,28,0,15),f('Sautéed palak with cream','150g',155,5,7,12),f('Mixed salad with olive oil','100g',55,1,5,4)];
const ketoMidMorning       = [f('Mixed nuts','30g',187,5.5,5.5,16),f('Paneer cube','50g',133,9,1.7,10)];
const ketoPreWorkout       = [f('Boiled eggs','2',140,12,1,10),f('Almonds','15g',88,3,3,7.5)];

// High-protein-specific blocks
const hpBreakfast1 = [f('Egg whites','6',102,21,1.2,0),f('Whole eggs','2',140,12,1,10),f('Whole wheat roti','2',180,6,36,2),f('Low-fat milk','200ml',80,8,10,1)];
const hpBreakfast2 = [f('Soya chunks (soaked and cooked)','50g dry',170,26,10,1),f('Whole wheat roti','2',180,6,36,2),f('Curd (low-fat)','150g',80,7,8,1.5),f('Black tea','1 cup',5,0.2,0.8,0)];
const hpMidMorning = [f('Low-fat cottage cheese (paneer)','100g',180,22,3,9),f('Seasonal fruit','1 medium',80,0.5,21,0.3)];
const hpLunch1     = [f('Chicken breast','150g',248,46,0,5),f('Brown rice (cooked)','150g',167,3.5,35,1),f('Toor dal','150ml',115,8,18,1),f('Salad','100g',30,1,6,0.2)];
const hpLunch2     = [f('Soya chunks curry','150g',255,39,15,1.5),f('Whole wheat roti','3',270,9,54,3),f('Mixed veg','100g',55,2,9,1.5)];
const hpPreWorkout = [f('Low-fat curd','200g',107,9.5,11,2),f('Banana','1 medium',90,1,23,0.3)];
const hpDinner1    = [f('Chicken breast','150g',248,46,0,5),f('Moong dal','200ml',125,9,20,0.5),f('Whole wheat roti','2',180,6,36,2),f('Palak sabzi','100g',47,3,5,2)];
const hpDinner2    = [f('Paneer (low-fat)','150g',270,33,4.5,13.5),f('Mixed dal','200ml',175,12,27,2),f('Jowar roti','2',240,7,50,2)];

// ── Build 7-day plan from day patterns ────────────────────────────────────
function make7Days(breakfast7, midMorning7, lunch7, preWorkout7, dinner7) {
  return Array.from({ length: 7 }, (_, i) => day(i+1, [
    B(breakfast7[i]),
    MM(midMorning7[i]),
    L(lunch7[i]),
    PW(preWorkout7[i]),
    DN(dinner7[i]),
  ]));
}

// Rotate arrays to make 7-day variety
function rot(arr) {
  return Array.from({ length: 7 }, (_, i) => arr[i % arr.length]);
}

const MEAL_TEMPLATES = [
  // ── LOSE FAT ──────────────────────────────────────────────────────────────
  {
    name: 'Fat Loss Plan – Omnivore',
    goal: 'lose_fat', dietPref: 'none', baseCalories: 2000,
    description: 'High-protein Indian omnivore plan in a moderate calorie deficit to maximise fat loss while preserving muscle.',
    macros: { proteinPct: 35, carbsPct: 35, fatPct: 30 },
    days: make7Days(
      rot([eggWheatBreakfast, oatsBreakfast, dalChillaBreakfast, eggWheatBreakfast, oatsBreakfast, pohaBreakfast, eggWheatBreakfast]),
      rot([fruitNuts, fruitCurd, sproutsSalad, fruitNuts, masalaChai, fruitCurd, sproutsSalad]),
      rot([chickenRotiLunch, chickenRiceLunch, eggRotiLunch, chickenRotiLunch, chickenRiceLunch, eggRotiLunch, chickenRotiLunch]),
      rot([bananaCurd, fruitProtein, bananaCurd, fruitProtein, dryFruits, bananaCurd, fruitProtein]),
      rot([chickenSabziDinner, fishRotiDinner, eggCurryDinner, chickenSabziDinner, fishRotiDinner, chickenSabziDinner, eggCurryDinner]),
    ),
  },
  {
    name: 'Fat Loss Plan – Vegetarian',
    goal: 'lose_fat', dietPref: 'vegetarian', baseCalories: 2000,
    description: 'High-protein vegetarian Indian plan with paneer, dal, and dairy to support fat loss.',
    macros: { proteinPct: 32, carbsPct: 38, fatPct: 30 },
    days: make7Days(
      rot([dalChillaBreakfast, oatsBreakfast, idliBreakfast, eggWheatBreakfast, pohaBreakfast, upmaBreakfast, dalChillaBreakfast]),
      rot([hpMidMorning, fruitCurd, sproutsSalad, hpMidMorning, masalaChai, fruitNuts, fruitCurd]),
      rot([paneerRotiLunch, rajmaRotiLunch, paneerRiceLunch, paneerRotiLunch, rajmaRotiLunch, paneerRiceLunch, paneerRotiLunch]),
      rot([bananaCurd, fruitCurd, oatsBanana, bananaCurd, dryFruits, fruitCurd, oatsBanana]),
      rot([paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner]),
    ),
  },
  {
    name: 'Fat Loss Plan – Vegan',
    goal: 'lose_fat', dietPref: 'vegan', baseCalories: 2000,
    description: 'Plant-based Indian fat loss plan using dal, tofu, soya, and whole grains.',
    macros: { proteinPct: 28, carbsPct: 42, fatPct: 30 },
    days: make7Days(
      rot([oatsBreakfast, dalChillaBreakfast, pohaBreakfast, upmaBreakfast, idliBreakfast, oatsBreakfast, dalChillaBreakfast]),
      rot([sproutsSalad, fruitNuts, fruitNuts, sproutsSalad, masalaChai, fruitNuts, sproutsSalad]),
      rot([dalRiceLunch, chanaRotiLunch, tofuRiceLunch, dalRiceLunch, chanaRotiLunch, tofuRiceLunch, dalRiceLunch]),
      rot([oatsBanana, dryFruits, peanutFruit, oatsBanana, dryFruits, peanutFruit, oatsBanana]),
      rot([chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner]),
    ),
  },
  {
    name: 'Fat Loss Plan – Keto',
    goal: 'lose_fat', dietPref: 'keto', baseCalories: 2000,
    description: 'Low-carb Indian keto plan with eggs, paneer, and healthy fats to trigger fat burning through ketosis.',
    macros: { proteinPct: 30, carbsPct: 10, fatPct: 60 },
    days: make7Days(
      rot([eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK]),
      rot([ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning]),
      rot([paneerKetoLunch, chickenKetoLunch, eggKetoLunch, paneerKetoLunch, chickenKetoLunch, eggKetoLunch, paneerKetoLunch]),
      rot([ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout]),
      rot([paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner]),
    ),
  },
  {
    name: 'Fat Loss Plan – High Protein',
    goal: 'lose_fat', dietPref: 'high_protein', baseCalories: 2000,
    description: 'Aggressive high-protein Indian plan targeting 40%+ protein to preserve muscle during a fat-loss phase.',
    macros: { proteinPct: 40, carbsPct: 30, fatPct: 30 },
    days: make7Days(
      rot([hpBreakfast1, hpBreakfast2, eggWheatBreakfast, hpBreakfast1, hpBreakfast2, oatsBreakfast, hpBreakfast1]),
      rot([hpMidMorning, hpMidMorning, fruitCurd, hpMidMorning, fruitNuts, hpMidMorning, fruitCurd]),
      rot([hpLunch1, hpLunch2, hpLunch1, hpLunch2, hpLunch1, hpLunch2, hpLunch1]),
      rot([hpPreWorkout, hpPreWorkout, fruitProtein, hpPreWorkout, hpPreWorkout, fruitProtein, hpPreWorkout]),
      rot([hpDinner1, hpDinner2, hpDinner1, hpDinner2, hpDinner1, hpDinner2, hpDinner1]),
    ),
  },
  // ── BUILD MUSCLE ──────────────────────────────────────────────────────────
  {
    name: 'Muscle Building Plan – Omnivore',
    goal: 'build_muscle', dietPref: 'none', baseCalories: 2000,
    description: 'Calorie-surplus Indian omnivore plan high in protein and carbs to fuel muscle growth and recovery.',
    macros: { proteinPct: 30, carbsPct: 45, fatPct: 25 },
    days: make7Days(
      rot([eggWheatBreakfast, oatsBreakfast, paratheBreakfast, eggWheatBreakfast, oatsBreakfast, idliBreakfast, paratheBreakfast]),
      rot([fruitNuts, peanutFruit, fruitCurd, peanutFruit, fruitNuts, masalaChai, peanutFruit]),
      rot([chickenRiceLunch, chickenRotiLunch, eggRotiLunch, chickenRiceLunch, chickenRotiLunch, eggRotiLunch, chickenRiceLunch]),
      rot([breadPeanut, bananaCurd, fruitProtein, bananaCurd, breadPeanut, fruitProtein, bananaCurd]),
      rot([chickenSabziDinner, eggCurryDinner, fishRotiDinner, chickenSabziDinner, eggCurryDinner, chickenSabziDinner, fishRotiDinner]),
    ),
  },
  {
    name: 'Muscle Building Plan – Vegetarian',
    goal: 'build_muscle', dietPref: 'vegetarian', baseCalories: 2000,
    description: 'Vegetarian Indian muscle-building plan with paneer, dairy, and complex carbs for anabolic support.',
    macros: { proteinPct: 28, carbsPct: 47, fatPct: 25 },
    days: make7Days(
      rot([eggWheatBreakfast, oatsBreakfast, idliBreakfast, paratheBreakfast, dalChillaBreakfast, upmaBreakfast, oatsBreakfast]),
      rot([hpMidMorning, peanutFruit, fruitCurd, hpMidMorning, masalaChai, peanutFruit, fruitNuts]),
      rot([paneerRiceLunch, rajmaRotiLunch, paneerRotiLunch, paneerRiceLunch, rajmaRotiLunch, paneerRotiLunch, paneerRiceLunch]),
      rot([bananaCurd, breadPeanut, bananaCurd, oatsBanana, bananaCurd, breadPeanut, bananaCurd]),
      rot([paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner]),
    ),
  },
  {
    name: 'Muscle Building Plan – Vegan',
    goal: 'build_muscle', dietPref: 'vegan', baseCalories: 2000,
    description: 'Plant-based Indian muscle-building plan using soya, tofu, legumes, and whole grains.',
    macros: { proteinPct: 26, carbsPct: 49, fatPct: 25 },
    days: make7Days(
      rot([oatsBreakfast, dalChillaBreakfast, idliBreakfast, pohaBreakfast, upmaBreakfast, oatsBreakfast, dalChillaBreakfast]),
      rot([hpMidMorning, peanutFruit, fruitNuts, sproutsSalad, peanutFruit, fruitNuts, sproutsSalad]),
      rot([hpLunch2, chanaRotiLunch, tofuRiceLunch, dalRiceLunch, hpLunch2, chanaRotiLunch, tofuRiceLunch]),
      rot([oatsBanana, peanutFruit, dryFruits, oatsBanana, peanutFruit, dryFruits, oatsBanana]),
      rot([chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner]),
    ),
  },
  {
    name: 'Muscle Building Plan – Keto',
    goal: 'build_muscle', dietPref: 'keto', baseCalories: 2000,
    description: 'Keto muscle-building plan with high protein and fat; minimal carbs timed around workouts.',
    macros: { proteinPct: 35, carbsPct: 10, fatPct: 55 },
    days: make7Days(
      rot([eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK]),
      rot([ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning]),
      rot([chickenKetoLunch, paneerKetoLunch, eggKetoLunch, chickenKetoLunch, paneerKetoLunch, eggKetoLunch, chickenKetoLunch]),
      rot([ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout]),
      rot([chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner]),
    ),
  },
  {
    name: 'Muscle Building Plan – High Protein',
    goal: 'build_muscle', dietPref: 'high_protein', baseCalories: 2000,
    description: 'Maximum-protein Indian muscle-building plan with surplus calories and multiple protein sources throughout the day.',
    macros: { proteinPct: 38, carbsPct: 38, fatPct: 24 },
    days: make7Days(
      rot([hpBreakfast1, hpBreakfast2, eggWheatBreakfast, hpBreakfast1, hpBreakfast2, oatsBreakfast, hpBreakfast1]),
      rot([hpMidMorning, hpMidMorning, peanutFruit, hpMidMorning, fruitNuts, hpMidMorning, peanutFruit]),
      rot([hpLunch1, hpLunch2, chickenRiceLunch, hpLunch1, hpLunch2, chickenRotiLunch, hpLunch1]),
      rot([hpPreWorkout, bananaCurd, hpPreWorkout, bananaCurd, hpPreWorkout, bananaCurd, hpPreWorkout]),
      rot([hpDinner1, hpDinner2, hpDinner1, hpDinner2, hpDinner1, hpDinner2, hpDinner1]),
    ),
  },
  // ── GET FIT ───────────────────────────────────────────────────────────────
  {
    name: 'Get Fit Plan – Omnivore',
    goal: 'get_fit', dietPref: 'none', baseCalories: 2000,
    description: 'Balanced Indian omnivore plan for overall fitness, providing energy for training and daily life.',
    macros: { proteinPct: 25, carbsPct: 45, fatPct: 30 },
    days: make7Days(
      rot([oatsBreakfast, eggWheatBreakfast, idliBreakfast, pohaBreakfast, upmaBreakfast, paratheBreakfast, oatsBreakfast]),
      rot([fruitNuts, fruitCurd, masalaChai, fruitNuts, sproutsSalad, fruitCurd, fruitNuts]),
      rot([chickenRotiLunch, eggRotiLunch, chickenRiceLunch, chickenRotiLunch, eggRotiLunch, chickenRiceLunch, chickenRotiLunch]),
      rot([bananaCurd, fruitProtein, bananaCurd, dryFruits, bananaCurd, fruitProtein, bananaCurd]),
      rot([chickenSabziDinner, fishRotiDinner, eggCurryDinner, chickenSabziDinner, fishRotiDinner, chickenSabziDinner, eggCurryDinner]),
    ),
  },
  {
    name: 'Get Fit Plan – Vegetarian',
    goal: 'get_fit', dietPref: 'vegetarian', baseCalories: 2000,
    description: 'Vegetarian Indian balanced plan for overall fitness with variety from dairy, legumes, and whole grains.',
    macros: { proteinPct: 23, carbsPct: 47, fatPct: 30 },
    days: make7Days(
      rot([idliBreakfast, pohaBreakfast, oatsBreakfast, upmaBreakfast, dalChillaBreakfast, paratheBreakfast, idliBreakfast]),
      rot([fruitCurd, masalaChai, fruitNuts, sproutsSalad, fruitCurd, fruitNuts, masalaChai]),
      rot([rajmaRotiLunch, paneerRotiLunch, paneerRiceLunch, rajmaRotiLunch, paneerRotiLunch, paneerRiceLunch, rajmaRotiLunch]),
      rot([bananaCurd, fruitCurd, oatsBanana, dryFruits, bananaCurd, fruitCurd, oatsBanana]),
      rot([dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner]),
    ),
  },
  {
    name: 'Get Fit Plan – Vegan',
    goal: 'get_fit', dietPref: 'vegan', baseCalories: 2000,
    description: 'Whole-food plant-based Indian plan for complete fitness, using seasonal produce, legumes, and whole grains.',
    macros: { proteinPct: 22, carbsPct: 48, fatPct: 30 },
    days: make7Days(
      rot([oatsBreakfast, idliBreakfast, pohaBreakfast, dalChillaBreakfast, upmaBreakfast, oatsBreakfast, idliBreakfast]),
      rot([fruitNuts, sproutsSalad, masalaChai, fruitNuts, sproutsSalad, peanutFruit, fruitNuts]),
      rot([dalRiceLunch, chanaRotiLunch, tofuRiceLunch, dalRiceLunch, chanaRotiLunch, tofuRiceLunch, dalRiceLunch]),
      rot([oatsBanana, peanutFruit, dryFruits, oatsBanana, peanutFruit, dryFruits, oatsBanana]),
      rot([dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner]),
    ),
  },
  {
    name: 'Get Fit Plan – Keto',
    goal: 'get_fit', dietPref: 'keto', baseCalories: 2000,
    description: 'Low-carb Indian keto plan for fitness enthusiasts seeking steady energy without carb crashes.',
    macros: { proteinPct: 28, carbsPct: 10, fatPct: 62 },
    days: make7Days(
      rot([eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK]),
      rot([ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning]),
      rot([paneerKetoLunch, chickenKetoLunch, eggKetoLunch, paneerKetoLunch, chickenKetoLunch, eggKetoLunch, paneerKetoLunch]),
      rot([ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout]),
      rot([chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner]),
    ),
  },
  {
    name: 'Get Fit Plan – High Protein',
    goal: 'get_fit', dietPref: 'high_protein', baseCalories: 2000,
    description: 'High-protein Indian fitness plan supporting muscle tone and endurance improvements simultaneously.',
    macros: { proteinPct: 35, carbsPct: 35, fatPct: 30 },
    days: make7Days(
      rot([hpBreakfast1, oatsBreakfast, hpBreakfast2, eggWheatBreakfast, hpBreakfast1, oatsBreakfast, hpBreakfast2]),
      rot([hpMidMorning, fruitCurd, hpMidMorning, fruitNuts, hpMidMorning, masalaChai, fruitCurd]),
      rot([hpLunch1, chickenRotiLunch, hpLunch2, chickenRiceLunch, hpLunch1, hpLunch2, chickenRotiLunch]),
      rot([hpPreWorkout, bananaCurd, hpPreWorkout, fruitProtein, hpPreWorkout, bananaCurd, hpPreWorkout]),
      rot([hpDinner1, chickenSabziDinner, hpDinner2, fishRotiDinner, hpDinner1, hpDinner2, chickenSabziDinner]),
    ),
  },
  // ── MAINTAIN ──────────────────────────────────────────────────────────────
  {
    name: 'Maintenance Plan – Omnivore',
    goal: 'maintain', dietPref: 'none', baseCalories: 2000,
    description: 'Balanced Indian omnivore maintenance plan to sustain current weight and fitness with enjoyable variety.',
    macros: { proteinPct: 25, carbsPct: 45, fatPct: 30 },
    days: make7Days(
      rot([eggWheatBreakfast, oatsBreakfast, idliBreakfast, paratheBreakfast, pohaBreakfast, upmaBreakfast, eggWheatBreakfast]),
      rot([fruitNuts, masalaChai, fruitCurd, fruitNuts, sproutsSalad, masalaChai, fruitCurd]),
      rot([chickenRotiLunch, eggRotiLunch, chickenRiceLunch, eggRotiLunch, chickenRotiLunch, chickenRiceLunch, eggRotiLunch]),
      rot([bananaCurd, dryFruits, fruitProtein, bananaCurd, dryFruits, fruitProtein, bananaCurd]),
      rot([fishRotiDinner, eggCurryDinner, chickenSabziDinner, fishRotiDinner, chickenSabziDinner, eggCurryDinner, chickenSabziDinner]),
    ),
  },
  {
    name: 'Maintenance Plan – Vegetarian',
    goal: 'maintain', dietPref: 'vegetarian', baseCalories: 2000,
    description: 'Varied vegetarian Indian plan for long-term weight maintenance with satisfying traditional meals.',
    macros: { proteinPct: 22, carbsPct: 48, fatPct: 30 },
    days: make7Days(
      rot([upmaBreakfast, idliBreakfast, pohaBreakfast, dalChillaBreakfast, paratheBreakfast, oatsBreakfast, upmaBreakfast]),
      rot([masalaChai, fruitCurd, fruitNuts, masalaChai, sproutsSalad, fruitCurd, fruitNuts]),
      rot([rajmaRotiLunch, paneerRiceLunch, paneerRotiLunch, rajmaRotiLunch, paneerRiceLunch, paneerRotiLunch, rajmaRotiLunch]),
      rot([fruitCurd, oatsBanana, bananaCurd, dryFruits, fruitCurd, oatsBanana, bananaCurd]),
      rot([paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner, dalMakhniDinner, paneerSabziDinner]),
    ),
  },
  {
    name: 'Maintenance Plan – Vegan',
    goal: 'maintain', dietPref: 'vegan', baseCalories: 2000,
    description: 'Sustainable plant-based Indian maintenance plan using seasonal vegetables, legumes, and whole grains.',
    macros: { proteinPct: 20, carbsPct: 50, fatPct: 30 },
    days: make7Days(
      rot([idliBreakfast, oatsBreakfast, pohaBreakfast, upmaBreakfast, dalChillaBreakfast, idliBreakfast, oatsBreakfast]),
      rot([sproutsSalad, fruitNuts, peanutFruit, sproutsSalad, masalaChai, fruitNuts, peanutFruit]),
      rot([chanaRotiLunch, tofuRiceLunch, dalRiceLunch, chanaRotiLunch, tofuRiceLunch, dalRiceLunch, chanaRotiLunch]),
      rot([peanutFruit, oatsBanana, dryFruits, peanutFruit, oatsBanana, dryFruits, peanutFruit]),
      rot([dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner, chanaRiceDinner, dalVegDinner]),
    ),
  },
  {
    name: 'Maintenance Plan – Keto',
    goal: 'maintain', dietPref: 'keto', baseCalories: 2000,
    description: 'Long-term Indian keto maintenance plan for those adapted to fat burning who want to maintain body composition.',
    macros: { proteinPct: 25, carbsPct: 10, fatPct: 65 },
    days: make7Days(
      rot([avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK, eggBaconBreakfastK, avocadoEggBreakfastK]),
      rot([ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning, ketoMidMorning]),
      rot([paneerKetoLunch, chickenKetoLunch, paneerKetoLunch, eggKetoLunch, chickenKetoLunch, paneerKetoLunch, eggKetoLunch]),
      rot([ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout, ketoPreWorkout]),
      rot([paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner, chickenKetoDinner, paneerKetoDinner]),
    ),
  },
  {
    name: 'Maintenance Plan – High Protein',
    goal: 'maintain', dietPref: 'high_protein', baseCalories: 2000,
    description: 'High-protein Indian maintenance plan to preserve muscle mass and body composition long-term.',
    macros: { proteinPct: 35, carbsPct: 35, fatPct: 30 },
    days: make7Days(
      rot([hpBreakfast1, hpBreakfast2, eggWheatBreakfast, hpBreakfast1, oatsBreakfast, hpBreakfast2, eggWheatBreakfast]),
      rot([hpMidMorning, fruitNuts, fruitCurd, hpMidMorning, masalaChai, fruitNuts, hpMidMorning]),
      rot([hpLunch1, chickenRotiLunch, hpLunch2, hpLunch1, chickenRiceLunch, hpLunch2, hpLunch1]),
      rot([hpPreWorkout, bananaCurd, fruitProtein, hpPreWorkout, bananaCurd, fruitProtein, hpPreWorkout]),
      rot([hpDinner1, hpDinner2, chickenSabziDinner, hpDinner1, hpDinner2, fishRotiDinner, hpDinner1]),
    ),
  },
];

// ─── Seed ─────────────────────────────────────────────────────────────────
async function seed() {
  await mongoose.connect(URI);
  console.log('Connected to MongoDB');

  // Workout templates
  await WorkoutPlanTemplate.deleteMany({});
  const insertedW = await WorkoutPlanTemplate.insertMany(WORKOUT_TEMPLATES);
  console.log(`Inserted ${insertedW.length} workout templates`);

  // Meal templates
  await MealPlanTemplate.deleteMany({});
  const insertedM = await MealPlanTemplate.insertMany(MEAL_TEMPLATES);
  console.log(`Inserted ${insertedM.length} meal templates`);

  await mongoose.disconnect();
  console.log('Done. Disconnected.');
}

seed().catch(err => { console.error(err); process.exit(1); });
