const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { authenticateToken } = require('../middleware/authMiddleware');

// Public routes
router.post('/register', userController.register);
router.post('/login', userController.login);

// Protected routes (require a valid JWT)
router.post('/invite/generate', authenticateToken, userController.generateInviteCode);

// New user-based endpoints
router.get('/members', authenticateToken, userController.getMembers);
router.get('/all-members', authenticateToken, userController.getAllMembers);
router.get('/self', authenticateToken, userController.getSelf);

module.exports = router;
