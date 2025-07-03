const express = require('express');
const router = express.Router();
const { generatePlan, aiCoachChat } = require('../controllers/aiController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.post('/generate-plan', authenticateToken, generatePlan);
router.post('/coach-chat', authenticateToken, aiCoachChat);

module.exports = router; 