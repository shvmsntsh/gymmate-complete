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

// Protected routes
router.use(authenticateToken);

// Get current user's data
router.get('/me', async (req, res) => {
  try {
    console.log('🔍 Fetching user data for ID:', req.user.id);
    
    const user = await User.findById(req.user.id)
      .select('name email role gymId profile preferences gamification onboardingProgress');
    
    if (!user) {
      console.log('❌ User not found for ID:', req.user.id);
      return res.status(404).json({ message: 'User not found' });
    }

    console.log('✅ Found user:', user.email);

    // If it's a gym member or owner, get the gym name
    let gymName = null;
    if (user.gymId) {
      const gym = await Gym.findById(user.gymId);
      if (gym) {
        gymName = gym.gymName;
        console.log('✅ Found gym:', gymName);
      }
    }

    const response = {
      id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      gymId: user.gymId,
      gymName,
      profile: user.profile || {},
      preferences: user.preferences || {},
      gamification: user.gamification || {},
      onboardingProgress: user.onboardingProgress || {}
    };

    console.log('📤 Sending response:', JSON.stringify(response, null, 2));
    res.status(200).json(response);
  } catch (error) {
    console.error('❌ Error fetching user data:', error);
    res.status(500).json({ 
      message: 'Internal server error', 
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

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
