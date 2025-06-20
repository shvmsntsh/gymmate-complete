const { authenticateToken } = require('../middleware/authMiddleware');
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { generateInviteCode } = require('../controllers/gymController');
const { listInviteCodes } = require('../controllers/inviteController');


// POST /api/gym/register - Register a new user with invite code
router.post('/register', async (req, res) => {
  try {
    const { username, password, inviteCode } = req.body;
    if (!username || !password || !inviteCode) {
      return res.status(400).json({ error: 'Username, password, and invite code are required.' });
    }

    // Validate invite code
    const invite = await InviteCode.findOne({ code: inviteCode, used: false });
    if (!invite) {
      return res.status(400).json({ error: 'Invalid or expired invite code.' });
    }

    // Lookup gymId based on gymName
    const gym = await Gym.findOne({ gymName: invite.gymName });
    if (!gym) {
      return res.status(400).json({ error: 'Gym not found for this invite code.' });
    }

    // Check if username already exists
    const existingUser = await User.findOne({ username });
    if (existingUser) {
      return res.status(400).json({ error: 'Username already exists.' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user with role and gymId from invite
    const newUser = new User({
      username,
      password: hashedPassword,
      role: invite.role,
      gymId: gym._id
    });

    await newUser.save();

    // Mark invite code as used, record usedBy and update timestamp
    invite.used = true;
    invite.usedBy = username;
    invite.updatedAt = new Date();
    await invite.save();

    res.status(201).json({ message: 'User registered successfully.' });
  } catch (err) {
    console.error('❌ Error during registration:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// POST /api/invite/validate - Validate an invite code
router.post('/validate', async (req, res) => {
  const { code } = req.body;
  if (!code) {
    return res.status(400).json({ error: 'Invite code is required.' });
  }

  const invite = await InviteCode.findOne({ code, used: false });
  if (!invite) {
    return res.status(400).json({ error: 'Invalid or expired invite code.' });
  }

  const gym = await Gym.findById(invite.gymId);
  return res.status(200).json({
    message: 'Valid invite code.',
    role: invite.role,
    gym: gym || null,
    gymId: invite.gymId?.toString() || null
  });
});

// POST /api/invite/generate - Generate a new invite code
router.post('/generate', authenticateToken, async (req, res) => {
  try {
    const { role, gymName } = req.body;
    const user = req.user;

    if (!role || !gymName) {
      return res.status(400).json({ message: 'Role and gymName are required' });
    }

    // Only superadmin can create gym_owner codes, and gym_owner can create gym_member codes
    if (user.role === 'superadmin' && role !== 'gym_owner') {
      return res.status(403).json({ message: 'Superadmin can only generate codes for gym_owner' });
    }
    if (user.role === 'gym_owner' && role !== 'gym_member') {
      return res.status(403).json({ message: 'Gym owner can only generate codes for gym_member' });
    }

    let finalGymName = gymName;
    if (user.role !== 'superadmin') {
      const gym = await Gym.findById(user.gymId);
      finalGymName = gym?.gymName || 'Unknown Gym';
    }

    console.log('📥 Invite Generation Request:', { role, gymName: finalGymName, gymId: req.user.gymId });
    console.log('👤 User:', user.email, '🏢 Role:', user.role, '🏋️ Gym:', finalGymName);

    const code = Math.random().toString(36).substring(2, 10).toUpperCase();
    const newCode = new InviteCode({
      code,
      role,
      gymId: req.user.gymId,
      gymName: finalGymName,
      used: false
    });

    await newCode.save();
    console.log('✅ Invite Code Saved:', newCode);
    res.status(201).json({ message: 'Invite code generated', code });
    console.log('🎯 Code generated and returned to client:', code);
  } catch (error) {
    console.error('Error generating invite code:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// GET /api/invite/list - List all invite codes based on role
router.get('/list', authenticateToken, listInviteCodes);

module.exports = router;
