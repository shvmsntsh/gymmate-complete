const express = require('express');
const router = express.Router();
const { generatePlan } = require('../controllers/aiController');
const { authenticateToken } = require('../middleware/authMiddleware');

router.post('/generate-plan', authenticateToken, generatePlan);

module.exports = router; 