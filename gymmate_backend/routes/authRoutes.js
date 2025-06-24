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
router.post('/register', async (req, res) => {
  try {
    console.log('🔗 Mongoose connection string:', mongoose.connection.client.s.url);
    console.log('🔗 Mongoose db name:', mongoose.connection.name);
    const { name, email, password, role, inviteCode, gymName } = req.body;
    console.log('🔔 Registration attempt:', { name, email, role, inviteCode, gymName });

    if (inviteCode === '123456' && role === 'superadmin') {
      console.log('💎 Superadmin registration attempt with special code.');
      const existingUser = await User.findOne({ email });
      if (existingUser) {
        return res.status(400).json({ error: 'Email already registered.' });
      }
      const hashedPassword = await bcrypt.hash(password, 10);
      const newUser = new User({ name, email, password: hashedPassword, role: 'superadmin', gymId: null });
      await newUser.save();
      console.log('✅ Superadmin user registered with special code.');
      return res.status(201).json({ message: 'User registered successfully.' });
    }

    if (!name || !email || !password || !role) {
      console.error('❌ Missing required registration fields');
      return res.status(400).json({ error: 'Missing required fields.' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      console.error('❌ Email already registered:', email);
      return res.status(400).json({ error: 'Email already registered.' });
    }

    let gymId = null;
    // Gym Owner registration: create a new gym
    if (role === 'gym_owner') {
      if (!inviteCode) {
        return res.status(400).json({ error: 'Invite code is required for gym owner registration.' });
      }
      
      const invite = await InviteCode.findOne({ code: inviteCode, role: 'gym_owner', used: false });

      if (!invite) {
        return res.status(400).json({ error: 'Invalid or expired invite code for gym owner.' });
      }

      if (!gymName) {
        console.error('❌ Gym name required for gym owner registration');
        return res.status(400).json({ error: 'Gym name required for gym owner.' });
      }
      const newGym = new Gym({ gymName, email });
      await newGym.save();
      gymId = newGym._id;
      console.log('✅ New gym created:', newGym);

      // Mark the invite code as used
      invite.used = true;
      invite.usedBy = email;
      invite.gymId = gymId; // Associate gym with invite
      invite.updatedAt = new Date();
      await invite.save();

    }
    // Gym Member registration: use invite code
    else if (role === 'gym_member') {
      if (!inviteCode) {
        console.error('❌ Invite code required for gym member registration');
        return res.status(400).json({ error: 'Invite code required for gym member.' });
      }
      const invite = await InviteCode.findOne({ code: inviteCode, used: false });
      if (!invite) {
        console.error('❌ Invalid or expired invite code:', inviteCode);
        return res.status(400).json({ error: 'Invalid or expired invite code.' });
      }
      gymId = invite.gymId;
      if (!gymId) {
        console.error('❌ Invite code does not reference a valid gym:', inviteCode);
        return res.status(400).json({ error: 'Invite code does not reference a valid gym.' });
      }
      invite.used = true;
      invite.usedBy = email;
      invite.updatedAt = new Date();
      await invite.save();
      console.log('✅ Invite code marked as used:', inviteCode);
    }
    // Superadmin registration: no gym
    else if (role === 'superadmin') {
      gymId = null;
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new User({ name, email, password: hashedPassword, role, gymId });
    try {
      await newUser.save();
      console.log('✅ User registered:', newUser);
    } catch (err) {
      console.error('❌ Error saving user:', err);
      return res.status(500).json({ error: 'Failed to save user', details: err.message });
    }
    res.status(201).json({ message: 'User registered successfully.' });
  } catch (err) {
    console.error('❌ Error during registration:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
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
