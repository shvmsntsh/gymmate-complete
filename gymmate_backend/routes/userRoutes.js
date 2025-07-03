const express = require('express');
const router = express.Router();
const User = require('../models/User'); // Adjust path if needed
const { authenticateToken } = require('../middleware/authMiddleware');
const { updateProfile, getMe } = require('../controllers/userController');

// Register a new gym member
router.post('/register-member', async (req, res) => {
  const { name, email, password, gymId } = req.body;

  if (!name || !email || !password || !gymId) {
    return res.status(400).json({ message: 'All fields are required.' });
  }

  try {
    const newUser = new User({
      name,
      email,
      password,
      role: 'gym_member',
      gymId,
    });

    await newUser.save();
    res.status(200).json({ message: 'Gym member registered successfully!' });
  } catch (err) {
    console.error('❌ Registration error:', err);
    res.status(500).json({ message: 'Server error during registration.' });
  }
});

// Update profile (name/email)
router.put('/profile', authenticateToken, updateProfile);

// Get current user profile
router.get('/me', authenticateToken, getMe);

module.exports = router;