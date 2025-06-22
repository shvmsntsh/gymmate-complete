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

    // Mark invite code as used using the proper function
    const { markInviteCodeAsUsed } = require('../models/InviteCode');
    await markInviteCodeAsUsed(inviteCode.trim(), email);

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
    console.log('🔐 Authenticated user:', req.user);

    const { role } = req.body;
    console.log('🧾 Incoming role:', role);

    if (!role) {
      return res.status(400).json({ message: 'Role is required' });
    }

    // Validate role
    if (!['gym_owner', 'gym_member'].includes(role)) {
      return res.status(400).json({ message: 'Invalid role. Must be gym_owner or gym_member' });
    }

    // Check permissions
    if (req.user.role === 'gym_owner' && role === 'gym_owner') {
      return res.status(403).json({ message: 'Gym owners cannot create codes for other gym owners' });
    }

    // Generate a random code
    const code = Math.random().toString(36).substring(2, 10).toUpperCase();

    const inviteData = {
      code,
      role,
      used: false,
    };

    // Set gymId based on role and user
    if (role === 'gym_member') {
      if (req.user.role === 'gym_owner') {
        inviteData.gymId = req.user.id; // Gym owner creating code for their gym
      } else if (req.user.role === 'superadmin') {
        // Superadmin needs to specify which gym
        const { gymId } = req.body;
        if (!gymId) {
          return res.status(400).json({ message: 'gymId is required when superadmin creates member codes' });
        }
        inviteData.gymId = gymId;
      }
    } else if (role === 'gym_owner') {
      // Only superadmin can create gym owner codes
      if (req.user.role !== 'superadmin') {
        return res.status(403).json({ message: 'Only superadmin can create gym owner codes' });
      }
      // gymId will be null for gym owner codes (they'll create their own gym)
    }

    const invite = new InviteCode(inviteData);
    await invite.save();

    console.log('✅ Invite code created and saved:', {
      code: invite.code,
      role: invite.role,
      gymId: invite.gymId,
      used: invite.used,
      createdAt: invite.createdAt,
    });

    console.log('📤 Sending response:', { message: 'Invite code generated', code });
    res.status(201).json({ message: 'Invite code generated', code });
  } catch (error) {
    console.error('❌ Error generating invite code:', error);
    res.status(500).json({ message: 'Failed to generate invite code', error: error.message });
  }
};