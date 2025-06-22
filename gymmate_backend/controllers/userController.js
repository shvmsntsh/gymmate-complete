const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

// Secret key for JWT - should be in environment variables
const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret-key-for-development';

/**
 * Register a new user (superadmin, gym_owner, or gym_member)
 * This function handles the core logic for user creation based on invitation codes.
 */
exports.register = async (req, res) => {
  const { name, email, password, inviteCode } = req.body;

  if (!name || !email || !password || !inviteCode) {
    return res.status(400).json({ message: 'Name, email, password, and invite code are required.' });
  }

  // Handle the very first superadmin registration
  if (inviteCode === '123456') {
    const userCount = await User.countDocuments();
    if (userCount > 0) {
      return res.status(403).json({ message: 'Superadmin already exists.' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = new User({
      name,
      email,
      password: hashedPassword,
      role: 'superadmin',
    });

    await newUser.save();
    return res.status(201).json({ message: 'Superadmin registered successfully.' });
  }

  // For all other users, validate the invite code
  const code = await InviteCode.findOne({ code: inviteCode });

  if (!code || code.used) {
    return res.status(400).json({ message: 'Invalid or already used invitation code.' });
  }

  const existingUser = await User.findOne({ email });
  if (existingUser) {
    return res.status(400).json({ message: 'An account with this email already exists.' });
  }

  const hashedPassword = await bcrypt.hash(password, 10);

  const newUser = new User({
    name,
    email,
    password: hashedPassword,
    role: code.role,
    gymId: code.gymId,
  });

  await newUser.save();

  // If the new user is a gym owner, their gymId should be their own ID.
  if (newUser.role === 'gym_owner' && !newUser.gymId) {
    newUser.gymId = newUser._id;
    await newUser.save();
    console.log(`🔗 Assigned gymId ${newUser._id} to new gym_owner ${newUser.email}`);
  }

  // Mark the code as used atomically
  code.used = true;
  code.usedBy = newUser._id;
  await code.save();

  res.status(201).json({ message: `User registered successfully as ${code.role}.` });
};

/**
 * Log in an existing user
 * Returns a JWT token for session management.
 */
exports.login = async (req, res) => {
  console.log('🔑 /api/auth/login endpoint hit');
  const { email, password } = req.body;
  console.log('Login attempt:', { email });

  if (!email || !password) {
    console.log('❌ Missing email or password');
    return res.status(400).json({ message: 'Email and password are required.' });
  }

  const user = await User.findOne({ email });
  if (!user) {
    console.log('❌ User not found');
    return res.status(401).json({ message: 'Invalid credentials.' });
  }

  const passwordMatch = await bcrypt.compare(password, user.password);
  console.log('Password match:', passwordMatch);
  if (!passwordMatch) {
    console.log('❌ Invalid password');
    return res.status(401).json({ message: 'Invalid credentials.' });
  }

  const token = jwt.sign(
    {
      id: user._id,
      email: user.email,
      role: user.role,
      gymId: user.gymId,
    },
    JWT_SECRET,
    { expiresIn: '2h' }
  );

  console.log('✅ Login successful for', email);
  res.json({
    token,
    user: {
      id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      gymId: user.gymId,
    },
  });
};

/**
 * Generate an invitation code
 * Only superadmins and gym_owners can do this.
 */
exports.generateInviteCode = async (req, res) => {
  console.log('✅ Received request to /api/auth/invite/generate');
  const { roleToGenerate } = req.body;
  const generator = req.user;
  console.log(`👤 Generator: ${generator.email} (Role: ${generator.role})`);
  console.log(`✨ Generating code for role: ${roleToGenerate}`);

  if (!roleToGenerate) {
    console.log('❌ Missing target role');
    return res.status(400).json({ message: 'A target role for the invite code is required.' });
  }

  // Superadmin can create gym_owners
  if (generator.role === 'superadmin' && roleToGenerate === 'gym_owner') {
    console.log('🔑 Superadmin generating gym_owner code...');
    try {
      const code = new InviteCode({
        code: Math.random().toString(36).substring(2, 10).toUpperCase(),
        role: 'gym_owner',
        generatedBy: generator.id,
      });
      console.log('💾 Saving new invite code to database...');
      await code.save();
      console.log('✅ Invite code saved successfully:', code.code);
      return res.status(201).json({ message: 'Gym owner invite code generated.', inviteCode: code.code });
    } catch (err) {
      console.error('💥 Error saving invite code:', err);
      return res.status(500).json({ message: 'Failed to generate invite code due to a database error.' });
    }
  }

  // Gym owners can create gym_members
  if (generator.role === 'gym_owner' && roleToGenerate === 'gym_member') {
    console.log('🔑 Gym owner generating gym_member code...');
    if (!generator.gymId) {
      console.error(`❌ Logic Error: Gym Owner ${generator.email} has no gymId.`);
      return res.status(500).json({ message: 'Could not generate code: Gym Owner has no associated Gym ID.' });
    }
    try {
      const code = new InviteCode({
        code: Math.random().toString(36).substring(2, 10).toUpperCase(),
        role: 'gym_member',
        gymId: generator.gymId,
        generatedBy: generator.id,
      });
      console.log(`💾 Saving new invite code for gymId ${generator.gymId}...`);
      await code.save();
      console.log('✅ Invite code saved successfully:', code.code);
      return res.status(201).json({ message: 'Gym member invite code generated.', inviteCode: code.code });
    } catch (err) {
      console.error('💥 Error saving invite code:', err);
      return res.status(500).json({ message: 'Failed to generate invite code due to a database error.' });
    }
  }

  console.log(`🚫 Permission denied for ${generator.role} to generate ${roleToGenerate} code.`);
  return res.status(403).json({ message: 'You do not have permission to generate this type of invite code.' });
};

/**
 * Get members based on user role
 */
exports.getMembers = async (req, res) => {
  try {
    console.log(`🔎 Fetching members for role: ${req.user.role}, gymId: ${req.user.gymId}`);

    let users;
    if (req.user.role === 'superadmin') {
      users = await User.find({});
    } else if (req.user.role === 'gym_owner') {
      users = await User.find({ role: 'gym_member', gymId: req.user.gymId });
    } else if (req.user.role === 'gym_member') {
      users = await User.find({ _id: req.user.id });
    } else {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    res.status(200).json({ members: users });
  } catch (error) {
    console.error('❌ Error fetching members:', error);
    res.status(500).json({ message: 'Error fetching members', error: error.message });
  }
};

/**
 * Get all members (superadmin only)
 */
exports.getAllMembers = async (req, res) => {
  if (req.user.role !== 'superadmin') {
    return res.status(403).json({ message: 'Forbidden: superadmin only' });
  }
  try {
    const users = await User.find({});
    return res.status(200).json({ members: users });
  } catch (error) {
    console.error('Error fetching all members:', error);
    return res.status(500).json({ message: 'Error fetching all members' });
  }
};

/**
 * Get current user's own data
 */
exports.getSelf = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.status(200).json({ member: user });
  } catch (error) {
    console.error('❌ Error fetching self user info:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
};
