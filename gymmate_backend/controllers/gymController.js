require('dotenv').config();
const { InviteCode } = require('../models/InviteCode');
const Gym = require('../models/Gym');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

exports.registerGym = async (req, res) => {
  try {
    const { name, email, password, inviteCode } = req.body;
    if (!name?.trim() || !email?.trim() || !inviteCode?.trim()) {
      return res.status(400).json({ message: 'Name, email, and invite code are required' });
    }

    // Check invite code
    const codeDoc = await InviteCode.findOne({ code: inviteCode.trim(), used: false });
    if (!codeDoc) {
      return res.status(400).json({ message: 'Invalid or expired invite code' });
    }

    const role = codeDoc.role;
    const gymId = codeDoc.gymId;

    const gymData = {
      gymName: name.trim(),
      email,
      password,
      role,
    };

    if (role === 'gym_member') {
      gymData.gymId = gymId;
    }

    const gym = new Gym(gymData);

    // Auto-promote first user to superadmin if no users exist
    const totalGyms = await Gym.countDocuments();
    if (totalGyms === 0) {
      gym.role = 'superadmin';
    }

    const savedGym = await gym.save();

    // Mark invite code as used
    codeDoc.used = true;
    await codeDoc.save();

    res.status(201).json({ message: 'Gym registered successfully', gym: savedGym });
  } catch (error) {
    res.status(400).json({ message: 'Error registering gym', error: error.message });
  }
};

exports.loginGym = async (req, res) => {
  const { email, password } = req.body;

  try {
    const gym = await Gym.findOne({ email });
    if (!gym) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    if (password !== gym.password) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    const token = jwt.sign(
      {
        id: gym._id,
        email: gym.email,
        role: gym.role,
        gymId: gym._id,
        gymName: gym.gymName
      },
      process.env.JWT_SECRET,
      { expiresIn: '2h' }
    );

    res.status(200).json({
      message: 'Login successful',
      token: token,
      gymId: gym._id,
      role: gym.role,
      gymName: gym.gymName
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

exports.generateInviteCode = async (req, res) => {
  try {
    console.log('📥 Request to generateInviteCode:', req.body);
    console.log('🔐 Authenticated user:', req.user); // Assuming authMiddleware adds `req.user`

    const { role, gymName } = req.body;
    console.log('🧾 Incoming role:', role);
    console.log('🏋️ Incoming gymName:', gymName);

    if (!role || !gymName) {
      return res.status(400).json({ message: 'Role and gymName are required' });
    }

    // Generate a random code
    const code = Math.random().toString(36).substring(2, 10).toUpperCase();

    const invite = new InviteCode({
      code,
      role,
      gymName,
      used: false,
    });

    await invite.save();
    console.log('✅ Invite code created and saved:', {
      code: invite.code,
      role: invite.role,
      gymName: invite.gymName,
      used: invite.used,
      createdAt: invite.createdAt,
    });

    console.log('📤 Sending response:', { message: 'Invite code generated', code });
    res.status(201).json({ message: 'Invite code generated', code });
  } catch (error) {
    res.status(500).json({ message: 'Failed to generate invite code', error: error.message });
  }
};