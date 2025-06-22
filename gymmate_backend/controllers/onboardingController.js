const Gym = require('../models/Gym');

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
    const gym = await Gym.findById(userId);
    
    if (!gym) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!gym.onboardingProgress) {
      gym.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7,
      };
    }

    // Ensure gamification object exists
    if (!gym.gamification) {
      gym.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    await gym.save();

    const onboardingData = {
      isCompleted: gym.onboardingProgress.isCompleted,
      currentStep: gym.onboardingProgress.currentStep,
      stepsCompleted: gym.onboardingProgress.stepsCompleted,
      totalSteps: gym.onboardingProgress.totalSteps,
      progress: Math.round((gym.onboardingProgress.stepsCompleted.length / 7) * 100),
      startedAt: gym.onboardingProgress.startedAt,
      completedAt: gym.onboardingProgress.completedAt,
      gamification: {
        totalXP: gym.gamification.totalXP,
        level: gym.gamification.level,
        badges: gym.gamification.badges,
        achievements: gym.gamification.achievements
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
    const gym = await Gym.findById(userId);
    
    if (!gym) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!gym.onboardingProgress) {
      gym.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7
      };
    }

    // Ensure gamification object exists
    if (!gym.gamification) {
      gym.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    // Initialize onboarding if not already started
    if (!gym.onboardingProgress.startedAt) {
      gym.onboardingProgress.isCompleted = false;
      gym.onboardingProgress.currentStep = 1;
      gym.onboardingProgress.stepsCompleted = [];
      gym.onboardingProgress.startedAt = new Date();
      gym.onboardingProgress.completedAt = null;
      gym.onboardingProgress.totalSteps = 7;

      // Award welcome XP and badge
      await awardXP(gym, XP_REWARDS.step_1_welcome);
      await awardBadge(gym, BADGES.first_steps);

      await gym.save();
    }

    res.status(200).json({
      message: 'Onboarding started successfully!',
      currentStep: gym.onboardingProgress.currentStep,
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

    const gym = await Gym.findById(userId);
    if (!gym) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!gym.onboardingProgress) {
      gym.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7
      };
    }

    // Ensure gamification object exists
    if (!gym.gamification) {
      gym.gamification = {
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
        gym.profile = { ...gym.profile, ...data };
        if (!gym.onboardingProgress.stepsCompleted.includes(2)) {
          xpAwarded = XP_REWARDS.step_2_profile;
          await awardXP(gym, xpAwarded);
          gym.onboardingProgress.stepsCompleted.push(2);
        }
        break;

      case 3: // Fitness Goals
        gym.fitnessGoals = data.goals || [];
        if (!gym.onboardingProgress.stepsCompleted.includes(3)) {
          xpAwarded = XP_REWARDS.step_3_goals;
          await awardXP(gym, xpAwarded);
          badgeUnlocked = await awardBadge(gym, BADGES.goal_setter);
          gym.onboardingProgress.stepsCompleted.push(3);
        }
        break;

      case 4: // Diet Preferences
        gym.dietPreferences = { ...gym.dietPreferences, ...data };
        if (!gym.onboardingProgress.stepsCompleted.includes(4)) {
          xpAwarded = XP_REWARDS.step_4_diet;
          await awardXP(gym, xpAwarded);
          badgeUnlocked = await awardBadge(gym, BADGES.health_conscious);
          gym.onboardingProgress.stepsCompleted.push(4);
        }
        break;

      case 5: // Workout Habits
        gym.workoutHabits = { ...gym.workoutHabits, ...data };
        if (!gym.onboardingProgress.stepsCompleted.includes(5)) {
          xpAwarded = XP_REWARDS.step_5_workout;
          await awardXP(gym, xpAwarded);
          badgeUnlocked = await awardBadge(gym, BADGES.workout_warrior);
          gym.onboardingProgress.stepsCompleted.push(5);
        }
        break;

      case 6: // First Challenge
        gym.firstChallenge = { ...gym.firstChallenge, ...data, isAccepted: true, startDate: new Date() };
        if (!gym.onboardingProgress.stepsCompleted.includes(6)) {
          xpAwarded = XP_REWARDS.step_6_challenge;
          await awardXP(gym, xpAwarded);
          badgeUnlocked = await awardBadge(gym, BADGES.challenge_accepted);
          gym.onboardingProgress.stepsCompleted.push(6);
        }
        break;

      case 7: // Completion
        if (!gym.onboardingProgress.stepsCompleted.includes(7)) {
          gym.onboardingProgress.isCompleted = true;
          gym.onboardingProgress.completedAt = new Date();
          xpAwarded = XP_REWARDS.step_7_completion;
          await awardXP(gym, xpAwarded);
          badgeUnlocked = await awardBadge(gym, BADGES.onboarding_complete);
          gym.onboardingProgress.stepsCompleted.push(7);
        }
        break;
    }

    // Update current step
    if (step > gym.onboardingProgress.currentStep) {
      gym.onboardingProgress.currentStep = step;
    }

    // Check for level up
    const oldLevel = gym.gamification.level;
    levelUp = calculateLevel(gym) > oldLevel;

    await gym.save();

    res.status(200).json({
      message: 'Progress saved successfully!',
      currentStep: gym.onboardingProgress.currentStep,
      stepsCompleted: gym.onboardingProgress.stepsCompleted,
      progress: Math.round((gym.onboardingProgress.stepsCompleted.length / 7) * 100),
      xpAwarded,
      totalXP: gym.gamification.totalXP,
      level: gym.gamification.level,
      levelUp,
      badgeUnlocked,
      isCompleted: gym.onboardingProgress.isCompleted
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
    const gym = await Gym.findById(userId);
    
    if (!gym) {
      return res.status(404).json({ message: 'User not found' });
    }

    const badges = gym.gamification?.badges || [];
    
    res.status(200).json({
      badges,
      totalBadges: badges.length,
      totalXP: gym.gamification?.totalXP || 0,
      level: gym.gamification?.level || 1
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
    const gym = await Gym.findById(userId)
      .select('gamification onboardingProgress preferences profile fitnessGoals');

    if (!gym) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!gym.onboardingProgress) {
      gym.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7,
      };
    }

    // Ensure gamification object exists
    if (!gym.gamification) {
      gym.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    // Ensure other objects exist
    if (!gym.preferences) gym.preferences = { theme: 'light' };
    if (!gym.profile) gym.profile = {};
    if (!gym.fitnessGoals) gym.fitnessGoals = [];

    await gym.save();

    const progressData = {
      totalXP: gym.gamification.totalXP,
      level: gym.gamification.level,
      badges: gym.gamification.badges,
      isOnboardingComplete: gym.onboardingProgress.isCompleted,
      onboardingProgress: Math.round((gym.onboardingProgress.stepsCompleted.length / 7) * 100),
      theme: gym.preferences.theme,
      profile: gym.profile,
      fitnessGoals: gym.fitnessGoals,
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
    const gym = await Gym.findById(userId);

    if (!gym) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Reset onboarding and gamification data
    gym.onboardingProgress = {
      isCompleted: false,
      currentStep: 0,
      stepsCompleted: [],
      startedAt: null,
      completedAt: null,
      totalSteps: 7,
    };
    gym.gamification = {
      totalXP: 0,
      level: 1,
      badges: [],
      streaks: { current: 0, longest: 0, lastLoginDate: null },
      achievements: {},
    };
    
    await gym.save();
    
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
    const gym = await Gym.findById(userId);

    if (!gym) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Ensure onboardingProgress object exists
    if (!gym.onboardingProgress) {
      gym.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7
      };
    }

    // Ensure gamification object exists
    if (!gym.gamification) {
      gym.gamification = {
        totalXP: 0,
        level: 1,
        badges: [],
        streaks: { current: 0, longest: 0, lastLoginDate: null },
        achievements: {}
      };
    }

    // Mark onboarding as completed
    gym.onboardingProgress.isCompleted = true;
    gym.onboardingProgress.completedAt = new Date();
    gym.onboardingProgress.currentStep = 7;
    
    if (!gym.onboardingProgress.stepsCompleted.includes(7)) {
      gym.onboardingProgress.stepsCompleted.push(7);
    }

    // Award completion XP and badge
    const xpAwarded = XP_REWARDS.step_7_completion;
    await awardXP(gym, xpAwarded);
    const badgeUnlocked = await awardBadge(gym, BADGES.onboarding_complete);

    await gym.save();

    res.status(200).json({
      message: 'Onboarding completed successfully!',
      isCompleted: true,
      xpAwarded,
      totalXP: gym.gamification.totalXP,
      level: gym.gamification.level,
      badgeUnlocked,
      completedAt: gym.onboardingProgress.completedAt
    });
  } catch (error) {
    console.error('❌ Error completing onboarding:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// 🏆 Helper Functions
async function awardXP(gym, xp) {
  if (!gym.gamification) {
    gym.gamification = { totalXP: 0, level: 1, badges: [], streaks: { current: 0, longest: 0 }, achievements: {} };
  }
  
  gym.gamification.totalXP += xp;
  gym.gamification.level = calculateLevel(gym);
  
  return xp;
}

async function awardBadge(gym, badgeData) {
  if (!gym.gamification) {
    gym.gamification = { totalXP: 0, level: 1, badges: [], streaks: { current: 0, longest: 0 }, achievements: {} };
  }

  // Check if badge already exists
  const existingBadge = gym.gamification.badges.find(b => b.id === badgeData.id);
  if (existingBadge) {
    return null;
  }

  const newBadge = {
    ...badgeData,
    unlockedAt: new Date(),
    xpAwarded: 0
  };

  gym.gamification.badges.push(newBadge);
  return newBadge;
}

function calculateLevel(gym) {
  const xp = gym.gamification?.totalXP || 0;
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