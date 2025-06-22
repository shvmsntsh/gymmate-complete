const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/authMiddleware');
const {
  getOnboardingStatus,
  startOnboarding,
  saveStepProgress,
  getUserBadges,
  getUserProgress,
  resetOnboarding,
  completeOnboarding
} = require('../controllers/onboardingController');

// 🔐 All onboarding routes require authentication
router.use(authenticateToken);

// 📊 GET /api/onboarding/status - Get current onboarding status
router.get('/status', getOnboardingStatus);

// 🚀 POST /api/onboarding/start - Start onboarding process
router.post('/start', startOnboarding);

// 💾 POST /api/onboarding/step - Save progress for a specific step
router.post('/step', saveStepProgress);

// ✅ POST /api/onboarding/complete - Complete onboarding process
router.post('/complete', completeOnboarding);

// 🏆 GET /api/onboarding/badges - Get user's badges
router.get('/badges', getUserBadges);

// 📈 GET /api/onboarding/progress - Get comprehensive user progress
router.get('/progress', getUserProgress);

// 🔄 POST /api/onboarding/reset - Reset onboarding (for testing)
router.post('/reset', resetOnboarding);

module.exports = router;