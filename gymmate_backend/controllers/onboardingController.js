const User = require('../models/User');

// 🎮 Gamification Constants
const XP_REWARDS = {
  step_1_welcome: 50,
  step_2_profile: 100,
  step_3_goals: 150,
  step_4_diet: 100,
  step_5_workout: 150,
  step_6_challenge: 200,
  step_7_completion: 500,
};

const BADGES = {
  first_steps: {
    id: 'first_steps',
    name: 'First Steps',
    description: 'Started your fitness journey!',
    category: 'starter',
    iconUrl: '/badges/first_steps.png'
  },
  goal_setter: {
    id: 'goal_setter',
    name: 'Goal Setter',
    description: 'Set your fitness goals',
    category: 'starter',
    iconUrl: '/badges/goal_setter.png'
  },
  health_conscious: {
    id: 'health_conscious',
    name: 'Health Conscious',
    description: 'Shared your diet preferences',
    category: 'starter',
    iconUrl: '/badges/health_conscious.png'
  },
  workout_warrior: {
    id: 'workout_warrior',
    name: 'Workout Warrior',
    description: 'Ready to crush your workouts!',
    category: 'milestone',
    iconUrl: '/badges/workout_warrior.png'
  },
  challenge_accepted: {
    id: 'challenge_accepted',
    name: 'Challenge Accepted',
    description: 'Accepted your first fitness challenge',
    category: 'special',
    iconUrl: '/badges/challenge_accepted.png'
  },
  onboarding_complete: {
    id: 'onboarding_complete',
    name: 'Onboarding Champion',
    description: 'Completed the entire onboarding journey!',
    category: 'achievement',
    iconUrl: '/badges/onboarding_complete.png'
  }
};

