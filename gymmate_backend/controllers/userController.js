const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { normalizeRole, hasRole } = require('../utils/roles');

// Secret key for JWT - should be in environment variables
const JWT_SECRET = process.env.JWT_SECRET || 'fallback-secret-key-for-development';

function buildUserPayload(user, gymName = null) {
  const isCompleted =
    user.onboardingProgress &&
    (user.onboardingProgress.isCompleted === true ||
      user.onboardingProgress.isCompleted === 'true');

  return {
    id: user._id,
    name: user.name,
    email: user.email,
    role: user.role,
    normalizedRole: normalizeRole(user.role),
    gymId: user.gymId,
    gymName,
    phone_number: user.phone_number || null,
    hasCompletedOnboarding: Boolean(user.hasCompletedOnboarding || isCompleted),
    profile: user.profile || {},
    fitnessGoals: user.fitnessGoals || [],
    dietPreferences: user.dietPreferences || {},
    workoutHabits: user.workoutHabits || {},
    firstChallenge: user.firstChallenge || {},
  };
}

function buildWeeklySeries(values) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return labels.map((day, index) => ({
    day,
    count: Math.max(0, Number(values[index] || 0)),
  }));
}

function buildMemberProgressSeries(user) {
  const workoutsPerWeek = Number(user?.workoutHabits?.workoutsPerWeek || 4);
  const challengeProgress = Number(user?.firstChallenge?.progress || 0);
  const base = Math.max(1, Math.min(6, workoutsPerWeek));
  const lift = challengeProgress >= 100 ? 1 : 0;

  return buildWeeklySeries([
    Math.max(1, base - 2),
    Math.max(1, base - 1),
    base,
    Math.max(1, base - 1),
    base + lift,
    Math.max(1, base - 2),
    Math.max(1, base - 1),
  ]);
}

async function buildTrainerAttendanceSeries(user) {
  const gymId = user?.gymId;
  const memberCount = gymId
    ? await User.countDocuments({ gymId, role: 'gym_member' })
    : 0;
  const base = Math.max(2, Math.min(8, memberCount || 4));

  return buildWeeklySeries([
    base - 1,
    base,
    base + 1,
    base,
    base + 2,
    base + 1,
    base - 1,
  ]);
}

/**
 * Register a new user (superadmin, gym_owner, or gym_member)
 * This function handles the core logic for user creation based on invitation codes.
 */
exports.register = async (req, res) => {
  let { name, email, password, inviteCode, phone_number } = req.body;
  if (!name || !email || !password || !inviteCode) {
    return res.status(400).json({ message: 'Name, email, password, and invite code are required.' });
  }
  email = email.trim().toLowerCase();
  inviteCode = inviteCode.trim().toUpperCase();

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
      phone_number,
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
      user: buildUserPayload(newUser, null),
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
    phone_number,
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
  let gymName = null;
  if (newUser.gymId) {
    const gym = await Gym.findById(newUser.gymId);
    if (gym) {
      gymName = gym.gymName;
    }
  }

  res.status(201).json({
    message: `User registered successfully as ${code.role}.`,
    token,
    user: buildUserPayload(newUser, gymName),
  });
};

/**
 * Log in an existing user
 * Returns a JWT token for session management.
 */
