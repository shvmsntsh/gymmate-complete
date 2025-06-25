const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { authenticateToken } = require('../middleware/authMiddleware');
const Gym = require('../models/Gym');
const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const bcrypt = require('bcrypt');
const mongoose = require('mongoose');

// Public routes
router.post('/register', userController.register);
router.post('/login', userController.login);

// Protected routes (require a valid JWT)
router.post('/invite/generate', authenticateToken, userController.generateInviteCode);

// New user-based endpoints
router.get('/members', authenticateToken, userController.getMembers);
router.get('/all-members', authenticateToken, userController.getAllMembers);
router.get('/self', authenticateToken, userController.getSelf);

// Add this route before module.exports
router.post('/check-email', async (req, res) => {
  const { email } = req.body;
  if (!email) {return res.status(400).json({ exists: false });}
  const user = await User.findOne({ email });
  if (!user) {
    res.json({ exists: false });
  } else {
    res.json({ exists: true });
  }
});

module.exports = router;
