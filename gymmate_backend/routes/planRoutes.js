const express = require('express');
const router = express.Router();
const planController = require('../controllers/planController');
const { protect, requireRole } = require('../middleware/authMiddleware');

// Fetch meal plan for user
router.get('/meal', protect, planController.getMealPlanForUser);
// Fetch workout plan for user
router.get('/workout', protect, planController.getWorkoutPlanForUser);
// Trainer/owner override plan for member
router.post('/:memberId/:type', protect, requireRole(['gym_trainer', 'gym_owner']), planController.trainerUpdatePlan);

module.exports = router;