// 📊 Get Onboarding Status
const getOnboardingStatus = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!user.onboardingProgress) {
      user.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7,
      };
    }

    // Ensure gamification object exists
    if (!user.gamification) {
      user.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    await user.save();

    const onboardingData = {
      isCompleted: user.onboardingProgress.isCompleted,
      currentStep: user.onboardingProgress.currentStep,
      stepsCompleted: user.onboardingProgress.stepsCompleted,
      totalSteps: user.onboardingProgress.totalSteps,
      progress: Math.round((user.onboardingProgress.stepsCompleted.length / 7) * 100),
      startedAt: user.onboardingProgress.startedAt,
      completedAt: user.onboardingProgress.completedAt,
      gamification: {
        totalXP: user.gamification.totalXP,
        level: user.gamification.level,
        badges: user.gamification.badges,
        achievements: user.gamification.achievements
      }
    };

    res.status(200).json(onboardingData);
  } catch (error) {
    console.error('❌ Error fetching onboarding status:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// 🚀 Start Onboarding
const startOnboarding = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!user.onboardingProgress) {
      user.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7
      };
    }

    // Ensure gamification object exists
    if (!user.gamification) {
      user.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    // Initialize onboarding if not already started
    if (!user.onboardingProgress.startedAt) {
      user.onboardingProgress.isCompleted = false;
      user.onboardingProgress.currentStep = 1;
      user.onboardingProgress.stepsCompleted = [];
      user.onboardingProgress.startedAt = new Date();
      user.onboardingProgress.completedAt = null;
      user.onboardingProgress.totalSteps = 7;

      // Award welcome XP and badge
      await awardXP(user, XP_REWARDS.step_1_welcome);
      await awardBadge(user, BADGES.first_steps);

      await user.save();
    }

    res.status(200).json({
      message: 'Onboarding started successfully!',
      currentStep: user.onboardingProgress.currentStep,
      xpAwarded: XP_REWARDS.step_1_welcome,
      badgeUnlocked: BADGES.first_steps
    });
  } catch (error) {
    console.error('❌ Error starting onboarding:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// 💾 Save Step Progress
const saveStepProgress = async (req, res) => {
  try {
    const userId = req.user.id;
    const { step, data } = req.body;
    
    if (!step || !data) {
      return res.status(400).json({ message: 'Step and data are required' });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!user.onboardingProgress) {
      user.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7
      };
    }

    // Ensure gamification object exists
    if (!user.gamification) {
      user.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    let xpAwarded = 0;
    let badgeUnlocked = null;
    let levelUp = false;

    // Process different steps
    switch (step) {
      case 2: // Profile Setup
        user.profile = { ...user.profile, ...data };
        if (!user.onboardingProgress.stepsCompleted.includes(2)) {
          xpAwarded = XP_REWARDS.step_2_profile;
          await awardXP(user, xpAwarded);
          user.onboardingProgress.stepsCompleted.push(2);
        }
        break;

      case 3: // Fitness Goals
        user.fitnessGoals = data.goals || [];
        if (!user.onboardingProgress.stepsCompleted.includes(3)) {
          xpAwarded = XP_REWARDS.step_3_goals;
          await awardXP(user, xpAwarded);
          badgeUnlocked = await awardBadge(user, BADGES.goal_setter);
          user.onboardingProgress.stepsCompleted.push(3);
        }
        break;

      case 4: // Diet Preferences
        user.dietPreferences = { ...user.dietPreferences, ...data };
        if (!user.onboardingProgress.stepsCompleted.includes(4)) {
          xpAwarded = XP_REWARDS.step_4_diet;
          await awardXP(user, xpAwarded);
          badgeUnlocked = await awardBadge(user, BADGES.health_conscious);
          user.onboardingProgress.stepsCompleted.push(4);
        }
        break;

      case 5: // Workout Habits
        user.workoutHabits = { ...user.workoutHabits, ...data };
        if (!user.onboardingProgress.stepsCompleted.includes(5)) {
          xpAwarded = XP_REWARDS.step_5_workout;
          await awardXP(user, xpAwarded);
          badgeUnlocked = await awardBadge(user, BADGES.workout_warrior);
          user.onboardingProgress.stepsCompleted.push(5);
        }
        break;

      case 6: // First Challenge
        user.firstChallenge = { ...user.firstChallenge, ...data, isAccepted: true, startDate: new Date() };
        if (!user.onboardingProgress.stepsCompleted.includes(6)) {
          xpAwarded = XP_REWARDS.step_6_challenge;
          await awardXP(user, xpAwarded);
          badgeUnlocked = await awardBadge(user, BADGES.challenge_accepted);
          user.onboardingProgress.stepsCompleted.push(6);
        }
        break;

      case 7: // Completion
        if (!user.onboardingProgress.stepsCompleted.includes(7)) {
          user.onboardingProgress.isCompleted = true;
          user.onboardingProgress.completedAt = new Date();
          xpAwarded = XP_REWARDS.step_7_completion;
          await awardXP(user, xpAwarded);
          badgeUnlocked = await awardBadge(user, BADGES.onboarding_complete);
          user.onboardingProgress.stepsCompleted.push(7);
        }
        break;
    }

    // Update current step
    if (step > user.onboardingProgress.currentStep) {
      user.onboardingProgress.currentStep = step;
    }

    // Check for level up
    const oldLevel = user.gamification.level;
    levelUp = calculateLevel(user) > oldLevel;

    await user.save();

    res.status(200).json({
      message: 'Progress saved successfully!',
      currentStep: user.onboardingProgress.currentStep,
      stepsCompleted: user.onboardingProgress.stepsCompleted,
      progress: Math.round((user.onboardingProgress.stepsCompleted.length / 7) * 100),
      xpAwarded,
      totalXP: user.gamification.totalXP,
      level: user.gamification.level,
      levelUp,
      badgeUnlocked,
      isCompleted: user.onboardingProgress.isCompleted
    });
  } catch (error) {
    console.error('❌ Error saving step progress:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// 🏆 Get User Badges
const getUserBadges = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const badges = user.gamification?.badges || [];
    
    res.status(200).json({
      badges,
      totalBadges: badges.length,
      totalXP: user.gamification?.totalXP || 0,
      level: user.gamification?.level || 1
    });
  } catch (error) {
    console.error('❌ Error fetching badges:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// 📈 Get User Progress
const getUserProgress = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId)
      .select('gamification onboardingProgress preferences profile fitnessGoals');

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!user.onboardingProgress) {
      user.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7,
      };
    }

    // Ensure gamification object exists
    if (!user.gamification) {
      user.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    // Ensure other objects exist
    if (!user.preferences) {
      user.preferences = { theme: 'light' };
    }
    if (!user.profile) {
      user.profile = {};
    }
    if (!user.fitnessGoals) {
      user.fitnessGoals = [];
    }

    await user.save();

    const progressData = {
      totalXP: user.gamification.totalXP,
      level: user.gamification.level,
      badges: user.gamification.badges,
      isOnboardingComplete: user.onboardingProgress.isCompleted,
      onboardingProgress: Math.round((user.onboardingProgress.stepsCompleted.length / 7) * 100),
      theme: user.preferences.theme,
      profile: user.profile,
      fitnessGoals: user.fitnessGoals,
    };
    
    res.status(200).json(progressData);
  } catch (error) {
    console.error('❌ Error getting user progress:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// 🔄 Reset Onboarding
const resetOnboarding = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Reset onboarding and gamification data
    user.onboardingProgress = {
      isCompleted: false,
      currentStep: 0,
      stepsCompleted: [],
      startedAt: null,
      completedAt: null,
      totalSteps: 7,
    };
    user.gamification = {
      totalXP: 0,
      level: 1,
      badges: [],
      streaks: { current: 0, longest: 0, lastLoginDate: null },
      achievements: {},
    };
    
    await user.save();
    
    res.status(200).json({ message: 'Onboarding has been reset successfully.' });
  } catch (error) {
    console.error('❌ Error resetting onboarding:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// ✅ Complete Onboarding
const completeOnboarding = async (req, res) => {
  try {
    const userId = req.user.id;
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Read onboarding data from request body
    const { profile, fitnessGoals, dietPreferences, workoutHabits, firstChallenge } = req.body;
    console.log('[Onboarding] Incoming data:', req.body);

    if (!profile || !fitnessGoals || !dietPreferences || !workoutHabits || !firstChallenge) {
      return res.status(400).json({ message: 'Missing required onboarding fields.' });
    }

    // Save onboarding data to user document with fallback/defaults
    user.profile = {
      ...user.profile,
      ...profile,
      age: Math.max(profile.age || 18, 13),
      height: Math.max(profile.height || 170, 100),
      weight: Math.max(profile.weight || 70, 20),
    };

    user.fitnessGoals = fitnessGoals;

    user.dietPreferences = {
      ...user.dietPreferences,
      ...dietPreferences,
      waterIntake: dietPreferences.waterIntake || 8,
      dailyMeals: dietPreferences.dailyMeals || 3,
      allergies: dietPreferences.allergies || [],
      restrictions: dietPreferences.restrictions || [],
    };

    user.workoutHabits = {
      ...user.workoutHabits,
      ...workoutHabits,
      workoutsPerWeek: workoutHabits.workoutsPerWeek || 3,
      sessionDuration: workoutHabits.sessionDuration || 60,
      hasInjuries: workoutHabits.hasInjuries || false,
      injuryDetails: workoutHabits.injuryDetails || null,
      favoriteExercises: workoutHabits.favoriteExercises || [],
    };

    user.firstChallenge = { ...user.firstChallenge, ...firstChallenge, isAccepted: true, startDate: new Date() };

    // Ensure onboardingProgress object exists
    if (!user.onboardingProgress) {
      user.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7
      };
    }

    if (!user.gamification) {
      user.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    user.onboardingProgress.isCompleted = true;
    user.onboardingProgress.completedAt = new Date();
    user.onboardingProgress.currentStep = 7;
    if (!user.onboardingProgress.stepsCompleted.includes(7)) {
      user.onboardingProgress.stepsCompleted.push(7);
    }

    user.hasCompletedOnboarding = true;

    const xpAwarded = XP_REWARDS.step_7_completion;
    await awardXP(user, xpAwarded);
    const badgeUnlocked = await awardBadge(user, BADGES.onboarding_complete);

    await user.save();

    res.status(200).json({
      message: 'Onboarding completed successfully!',
      isCompleted: true,
      xpAwarded,
      totalXP: user.gamification.totalXP,
      level: user.gamification.level,
      badgeUnlocked,
      completedAt: user.onboardingProgress.completedAt
    });
  } catch (error) {
    console.error('❌ Error completing onboarding:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// 🏆 Helper Functions
async function awardXP(user, xp) {
  if (!user.gamification) {
    user.gamification = { totalXP: 0, level: 1, badges: [], streaks: { current: 0, longest: 0 }, achievements: {} };
  }
  
  user.gamification.totalXP += xp;
  user.gamification.level = calculateLevel(user);
  
  return xp;
}

async function awardBadge(user, badgeData) {
  if (!user.gamification) {
    user.gamification = { totalXP: 0, level: 1, badges: [], streaks: { current: 0, longest: 0 }, achievements: {} };
  }

  // Check if badge already exists
  const existingBadge = user.gamification.badges.find(b => b.id === badgeData.id);
  if (existingBadge) {
    return null;
  }

  const newBadge = {
    ...badgeData,
    unlockedAt: new Date(),
    xpAwarded: 0
  };

  user.gamification.badges.push(newBadge);
  return newBadge;
}

function calculateLevel(user) {
  const xp = user.gamification?.totalXP || 0;
  // Level calculation: Level 1 = 0-99 XP, Level 2 = 100-299 XP, etc.
  return Math.floor(xp / 100) + 1;
}

module.exports = {
  getOnboardingStatus,
  startOnboarding,
  saveStepProgress,
  getUserBadges,
  getUserProgress,
  resetOnboarding,
  completeOnboarding
};