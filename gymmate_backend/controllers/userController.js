const User = require('../models/User');
const Gym = require('../models/Gym');
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
  let { name, email, password, inviteCode } = req.body;
  if (!name || !email || !password || !inviteCode) {
    return res.status(400).json({ message: 'Name, email, password, and invite code are required.' });
  }
  email = email.trim().toLowerCase();

  // Handle the very first superadmin registration
  if (inviteCode === '123456') {
    const userCount = await User.countDocuments();
    if (userCount > 0) {
      return res.status(403).json({ message: 'Superadmin already exists.' });
    }
    // Check for duplicate email
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'An account with this email already exists.' });
    }
    // DO NOT hash password here, let pre-save hook handle it
    const newUser = new User({
      name,
      email,
      password, // plain password
      role: 'superadmin',
    });
    await newUser.save();
    // Generate token and return user object (like login)
    const token = jwt.sign(
      {
        id: newUser._id,
        email: newUser.email,
        role: newUser.role,
        gymId: newUser.gymId,
      },
      JWT_SECRET,
      { expiresIn: '2h' }
    );
    return res.status(201).json({
      message: 'Superadmin registered successfully.',
      token,
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        role: newUser.role,
        gymId: newUser.gymId,
      },
    });
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
  const newUser = new User({
    name,
    email,
    password, // plain password
    role: code.role,
    gymId: code.gymId,
  });
  await newUser.save();
  // If the new user is a gym owner, their gymId should be their own ID.
  if (newUser.role === 'gym_owner' && !newUser.gymId) {
    try {
      const gymName = req.body.gymName || `${newUser.name}'s Gym`;
      const gym = new Gym({
        gymName,
        email: newUser.email,
        owner: newUser._id,
      });
      await gym.save();
      newUser.gymId = gym._id;
      await newUser.save();
      console.log(`✅ Created gym ${gym._id} for gym_owner ${newUser.email}`);
    } catch (err) {
      console.error('❌ Failed to create gym for gym_owner:', err);
      // Optionally, remove the user if gym creation fails
      await User.findByIdAndDelete(newUser._id);
      return res.status(500).json({ message: 'Failed to create gym for gym owner. Registration aborted.' });
    }
  }
  // Mark the code as used atomically
  code.used = true;
  code.usedBy = newUser._id;
  await code.save();
  // Generate token and return user object (like login)
  const token = jwt.sign(
    {
      id: newUser._id,
      email: newUser.email,
      role: newUser.role,
      gymId: newUser.gymId,
    },
    JWT_SECRET,
    { expiresIn: '2h' }
  );
  res.status(201).json({
    message: `User registered successfully as ${code.role}.`,
    token,
    user: {
      id: newUser._id,
      name: newUser.name,
      email: newUser.email,
      role: newUser.role,
      gymId: newUser.gymId,
    },
  });
};

/**
 * Log in an existing user
 * Returns a JWT token for session management.
 */
