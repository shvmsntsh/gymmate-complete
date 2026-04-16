const User = require('../models/User');
const Gym = require('../models/Gym');
const { InviteCode } = require('../models/InviteCode');
const DailyPlanLog = require('../models/DailyPlanLog');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { normalizeRole, hasRole } = require('../utils/roles');
const { getJwtSecret } = require('../utils/jwt');
const { normalizeIndianPhone, indianPhoneVariants, looksLikeEmail } = require('../utils/phone');

const VALID_AVATARS = new Set([
  'assets/avatars/o_m_1.png',
  'assets/avatars/o_f_1.png',
  'assets/avatars/t_m_1.png',
  'assets/avatars/t_f_1.png',
  'assets/avatars/m_m_1.png',
  'assets/avatars/m_f_1.png',
  'assets/avatars/staff_m_1.png',
  'assets/avatars/staff_f_1.png',
]);

function getAvatarPath(user) {
  return user?.profile?.avatar || user?.profile?.profilePicture || null;
}

function createToken(user, gymName = null) {
  return jwt.sign(
    {
      id: user._id,
      email: user.email,
      role: user.role,
      gymId: user.gymId,
      gymName,
    },
    getJwtSecret(),
    { expiresIn: '2h' },
  );
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeInviteCode(value) {
  return String(value || '').trim().toUpperCase();
}

function normalizePhone(value) {
  return normalizeIndianPhone(value) || String(value || '').trim();
}

function isValidEmail(value) {
  return /^\S+@\S+\.\S+$/.test(String(value || '').trim());
}

function memberPhoneQuery(value) {
  const variants = indianPhoneVariants(value);
  return variants.length
    ? { phone_number: { $in: variants } }
    : { phone_number: String(value || '').trim() };
}

async function getGymNameForUser(user) {
  if (!user?.gymId) return null;
  const gym = await Gym.findById(user.gymId).select('gymName');
  return gym?.gymName || null;
}

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
    hasPassword: Boolean(user.password),
    avatarPath: getAvatarPath(user),
    accountStatus: user.accountStatus || 'active',
    staffCapabilities: user.staffCapabilities || {},
    telegramProfile: user.telegramProfile || {},
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

async function buildMemberProgressSeries(user) {
  const memberId = user._id;
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const today = new Date();
  const dayOfWeek = today.getDay();
  const monday = new Date(today);
  monday.setDate(today.getDate() - ((dayOfWeek + 6) % 7));
  monday.setHours(0, 0, 0, 0);

  const localDateString = (date) => {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  };

  const weekLogs = await DailyPlanLog.find({
    memberId,
    date: {
      $gte: localDateString(monday),
      $lte: localDateString(today),
    },
  }).select('date');

  const logCounts = {};
  weekLogs.forEach((log) => {
    const date = new Date(log.date + 'T00:00:00');
    const dayName = dayNames[date.getDay() === 0 ? 6 : date.getDay() - 1];
    logCounts[dayName] = (logCounts[dayName] || 0) + 1;
  });

  return dayNames.map((day) => ({
    day,
    count: logCounts[day] || 0,
  }));
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
  email = normalizeEmail(email);
  inviteCode = normalizeInviteCode(inviteCode);
  phone_number = normalizePhone(phone_number);

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
    const token = createToken(newUser, null);
    return res.status(201).json({
      message: 'Superadmin registered successfully.',
      token,
      user: buildUserPayload(newUser, null),
    });
  }

  // For all other users, validate the invite code
  const code = await InviteCode.findOneAndUpdate(
    { code: inviteCode, used: false },
    { $set: { used: true, usedAt: new Date() } },
    { new: true },
  );
  if (!code) {
    return res.status(400).json({ message: 'Invalid or already used invitation code.' });
  }
  if (code.role === 'gym_member') {
    if (!isValidEmail(email)) {
      await InviteCode.updateOne(
        { _id: code._id, usedBy: null },
        { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
      );
      return res.status(400).json({ message: 'A valid email is required for members.' });
    }
    if (!normalizeIndianPhone(phone_number)) {
      await InviteCode.updateOne(
        { _id: code._id, usedBy: null },
        { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
      );
      return res.status(400).json({ message: 'A valid Indian phone number is required for members.' });
    }
  }
  if (code.gymId) {
    const inviteGym = await Gym.findById(code.gymId).select('status');
    if (!inviteGym || inviteGym.status !== 'active') {
      await InviteCode.updateOne(
        { _id: code._id, usedBy: null },
        { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
      );
      return res.status(403).json({ message: 'This gym account is not active.' });
    }
  }
  const placeholderQuery = {
    role: code.role,
    invited: true,
    registered: false,
    $or: [
      { inviteCodeId: code._id },
      ...(phone_number ? [memberPhoneQuery(phone_number)] : []),
      ...(code.inviteePhone ? [memberPhoneQuery(code.inviteePhone)] : []),
    ],
  };
  if (code.gymId) placeholderQuery.gymId = code.gymId;

  let user = await User.findOne(placeholderQuery);
  const existingUser = await User.findOne({ email });
  if (existingUser && (!user || existingUser._id.toString() !== user._id.toString())) {
    await InviteCode.updateOne(
      { _id: code._id, usedBy: null },
      { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
    );
    return res.status(400).json({ message: 'An account with this email already exists.' });
  }

  if (user) {
    user.name = name;
    user.email = email;
    user.password = password;
    user.phone_number = phone_number || user.phone_number || code.inviteePhone || null;
    user.invited = false;
    user.registered = true;
    user.registeredFromInviteAt = new Date();
    user.registrationMethod = 'invite_registration';
    user.inviteCodeId = code._id;
    user.inviteCode = code.code;
  } else {
    user = new User({
      name,
      email,
      password,
      role: code.role,
      gymId: code.gymId,
      phone_number,
      invited: false,
      registered: true,
      registeredFromInviteAt: new Date(),
      registrationMethod: 'invite_registration',
      inviteCodeId: code._id,
      inviteCode: code.code,
    });
  }
  await user.save();
  // If the new user is a gym owner, their gymId should be their own ID.
  if (user.role === 'gym_owner' && !user.gymId) {
    try {
      const gymName = req.body.gymName || `${user.name}'s Gym`;
      const gym = new Gym({
        gymName,
        email: user.email,
        owner: user._id,
      });
      await gym.save();
      user.gymId = gym._id;
      await user.save();
    } catch (err) {
      console.error('❌ Failed to create gym for gym_owner:', err);
      await User.findByIdAndDelete(user._id);
      await InviteCode.updateOne(
        { _id: code._id },
        { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
      );
      return res.status(500).json({ message: 'Failed to create gym for gym owner. Registration aborted.' });
    }
  }
  code.usedBy = user._id;
  code.updatedAt = new Date();
  await code.save();
  // Generate token and return user object (like login)
  const gymName = await getGymNameForUser(user);
  const token = createToken(user, gymName);

  res.status(201).json({
    message: `User registered successfully as ${code.role}.`,
    token,
    user: buildUserPayload(user, gymName),
  });
};

/**
 * Log in an existing user
 * Returns a JWT token for session management.
 */
exports.login = async (req, res) => {
  try {
    let { email, identifier, password } = req.body;
    let loginIdentifier = identifier || email;

    if (!loginIdentifier || !password) {
      return res.status(400).json({ message: 'Email or phone and password are required.' });
    }

    loginIdentifier = String(loginIdentifier).trim();
    const user = looksLikeEmail(loginIdentifier)
      ? await User.findOne({ email: normalizeEmail(loginIdentifier) })
      : await User.findOne(memberPhoneQuery(loginIdentifier));
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials.' });
    }
    if (user.accountStatus === 'deactivated') {
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
        if (gym.status !== 'active') {
          return res.status(403).json({ message: 'Gym account is inactive.' });
        }
        gymName = gym.gymName;
      }
    }

    const token = createToken(user, gymName);

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
 * First-time invite access with phone number and access code.
 */
exports.quickLogin = async (req, res) => {
  const phone_number = normalizePhone(req.body.phone_number);
  const accessCode = normalizeInviteCode(req.body.accessCode || req.body.inviteCode || req.body.otp);

  if (!phone_number || !accessCode) {
    return res.status(400).json({ message: 'Phone number and access code are required.' });
  }

  const invite = await InviteCode.findOneAndUpdate(
    {
      code: accessCode,
      inviteePhone: { $in: indianPhoneVariants(phone_number) },
      role: { $in: ['gym_member', 'gym_trainer'] },
      used: false,
    },
    { $set: { used: true, usedAt: new Date() } },
    { new: true },
  );

  if (!invite) {
    return res.status(401).json({ message: 'Invalid phone number or access code.' });
  }
  if (invite.gymId) {
    const gym = await Gym.findById(invite.gymId).select('status');
    if (!gym || gym.status !== 'active') {
      await InviteCode.updateOne(
        { _id: invite._id },
        { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
      );
      return res.status(401).json({ message: 'Invalid phone number or access code.' });
    }
  }

  let user = await User.findOne({
    role: invite.role,
    invited: true,
    registered: false,
    $or: [{ inviteCodeId: invite._id }, { phone_number }],
  });

  if (!user) {
    user = new User({
      name: invite.inviteeName || 'GymMate Invite',
      email: normalizeEmail(invite.inviteeEmail),
      phone_number,
      role: invite.role,
      gymId: invite.gymId,
      invited: true,
      registered: false,
    });
  }

  if (!user.email) {
    await InviteCode.updateOne(
      { _id: invite._id },
      { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
    );
    return res.status(401).json({ message: 'Invalid phone number or access code.' });
  }
  if (user.accountStatus === 'deactivated') {
    await InviteCode.updateOne(
      { _id: invite._id },
      { $set: { used: false, usedAt: null }, $unset: { usedBy: 1 } },
    );
    return res.status(401).json({ message: 'Invalid phone number or access code.' });
  }

  user.name = user.name || invite.inviteeName || 'GymMate Invite';
  user.phone_number = phone_number;
  user.invited = false;
  user.registered = true;
  user.registeredFromInviteAt = new Date();
  user.registrationMethod = 'first_time_invite_access';
  user.inviteCodeId = invite._id;
  user.inviteCode = invite.code;
  await user.save({ validateBeforeSave: false });

  invite.usedBy = user._id;
  invite.updatedAt = new Date();
  await invite.save();

  const gymName = await getGymNameForUser(user);
  const token = createToken(user, gymName);

  return res.json({
    token,
    user: buildUserPayload(user, gymName),
  });
};

exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!newPassword || String(newPassword).length < 6) {
      return res.status(400).json({ message: 'New password must be at least 6 characters.' });
    }

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found.' });

    if (user.password) {
      if (!currentPassword) {
        return res.status(400).json({ message: 'Current password is required.' });
      }
      const matches = await bcrypt.compare(currentPassword, user.password);
      if (!matches) {
        return res.status(401).json({ message: 'Invalid current password.' });
      }
    }

    user.password = newPassword;
    await user.save();
    return res.status(200).json({ message: 'Password updated.', hasPassword: true });
  } catch (error) {
    console.error('Password update error:', error);
    return res.status(500).json({ message: 'Server error while updating password.' });
  }
};

exports.updateAvatar = async (req, res) => {
  try {
    const avatar = String(req.body.avatar || '').trim();
    if (!VALID_AVATARS.has(avatar)) {
      return res.status(400).json({ message: 'Choose a valid avatar.' });
    }

    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ message: 'User not found.' });

    user.profile = user.profile || {};
    user.profile.avatar = avatar;
    await user.save();

    return res.status(200).json({ message: 'Avatar updated.', avatarPath: avatar });
  } catch (error) {
    console.error('Avatar update error:', error);
    return res.status(500).json({ message: 'Server error while updating avatar.' });
  }
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

  // Gym owners can create gym_members, gym_trainers, and gym_staff (must have gymId)
  if (
    generator.role === 'gym_owner' &&
    ['gym_member', 'gym_trainer', 'gym_staff'].includes(roleToGenerate)
  ) {
    if (!generator.gymId) {
      console.error(`❌ Logic Error: Gym Owner ${generator.email} has no gymId.`);
      return res.status(500).json({ message: 'Could not generate code: Gym Owner has no associated Gym ID.' });
    }
    try {
      const code = new InviteCode({
        code: Math.random().toString(36).substring(2, 10).toUpperCase(),
        role: roleToGenerate,
        gymId: generator.gymId,
        generatedBy: generator.id,
      });
      await code.save();
      return res.status(201).json({ message: `${roleToGenerate} invite code generated.`, inviteCode: code.code });
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

    const ownersCount = await User.countDocuments({ role: 'gym_owner' });

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
      owners: ownersCount,
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
      progressParticipation: await buildMemberProgressSeries(user),
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
    const user = await User.findById(req.user.id);
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

    const userObject = user.toObject();
    delete userObject.password;
    res.json({
      ...userObject,
      normalizedRole: normalizeRole(user.role),
      gymName,
      avatarPath: getAvatarPath(user),
      hasPassword: Boolean(user.password),
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

const uploadProfilePicture = async (req, res) => {
  try {
    const userId = req.user.id;
    const { imageData } = req.body;

    if (!imageData || typeof imageData !== 'string') {
      return res.status(400).json({ message: 'Image data is required.' });
    }

    if (!imageData.startsWith('data:image/')) {
      return res.status(400).json({ message: 'Invalid image format.' });
    }

    const maxSizeBytes = 2 * 1024 * 1024;
    const base64Data = imageData.replace(/^data:image\/\w+;base64,/, '');
    if (Buffer.from(base64Data, 'base64').length > maxSizeBytes) {
      return res.status(400).json({ message: 'Image size must be under 2MB.' });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }

    user.profile = user.profile || {};
    user.profile.profilePicture = imageData;
    await user.save();

    return res.status(200).json({
      message: 'Profile picture updated.',
      profilePicture: imageData,
    });
  } catch (error) {
    console.error('Profile picture upload error:', error);
    return res.status(500).json({ message: 'Server error while uploading profile picture.' });
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
    let gymName = null;
    if (user.gymId) {
      const gym = await Gym.findById(user.gymId);
      if (gym) {
        gymName = gym.gymName;
      }
    }
    const token = createToken(user, gymName);
    return res.json({
      message: 'Profile updated successfully.',
      token,
      user: buildUserPayload(user, gymName),
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
    const [users, openInvites, gym] = await Promise.all([
      require('../models/User').find({ gymId }),
      InviteCode.find({ gymId, used: false }),
      Gym.findById(gymId).lean(),
    ]);

    const members = users.filter((u) => u.role === 'gym_member');
    const trainers = users.filter((u) => u.role === 'gym_trainer');
    const trainersAndMembers = [...members, ...trainers];

    // Registrations in last 7 days (always Mon-Sun order)
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const now = new Date();
    const monday = new Date(now);
    const dayOfWeek = monday.getDay();
    const diffToMonday = (dayOfWeek + 6) % 7;
    monday.setDate(now.getDate() - diffToMonday);
    monday.setHours(0, 0, 0, 0);

    const registrations = [];
    for (let i = 0; i < 7; i++) {
      const day = new Date(monday);
      day.setDate(monday.getDate() + i);
      const nextDay = new Date(day);
      nextDay.setDate(day.getDate() + 1);
      const count = trainersAndMembers.filter(
        (u) => u.createdAt >= day && u.createdAt < nextDay,
      ).length;
      registrations.push({ day: dayNames[i], count });
    }

    const weeklySignups = registrations.reduce(
      (sum, entry) => sum + Number(entry.count || 0),
      0,
    );

    const brandCompletionChecks = [
      gym?.gymName,
      gym?.branding?.logoUrl,
      gym?.branding?.primaryColor,
      gym?.branding?.secondaryColor,
      Array.isArray(gym?.services) && gym.services.length > 0,
    ];
    const brandCompletion = Math.round(
      (brandCompletionChecks.filter(Boolean).length / brandCompletionChecks.length) * 100,
    );

    res.status(200).json({
      membersCount: members.length,
      trainersCount: trainers.length,
      registrations,
      activeMembers: members.length,
      coachCount: trainers.length,
      weeklySignups,
      inviteCount: openInvites.length,
      brandCompletion,
      chartSeries: registrations.map((entry) => ({
        label: entry.day,
        value: Number(entry.count || 0),
      })),
    });
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
  uploadProfilePicture,
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
  changePassword: exports.changePassword,
  updateAvatar: exports.updateAvatar,
};
