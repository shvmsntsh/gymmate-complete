const { authenticateToken } = require('../middleware/authMiddleware');
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { generateInviteCode: gymControllerGenerate, createGymAndOwnerInvite } = require('../controllers/gymController');
const {
  listInviteCodes,
  generateInviteCode: inviteControllerGenerate,
  validateInviteCode,
} = require('../controllers/inviteController');


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

    const gym = invite.gymId
      ? await Gym.findById(invite.gymId)
      : await Gym.findOne({ gymName: invite.gymName });
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


router.post('/validate', validateInviteCode);
router.post('/verify', validateInviteCode);

// POST /api/invite/generate - Generate a new invite code
router.post('/generate', authenticateToken, inviteControllerGenerate);

// GET /api/invite/list - List all invite codes based on role
router.get('/list', authenticateToken, listInviteCodes);

// Superadmin: create gym and gym_owner invite in one step
router.post('/superadmin-create', authenticateToken, async (req, res, next) => {
  if (!req.user || req.user.role !== 'superadmin') {
    console.error('❌ Only superadmin can access this endpoint');
    return res.status(403).json({ error: 'Only superadmin can create gyms and owner invites.' });
  }
  return createGymAndOwnerInvite(req, res, next);
});

module.exports = router;