exports.login = async (req, res) => {
  try {
    let { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required.' });
    }

    email = email.trim().toLowerCase();
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    if (!user.password) {
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    const passwordMatch = await bcrypt.compare(password, user.password);
    if (!passwordMatch) {
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

    return res.json({
      token,
      user: buildUserPayload(user, gymName),
    });
  } catch (error) {
    console.error('❌ Login handler failed:', error);
    return res.status(500).json({ message: 'Internal server error', error: error.message });
  }
};

/**
 * Log in a user with a phone number and OTP
 */
exports.quickLogin = async (req, res) => {
  const { phone_number, otp } = req.body;

  if (!phone_number || !otp) {
    return res.status(400).json({ message: 'Phone number and OTP are required.' });
  }

  // For now, OTP is hardcoded to '1234'
  if (otp !== '1234') {
    return res.status(401).json({ message: 'Invalid OTP.' });
  }

  const user = await User.findOne({ phone_number });

  if (!user) {
    return res.status(404).json({ message: 'No user found with this phone number.' });
  }

  // If the user was only invited, mark them as registered
  if (user.invited && !user.registered) {
    user.registered = true;
    // Since they are logging in without a password, we might not need to set one.
    // Or we could set a default placeholder that they are prompted to change later.
    // For now, we'll leave the password as is (or null if it was never set).
    await user.save({ validateBeforeSave: false });
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

  res.json({
    token,
    user: buildUserPayload(user, gymName),
  });
};


/**
 * Generate an invitation code
 * Only superadmins and gym_owners can do this.
 */
exports.generateInviteCode = async (req, res) => {
  const { roleToGenerate } = req.body;
  const generator = req.user;

  if (!roleToGenerate) {
    return res.status(400).json({ message: 'A target role for the invite code is required.' });
  }

  // Superadmin can create gym_owners (no gymId required)
  if (generator.role === 'superadmin' && roleToGenerate === 'gym_owner') {
    try {
      const code = new InviteCode({
        code: Math.random().toString(36).substring(2, 10).toUpperCase(),
        role: 'gym_owner',
        generatedBy: generator.id,
      });
      await code.save();
      return res.status(201).json({ message: 'Gym owner invite code generated.', inviteCode: code.code });
    } catch (err) {
      console.error('💥 Error saving invite code:', err);
      return res.status(500).json({ message: 'Failed to generate invite code due to a database error.' });
    }
  }

  // Gym owners can create gym_members (must have gymId)
  if (generator.role === 'gym_owner' && roleToGenerate === 'gym_member') {
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
      await code.save();
      return res.status(201).json({ message: 'Gym member invite code generated.', inviteCode: code.code });
    } catch (err) {
      console.error('💥 Error saving invite code:', err);
      return res.status(500).json({ message: 'Failed to generate invite code due to a database error.' });
    }
  }

  return res.status(403).json({ message: 'You do not have permission to generate this type of invite code.' });
};

/**
 * Get members based on user role
 */
exports.getMembers = async (req, res) => {
  try {

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
  if (!hasRole(req.user, ['admin'])) {
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
  if (!hasRole(req.user, ['admin'])) {
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
  
  if (!hasRole(req.user, ['admin'])) {
    return res.status(403).json({ message: 'Forbidden: superadmin only' });
  }

  try {
    const gymsCount = await Gym.countDocuments({});

    const membersCount = await User.countDocuments({ role: 'gym_member' });

    const trainersCount = await User.countDocuments({ role: 'gym_trainer' });

    const invitesCount = await InviteCode.countDocuments({ used: false });

    // Registrations in last 7 days (Mon-Sun)
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const now = new Date();
    // Find the most recent Monday
    const monday = new Date(now);
    const dayOfWeek = monday.getDay(); // 0 (Sun) - 6 (Sat)
    const diffToMonday = (dayOfWeek + 6) % 7; // 0 if Mon, 1 if Tue, ..., 6 if Sun
    monday.setDate(now.getDate() - diffToMonday);
    monday.setHours(0, 0, 0, 0);

    // Get all users created in the last 7 days (members + trainers)
    const weekUsers = await User.find({
      role: { $in: ['gym_member', 'gym_trainer'] },
      createdAt: { $gte: monday }
    }).select('createdAt role');

    const registrations = [];
    for (let i = 0; i < 7; i++) {
      const day = new Date(monday);
      day.setDate(monday.getDate() + i);
      const nextDay = new Date(day);
      nextDay.setDate(day.getDate() + 1);
      const count = weekUsers.filter(u => u.createdAt >= day && u.createdAt < nextDay).length;
      registrations.push({ day: dayNames[i], count });
    }

    const stats = {
      gyms: gymsCount,
      members: membersCount,
      trainers: trainersCount,
      invites: invitesCount,
      registrations
    };

    return res.status(200).json(stats);
  } catch (error) {
    console.error('❌ Error fetching dashboard stats:', error);
    return res.status(500).json({ message: 'Error fetching dashboard stats' });
  }
};

exports.getMemberProgressParticipation = async (req, res) => {
  if (!hasRole(req.user, ['member'])) {
    return res.status(403).json({ message: 'Forbidden: gym members only' });
  }

  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.status(200).json({
      progressParticipation: buildMemberProgressSeries(user),
    });
  } catch (error) {
    console.error('Error fetching member progress participation:', error);
    return res.status(500).json({ message: 'Error fetching member progress participation' });
  }
};

exports.getTrainerAttendanceProgress = async (req, res) => {
  if (!hasRole(req.user, ['trainer'])) {
    return res.status(403).json({ message: 'Forbidden: trainers only' });
  }

  try {
    const user = await User.findById(req.user.id).select('gymId');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.status(200).json({
      attendanceProgress: await buildTrainerAttendanceSeries(user),
    });
  } catch (error) {
    console.error('Error fetching trainer attendance/progress:', error);
    return res.status(500).json({ message: 'Error fetching trainer attendance/progress' });
  }
};

const getUserProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select('-password');
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    let gymName = null;
    if (user.gymId) {
      const gym = await Gym.findById(user.gymId).select('gymName');
      if (gym) {
        gymName = gym.gymName;
      }
    }

    const isCompleted =
      user.onboardingProgress &&
      (user.onboardingProgress.isCompleted === true ||
        user.onboardingProgress.isCompleted === 'true');

    res.json({
      ...user.toObject(),
      normalizedRole: normalizeRole(user.role),
      gymName,
      hasCompletedOnboarding: isCompleted || user.hasCompletedOnboarding === true,
    });
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
  try {
    const user = await User.findById(req.user.id);
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }

    if (!user.onboardingProgress) {
      user.onboardingProgress = {
        isCompleted: false,
        currentStep: 0,
        stepsCompleted: [],
        startedAt: null,
        completedAt: null,
        totalSteps: 7,
      };
    }

    const shouldComplete = req.body.isCompleted !== false;

    user.onboardingProgress.isCompleted = shouldComplete;
    user.onboardingProgress.currentStep = shouldComplete ? 7 : user.onboardingProgress.currentStep || 0;
    user.onboardingProgress.totalSteps = 7;

    if (shouldComplete) {
      user.onboardingProgress.completedAt = new Date();
      user.onboardingProgress.startedAt = user.onboardingProgress.startedAt || new Date();
      user.onboardingProgress.stepsCompleted = [1, 2, 3, 4, 5, 6, 7];
      user.hasCompletedOnboarding = true;
    } else {
      user.onboardingProgress.completedAt = null;
      user.hasCompletedOnboarding = false;
    }

    await user.save();

    return res.status(200).json({
      message: shouldComplete
        ? 'Onboarding completed successfully.'
        : 'Onboarding status updated.',
      hasCompletedOnboarding: user.hasCompletedOnboarding,
      onboardingProgress: user.onboardingProgress,
    });
  } catch (error) {
    console.error('Onboarding completion error:', error);
    return res.status(500).json({ message: 'Server error while updating onboarding.' });
  }
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
        normalizedRole: normalizeRole(user.role),
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
    res.json(buildUserPayload(user, gymName));
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
    if (!hasRole(user, ['trainer', 'owner'])) {
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

/**
 * Get dashboard stats for a gym (for gym_owner)
 */
exports.getGymDashboardStats = async (req, res) => {
  try {
    if (!hasRole(req.user, ['owner'])) {
      return res.status(403).json({ message: 'Forbidden: gym_owner only' });
    }
    const gymId = req.user.gymId;
    // Get all users for this gym
    const users = await require('../models/User').find({ gymId });
    // Only count trainers and members for registrations
    const trainersAndMembers = users.filter(u => u.role === 'gym_trainer' || u.role === 'gym_member');
    // Registrations in last 7 days (always Mon-Sun order)
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // Find the date for the most recent Monday
    const now = new Date();
    const monday = new Date(now);
    const dayOfWeek = monday.getDay(); // 0 (Sun) - 6 (Sat)
    // If today is not Monday, go back to the most recent Monday
    const diffToMonday = (dayOfWeek + 6) % 7; // 0 if Mon, 1 if Tue, ..., 6 if Sun
    monday.setDate(now.getDate() - diffToMonday);
    monday.setHours(0, 0, 0, 0);
    const registrations = [];
    for (let i = 0; i < 7; i++) {
      const day = new Date(monday);
      day.setDate(monday.getDate() + i);
      const nextDay = new Date(day);
      nextDay.setDate(day.getDate() + 1);
      const count = trainersAndMembers.filter(u => u.createdAt >= day && u.createdAt < nextDay).length;
      registrations.push({ day: dayNames[i], count });
    }
    res.status(200).json({ membersCount: trainersAndMembers.length, trainersCount: users.filter(u => u.role === 'gym_trainer').length, registrations });
  } catch (error) {
    console.error('❌ Error fetching gym dashboard stats:', error);
    res.status(500).json({ message: 'Error fetching gym dashboard stats', error: error.message });
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
  getMemberProgressParticipation: exports.getMemberProgressParticipation,
  getTrainerAttendanceProgress: exports.getTrainerAttendanceProgress,
  updateProfile: exports.updateProfile,
  getMe: exports.getMe,
  getGymMembers: exports.getGymMembers,
  getGymDashboardStats: exports.getGymDashboardStats,
  quickLogin: exports.quickLogin,
};