exports.login = async (req, res) => {
  console.log('🔑 /api/auth/login endpoint hit');
  let { email, password } = req.body;
  console.log('Login attempt:', { email });
  if (!email || !password) {
    console.log('❌ Missing email or password');
    return res.status(400).json({ message: 'Email and password are required.' });
  }
  email = email.trim().toLowerCase();
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
  let gymName = null;
  if (user.gymId) {
    const gym = await Gym.findById(user.gymId);
    if (gym) {
      gymName = gym.gymName;
    }
  }
  const token = jwt.sign(
    {
      id: user._id,
      email: user.email,
      role: user.role,
      gymId: user.gymId,
      gymName: gymName,
    },
    JWT_SECRET,
    { expiresIn: '2h' }
  );
  console.log('✅ Login successful for', email);
  const isCompleted = user.onboardingProgress && (user.onboardingProgress.isCompleted === true || user.onboardingProgress.isCompleted === 'true');
  const userPayload = {
      id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      gymId: user.gymId,
      gymName: gymName,
      hasCompletedOnboarding: isCompleted,
  };
  console.log('📦 Sending user payload:', JSON.stringify(userPayload, null, 2));
  res.json({
    token,
    user: userPayload,
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

  // Superadmin can create gym_owners (no gymId required)
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

  // Gym owners can create gym_members (must have gymId)
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

/**
 * Get categorized members (superadmin only)
 * Returns a list of gym owners with their respective members
 */
exports.getCategorizedMembers = async (req, res) => {
  if (req.user.role !== 'superadmin') {
    return res.status(403).json({ message: 'Forbidden: superadmin only' });
  }

  try {
    // First, get all gym owners
    const gymOwners = await User.find({ role: 'gym_owner' }).select('name email gymId');
    
    // For each gym owner, get their gym details and members
    const categorizedData = await Promise.all(gymOwners.map(async (owner) => {
      const gym = await Gym.findById(owner.gymId);
      const members = await User.find({ 
        role: 'gym_member', 
        gymId: owner.gymId 
      }).select('name email createdAt');

      return {
        gymName: gym?.gymName || 'Unknown Gym',
        ownerName: owner.name,
        ownerEmail: owner.email,
        members: members.map(member => ({
          name: member.name,
          email: member.email,
          joinDate: member.createdAt
        }))
      };
    }));

    return res.status(200).json({ gymOwners: categorizedData });
  } catch (error) {
    console.error('Error fetching categorized members:', error);
    return res.status(500).json({ message: 'Error fetching categorized members' });
  }
};

/**
 * Get dashboard statistics (superadmin only)
 */
exports.getDashboardStats = async (req, res) => {
  console.log('🔍 Fetching dashboard stats for superadmin');
  
  if (req.user.role !== 'superadmin') {
    console.log('❌ Unauthorized access attempt:', req.user.role);
    return res.status(403).json({ message: 'Forbidden: superadmin only' });
  }

  try {
    const gymsCount = await User.countDocuments({ role: 'gym_owner' });
    console.log('📊 Total gyms:', gymsCount);

    const membersCount = await User.countDocuments({ role: 'gym_member' });
    console.log('📊 Total members:', membersCount);

    const invitesCount = await InviteCode.countDocuments({ used: false });
    console.log('📊 Active invites:', invitesCount);

    // Log the query we're using
    console.log('🔍 Querying active members with:', {
      role: 'gym_member',
      hasCompletedOnboarding: true
    });

    // First, let's find all such users to inspect
    const activeMembers = await User.find({ 
      role: 'gym_member',
      hasCompletedOnboarding: true
    });
    console.log('📊 Active members found:', activeMembers.length);
    console.log('📄 Active members details:', activeMembers.map(m => ({
      email: m.email,
      hasCompletedOnboarding: m.hasCompletedOnboarding
    })));

    const activeMembersCount = activeMembers.length;

    const stats = {
      gyms: gymsCount,
      members: membersCount,
      invites: invitesCount,
      activeMembers: activeMembersCount
    };

    console.log('📤 Sending stats:', stats);
    return res.status(200).json(stats);
  } catch (error) {
    console.error('❌ Error fetching dashboard stats:', error);
    return res.status(500).json({ message: 'Error fetching dashboard stats' });
  }
};

const getUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

const getUserDetailsForPlan = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('profile fitnessGoals dietPreferences workoutHabits');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    console.error('Error fetching user details for plan:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

const updateOnboardingStatus = async (req, res) => {
  // ... existing code ...
};

// Update profile (name/email)
exports.updateProfile = async (req, res) => {
  try {
    const userId = req.user.id;
    let { name, email } = req.body;
    if (!name || typeof name !== 'string' || name.trim().length < 2) {
      return res.status(400).json({ message: 'Name must be at least 2 characters.' });
    }
    if (!email || typeof email !== 'string' || !/^\S+@\S+\.\S+$/.test(email)) {
      return res.status(400).json({ message: 'A valid email is required.' });
    }
    email = email.trim().toLowerCase();
    // Check if email is unique (except for current user)
    const existing = await User.findOne({ email });
    if (existing && existing._id.toString() !== userId) {
      return res.status(400).json({ message: 'Email is already in use.' });
    }
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'User not found.' });
    user.name = name.trim();
    user.email = email;
    await user.save();
    return res.json({
      message: 'Profile updated successfully.',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        gymId: user.gymId,
      },
    });
  } catch (err) {
    console.error('Profile update error:', err);
    return res.status(500).json({ message: 'Server error during profile update.' });
  }
};

// Get current user profile by token
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found.' });
    let gymName = null;
    if (user.gymId) {
      const gym = await Gym.findById(user.gymId);
      if (gym) gymName = gym.gymName;
    }
    res.json({
      id: user._id,
      name: user.name,
      email: user.email,
      role: user.role,
      gymId: user.gymId,
      gymName,
      hasCompletedOnboarding: user.hasCompletedOnboarding,
    });
  } catch (err) {
    console.error('GetMe error:', err);
    res.status(500).json({ message: 'Server error.' });
  }
};

// Get all gym members for the trainer's gym
exports.getGymMembers = async (req, res) => {
  try {
    const user = req.user;
    if (!user || !user.gymId) {
      return res.status(400).json({ message: 'User or gymId missing.' });
    }
    if (!['gym_trainer', 'gym_owner'].includes(user.role)) {
      return res.status(403).json({ message: 'Forbidden: Only trainers or owners can view gym members.' });
    }
    const members = await require('../models/User').find({
      gymId: user.gymId,
      role: 'gym_member',
    }).select('name email _id');
    res.status(200).json({ members });
  } catch (err) {
    console.error('❌ Error fetching gym members:', err);
    res.status(500).json({ message: 'Server error fetching gym members.' });
  }
};

module.exports = {
  register: exports.register,
  login: exports.login,
  generateInviteCode: exports.generateInviteCode,
  getInviteCodes: exports.getInviteCodes,
  getUserProfile,
  updateOnboardingStatus,
  getUserDetailsForPlan,
  getDashboardStats: exports.getDashboardStats,
  getCategorizedMembers: exports.getCategorizedMembers,
  updateProfile: exports.updateProfile,
  getMe: exports.getMe,
  getGymMembers: exports.getGymMembers,
};
