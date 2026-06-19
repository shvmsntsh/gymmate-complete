const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/authMiddleware');
const ctrl = require('../controllers/memberPlanController');

// Member routes (mounted at /api/member/me)
router.post('/profile', authenticateToken, ctrl.saveProfile);
router.get('/profile', authenticateToken, ctrl.getProfile);
router.get('/workout-plan', authenticateToken, ctrl.getWorkoutPlan);
router.get('/meal-plan', authenticateToken, ctrl.getMealPlan);

// Trainer routes (mounted at /api)
router.put('/trainer/members/:memberId/workout-plan', authenticateToken, ctrl.trainerUpdateWorkoutPlan);
router.put('/trainer/members/:memberId/meal-plan', authenticateToken, ctrl.trainerUpdateMealPlan);

module.exports = router;
