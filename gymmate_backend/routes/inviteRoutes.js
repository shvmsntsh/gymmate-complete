const { authenticateToken } = require('../middleware/authMiddleware');
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { generateInviteCode: gymControllerGenerate, createGymAndOwnerInvite } = require('../controllers/gymController');
const { listInviteCodes, generateInviteCode: inviteControllerGenerate } = require('../controllers/inviteController');


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
    console.error('❌ Invite code is required');
    return res.status(400).json({ error: 'Invite code is required.' });
  }

  // Handle the special superadmin code "123456"
  if (code === '123456') {
    const userCount = await User.countDocuments();
    if (userCount > 0) {
      console.error('❌ Superadmin already exists.');
      return res.status(400).json({ error: 'Superadmin already exists.' });
    }
    return res.status(200).json({
      message: 'Valid superadmin invite code.',
      role: 'superadmin',
      gym: null,
      gymId: null
    });
  }

  try {
    const invite = await InviteCode.findOne({ code });
    if (!invite) {
      console.error('❌ Invalid invite code:', code);
      return res.status(400).json({ error: 'Invalid invite code.' });
    }
    if (invite.used) {
      console.error('❌ Invite code already used:', code);
      return res.status(400).json({ error: 'Invite code already used.' });
    }
    // For gym_owner, allow gymId to be null (gym will be created on registration)
    if (invite.role === 'gym_owner') {
      return res.status(200).json({
        message: 'Valid invite code.',
        role: invite.role,
        gym: null,
        gymId: null
      });
    }
    // For member/trainer, require gymId and gym to exist
    if (!invite.gymId) {
      console.error('❌ Invite code does not reference a valid gym:', code);
      return res.status(400).json({ error: 'Invite code does not reference a valid gym.' });
    }
    const gym = await Gym.findById(invite.gymId);
    if (!gym) {
      console.error('❌ Gym not found for invite code:', code, 'with gymId:', invite.gymId);
      return res.status(400).json({ error: 'Gym not found for this invite code.' });
    }
    console.log('✅ Invite code validated:', code, 'for gym:', gym.gymName);
    res.status(200).json({
      message: 'Valid invite code.',
      role: invite.role,
      gym: { gymName: gym.gymName, _id: gym._id },
      gymId: gym._id
    });
  } catch (err) {
    console.error('❌ Error validating invite code:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

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
