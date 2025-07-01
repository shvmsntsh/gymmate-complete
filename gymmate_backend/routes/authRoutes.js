const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/authMiddleware');
const userController = require('../controllers/userController');

// Public routes
router.post('/register', userController.register);
router.post('/login', userController.login);

// Protected routes - All routes below this line require a valid token
router.use(authenticateToken);

// Get current user's profile data
router.get('/me', userController.getUserProfile);

// Get user details specifically for the plan generation
router.get('/user-details-for-plan', userController.getUserDetailsForPlan);

// Onboarding-related routes
router.post('/complete-onboarding', userController.updateOnboardingStatus);

// Dashboard stats for superadmin
router.get('/dashboard/stats', userController.getDashboardStats);

// Categorized members for superadmin
router.get('/members/categorized', userController.getCategorizedMembers);

module.exports = router;
