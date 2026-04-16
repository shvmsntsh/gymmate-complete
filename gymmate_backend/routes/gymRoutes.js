const express = require('express');
const router = express.Router();
const Gym = require('../models/Gym');
const User = require('../models/User');
const { InviteCode } = require('../models/InviteCode');
const ServiceCatalog = require('../models/ServiceCatalog');
const jwt = require('jsonwebtoken');
const { authenticateToken } = require('../middleware/authMiddleware');
const bcrypt = require('bcryptjs');
const { hasRole } = require('../utils/roles');
const { getJwtSecret } = require('../utils/jwt');
const {
  DEFAULT_SERVICE_NAMES,
  normalizeServices,
  serviceSlug,
  servicesToCatalogItems,
} = require('../utils/serviceCatalog');
const { ensureCanCreateMemberInvite } = require('../utils/gymLimits');

const MAX_LOGO_DATA_BYTES = 1024 * 1024;
const LOGO_DATA_URL_PATTERN = /^data:image\/(png|jpe?g|webp);base64,/i;

function validateLogoUrl(value) {
  if (!value) {
    return null;
  }

  if (value.startsWith('data:')) {
    if (!LOGO_DATA_URL_PATTERN.test(value)) {
      return 'Logo must be a PNG, JPEG, or WebP image.';
    }
    const base64 = value.replace(LOGO_DATA_URL_PATTERN, '');
    const sizeBytes = Buffer.byteLength(base64, 'base64');
    if (!sizeBytes || sizeBytes > MAX_LOGO_DATA_BYTES) {
      return 'Logo image must be smaller than 1 MB.';
    }
    return null;
  }

  if (!/^https?:\/\//i.test(value)) {
    return 'Logo must be an HTTPS URL or a small image upload.';
  }

  if (value.length > 2048) {
    return 'Logo URL is too long.';
  }

  return null;
}

router.post('/register', async (req, res) => {

  try {
    const {
      gymName: rawGymName,
      name,
      email,
      password,
      address,
      contactNumber,
      phone,
      services,
    } = req.body;
    const gymName = rawGymName || name;
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const normalizedContactNumber = String(contactNumber || phone || '').trim();

    if (!gymName || !normalizedEmail) {
      return res.status(400).json({ message: 'Name and email are required' });
    }

    if (!req.body.gymName) {
      return res.status(400).json({ message: 'Gym name is required' });
    }
    if (!req.body.address) {
      return res.status(400).json({ message: 'Address is required' });
    }
    if (!normalizedContactNumber) {
      return res.status(400).json({ message: 'Phone number is required' });
    }

    // 🧹 Clean up falsy/null diet, workout, fitnessGoals fields and log them
    ['diet', 'workout', 'fitnessGoals'].forEach(field => {
      if (!req.body[field]) {
        delete req.body[field];
      }
    });

    const existingGym = await Gym.findOne({ email: normalizedEmail });
    if (existingGym) {
      return res.status(400).json({ message: 'Gym already exists' });
    }

    const existingOwner = await User.findOne({ email: normalizedEmail });
    if (existingOwner) {
      return res.status(400).json({ message: 'An account with this email already exists' });
    }

    const existingPhone = await User.findOne({ phone_number: normalizedContactNumber });
    if (existingPhone) {
      return res.status(400).json({ message: 'An account with this phone number already exists' });
    }

    const assignedRole = 'gym_owner';
    const normalizedServices = normalizeServices(services);
    const normalizedServiceSlugs = normalizedServices.map(serviceSlug);

    let hashedPassword = password;
    if (password) {
      hashedPassword = await bcrypt.hash(password, 10);
    }
    const newGymData = {
      gymName,
      email: normalizedEmail,
      password: hashedPassword,
      address,
      contactNumber: normalizedContactNumber,
      services: normalizedServices,
      serviceSlugs: normalizedServiceSlugs,
      role: assignedRole,
    };

    if (req.body.diet) {
      newGymData.diet = req.body.diet;
    }
    if (req.body.workout) {
      newGymData.workout = req.body.workout;
    }
    if (req.body.fitnessGoals) {
      newGymData.fitnessGoals = req.body.fitnessGoals;
    }

    const newGym = new Gym(newGymData);
    await newGym.save();

    let ownerUser;
    try {
      ownerUser = new User({
        name: gymName,
        email: normalizedEmail,
        password,
        role: assignedRole,
        gymId: newGym._id,
        phone_number: normalizedContactNumber || undefined,
      });

      await ownerUser.save();
      const linkedGym = await Gym.findByIdAndUpdate(
        newGym._id,
        { $set: { owner: ownerUser._id } },
        { new: true },
      );
      if (!linkedGym) {
        throw new Error('Failed to link owner to the gym.');
      }
    } catch (ownerError) {
      await Gym.findByIdAndDelete(newGym._id).catch(() => {});
      throw ownerError;
    }

    await Promise.all(
      servicesToCatalogItems(normalizedServices).map((service) =>
        ServiceCatalog.updateOne(
          { slug: service.slug },
          {
            $setOnInsert: {
              name: service.name,
              slug: service.slug,
              source: DEFAULT_SERVICE_NAMES.map(serviceSlug).includes(service.slug)
                ? 'default'
                : 'custom',
            },
            $inc: { usageCount: 1 },
          },
          { upsert: true },
        ),
      ),
    );

    const { InviteCode } = require('../models/InviteCode');
    let invite;
    if (req.body.inviteId) {
      invite = await InviteCode.findById(req.body.inviteId);
    } else if (assignedRole !== 'superadmin' && req.body.inviteCode) {
      invite = await InviteCode.findOne({
        code: req.body.inviteCode,
        role: assignedRole,
        used: false
      });
    }

    if (invite) {
      await InviteCode.updateOne(
        { _id: invite._id },
        {
          $set: {
            used: true,
            usedBy: email,
            updatedAt: new Date()
          }
        }
      );
    }

    res.status(201).json({
      message: 'Gym registered successfully',
      gym: {
        id: newGym._id,
        gymName: newGym.gymName,
        name: newGym.gymName,
        email: newGym.email,
        address: newGym.address || '',
        contactNumber: newGym.contactNumber || '',
        services: normalizeServices(newGym.services),
        status: newGym.status,
      },
      owner: {
        id: ownerUser._id,
        name: ownerUser.name,
        email: ownerUser.email,
        role: ownerUser.role,
        gymId: ownerUser.gymId,
      },
    });
  } catch (error) {
    console.error('Error registering gym:', error);
    if (error?.code === 11000) {
      const field = Object.keys(error.keyPattern || {})[0] || 'field';
      return res.status(400).json({ message: `An account with this ${field} already exists.` });
    }
    if (error?.name === 'ValidationError') {
      const firstError = Object.values(error.errors || {})[0];
      return res.status(400).json({ message: firstError?.message || 'Please check the registration details.' });
    }
    res.status(500).json({ message: 'We could not register this gym right now. Please try again.', error: error.message });
  }
});

router.get('/list', authenticateToken, async (req, res) => {
  try {
    if (!hasRole(req.user, ['admin'])) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const gyms = await Gym.find({})
      .sort({ createdAt: -1 })
      .select('gymName email address contactNumber services serviceSlugs status platformPlan memberCap planStatus createdAt');

    return res.status(200).json(
      gyms.map((gym) => ({
        id: gym._id,
        name: gym.gymName,
        email: gym.email,
        address: gym.address || '',
        contactNumber: gym.contactNumber || '',
        services: normalizeServices(gym.services),
        serviceSlugs: gym.serviceSlugs || normalizeServices(gym.services).map(serviceSlug),
        status: gym.status,
        platformPlan: gym.platformPlan || 'launch_50',
        memberCap: gym.memberCap || 50,
        planStatus: gym.planStatus || 'active',
        createdAt: gym.createdAt,
      })),
    );
  } catch (error) {
    console.error('Error fetching gym list:', error);
    return res.status(500).json({ message: 'Failed to fetch gyms' });
  }
});

// ✅ Gym Login Route
router.post('/login', async (req, res) => {

  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const { password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const gym = await Gym.findOne({ email });
    if (!gym || !gym.password) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }
    if (gym.status !== 'active') {
      return res.status(403).json({ message: 'Gym account is inactive.' });
    }

    const passwordMatch = await bcrypt.compare(password, gym.password);
    if (!passwordMatch) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    const token = jwt.sign(
      { id: gym._id, email: gym.email, role: gym.role, gymId: gym._id },
      getJwtSecret(),
      { expiresIn: '2h' }
    );

    if (gym.role === 'gym_member') {
      const now = new Date();
      const update = {
        $set: { lastLoginAt: now },
        $push: {
          loginTimestamps: {
            $each: [now],
            $position: 0,
            $slice: 100
          }
        }
      };
      await Gym.findByIdAndUpdate(gym._id, update, { new: true });
    }

    return res.status(200).json({
      message: 'Login successful',
      token,
      gymId: gym._id,
      gymName: gym.gymName,
      role: gym.role,
    });
  } catch (error) {
    console.error('Error during gym login:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// ✅ Get all services from all gyms
router.get('/services', async (req, res) => {
  try {
    const gyms = await Gym.find({}, 'services'); // Only fetch the 'services' field from all gyms
    const services = gyms.flatMap(g => normalizeServices(g.services));
    const uniqueServices = [...new Set(services)];
    res.status(200).json({ services: uniqueServices });
  } catch (error) {
    console.error('Error fetching services:', error);
    res.status(500).json({ message: 'Failed to fetch services', error: error.message });
  }
});

router.get('/services/catalog', async (req, res) => {
  try {
    const defaultItems = DEFAULT_SERVICE_NAMES.map((name) => ({
      name,
      slug: serviceSlug(name),
      source: 'default',
      usageCount: 0,
    }));
    const catalogItems = await ServiceCatalog.find({}).sort({ source: 1, name: 1 }).lean();
    const gyms = await Gym.find({}, 'services serviceSlugs').lean();
    const usageCounts = new Map();

    gyms.forEach((gym) => {
      normalizeServices(gym.services).forEach((service) => {
        const slug = serviceSlug(service);
        usageCounts.set(slug, (usageCounts.get(slug) || 0) + 1);
      });
    });

    const bySlug = new Map();
    [...defaultItems, ...catalogItems].forEach((item) => {
      bySlug.set(item.slug, {
        name: item.name,
        slug: item.slug,
        source: item.source || 'custom',
        usageCount: usageCounts.get(item.slug) || item.usageCount || 0,
      });
    });

    return res.status(200).json({
      services: Array.from(bySlug.values()).sort((a, b) => {
        if (a.source !== b.source) return a.source === 'default' ? -1 : 1;
        return a.name.localeCompare(b.name);
      }),
    });
  } catch (error) {
    console.error('Error fetching service catalog:', error);
    return res.status(500).json({ message: 'Failed to fetch service catalog' });
  }
});

router.get('/services/distribution', authenticateToken, async (req, res) => {
  try {
    if (!hasRole(req.user, ['admin'])) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const gyms = await Gym.find({}, 'services');
    const counts = new Map();

    gyms.forEach((gym) => {
      normalizeServices(gym.services).forEach((service) => {
        counts.set(service, (counts.get(service) || 0) + 1);
      });
    });

    return res.status(200).json(
      Array.from(counts.entries())
        .map(([name, count]) => ({ name, count }))
        .sort((a, b) => b.count - a.count),
    );
  } catch (error) {
    console.error('Error fetching services distribution:', error);
    return res.status(500).json({ message: 'Failed to fetch service distribution' });
  }
});

router.get('/branding/:gymId', async (req, res) => {
  try {
    const gym = await Gym.findById(req.params.gymId).select(
      'gymName branding.logoUrl branding.primaryColor branding.secondaryColor branding.logoScale branding.logoOffsetX branding.logoOffsetY'
    );

    if (!gym) {
      return res.status(404).json({ message: 'Gym not found' });
    }

    return res.status(200).json({
      gymName: gym.gymName,
      logoUrl: gym.branding?.logoUrl || null,
      primaryColor: gym.branding?.primaryColor || '#B59F5B',
      secondaryColor: gym.branding?.secondaryColor || '#F8D84B',
      logoScale: gym.branding?.logoScale ?? 1,
      logoOffsetX: gym.branding?.logoOffsetX ?? 0,
      logoOffsetY: gym.branding?.logoOffsetY ?? 0,
    });
  } catch (error) {
    console.error('Error fetching gym branding:', error);
    return res.status(500).json({ message: 'Failed to fetch gym branding' });
  }
});

router.put('/branding', authenticateToken, async (req, res) => {
  try {
    if (!hasRole(req.user, ['owner'])) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    const targetGymId = req.user.gymId;

    if (!targetGymId) {
      return res.status(400).json({ message: 'No gym available for branding update' });
    }

    const gym = await Gym.findById(targetGymId);
    if (!gym) {
      return res.status(404).json({ message: 'Gym not found' });
    }

    const gymName = typeof req.body.gymName === 'string' ? req.body.gymName.trim() : '';
    const logoUrl = typeof req.body.logoUrl === 'string' ? req.body.logoUrl.trim() : '';
    const primaryColor = typeof req.body.primaryColor === 'string' ? req.body.primaryColor.trim() : '';
    const secondaryColor = typeof req.body.secondaryColor === 'string' ? req.body.secondaryColor.trim() : '';
    const logoScale = Number(req.body.logoScale);
    const logoOffsetX = Number(req.body.logoOffsetX);
    const logoOffsetY = Number(req.body.logoOffsetY);

    if (!gymName) {
      return res.status(400).json({ message: 'Gym name is required' });
    }

    const hexColorPattern = /^#?[0-9A-Fa-f]{6}$/;
    if (primaryColor && !hexColorPattern.test(primaryColor)) {
      return res.status(400).json({ message: 'Primary color must be a 6-digit hex value' });
    }
    if (secondaryColor && !hexColorPattern.test(secondaryColor)) {
      return res.status(400).json({ message: 'Secondary color must be a 6-digit hex value' });
    }

    const logoError = validateLogoUrl(logoUrl);
    if (logoError) {
      return res.status(400).json({ message: logoError });
    }

    const normalizeHex = (value, fallback) => {
      if (!value) return fallback;
      return value.startsWith('#') ? value.toUpperCase() : `#${value.toUpperCase()}`;
    };

    gym.gymName = gymName;
    gym.branding = {
      ...(gym.branding || {}),
      logoUrl: logoUrl || null,
      primaryColor: normalizeHex(primaryColor, gym.branding?.primaryColor || '#B59F5B'),
      secondaryColor: normalizeHex(secondaryColor, gym.branding?.secondaryColor || '#F8D84B'),
      logoScale: Number.isFinite(logoScale) ? Math.min(Math.max(logoScale, 0.8), 2) : (gym.branding?.logoScale ?? 1),
      logoOffsetX: Number.isFinite(logoOffsetX) ? Math.min(Math.max(logoOffsetX, -1), 1) : (gym.branding?.logoOffsetX ?? 0),
      logoOffsetY: Number.isFinite(logoOffsetY) ? Math.min(Math.max(logoOffsetY, -1), 1) : (gym.branding?.logoOffsetY ?? 0),
    };

    await gym.save();

    await User.updateMany(
      { gymId: targetGymId },
      { $set: { gymName } }
    );

    await InviteCode.updateMany(
      { gymId: targetGymId },
      { $set: { gymName } }
    );

    return res.status(200).json({
      message: 'Branding updated successfully',
      branding: {
        gymName: gym.gymName,
        logoUrl: gym.branding?.logoUrl || null,
        primaryColor: gym.branding?.primaryColor || '#B59F5B',
        secondaryColor: gym.branding?.secondaryColor || '#F8D84B',
        logoScale: gym.branding?.logoScale ?? 1,
        logoOffsetX: gym.branding?.logoOffsetX ?? 0,
        logoOffsetY: gym.branding?.logoOffsetY ?? 0,
      },
    });
  } catch (error) {
    console.error('Error updating gym branding:', error);
    return res.status(500).json({ message: 'Failed to update gym branding' });
  }
});

// GET /api/gym/members
router.get('/members', authenticateToken, async (req, res) => {
  try {

    let members;
    if (hasRole(req.user, ['admin'])) {
      members = await User.find({ role: { $in: ['gym_owner', 'gym_trainer', 'gym_member'] } })
        .select('name email role gymId createdAt');
    } else if (hasRole(req.user, ['owner'])) {
      members = await User.find({
        gymId: req.user.gymId,
        role: { $in: ['gym_trainer', 'gym_member'] }
      }).select('name email role gymId createdAt');
    } else if (hasRole(req.user, ['member'])) {
      members = await User.find({ _id: req.user.id })
        .select('name email role gymId createdAt');
    } else {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    res.status(200).json({ members });
  } catch (error) {
    console.error('Error fetching members:', error);
    res.status(500).json({ message: 'Error fetching members', error: error.message });
  }
});

// GET /api/gym/all-members (superadmin only)
router.get('/all-members', authenticateToken, async (req, res) => {
  if (!hasRole(req.user, ['admin'])) {
    return res.status(403).json({ message: 'Forbidden' });
  }
  try {
    const members = await User.find({ role: { $in: ['gym_owner', 'gym_trainer', 'gym_member'] } })
      .select('name email role gymId createdAt');
    return res.status(200).json({ members });
  } catch (error) {
    console.error('Error fetching all members:', error);
    return res.status(500).json({ message: 'Error fetching all members' });
  }
});

// GET /api/gym/self - Returns the current logged-in gym user
router.get('/self', authenticateToken, async (req, res) => {
  try {
    const gymId = req.user.gymId || req.user._id;
    if (!gymId) {
      return res.status(404).json({ message: 'Gym not associated with current user' });
    }
    const gym = await Gym.findById(gymId);
    if (!gym) {
      return res.status(404).json({ message: 'Gym not found' });
    }

    const gymSummary = {
      id: gym._id,
      name: gym.gymName,
      gymName: gym.gymName,
      email: gym.email,
      address: gym.address || '',
      contactNumber: gym.contactNumber || '',
      services: normalizeServices(gym.services),
      serviceSlugs: gym.serviceSlugs || normalizeServices(gym.services).map(serviceSlug),
      status: gym.status,
      platformPlan: gym.platformPlan || 'launch_50',
      memberCap: gym.memberCap || 50,
      planStatus: gym.planStatus || 'active',
      branding: gym.branding || {},
      owner: gym.owner || null,
    };

    res.status(200).json({
      member: gymSummary,
      gym: gymSummary,
    });
  } catch (error) {
    console.error('Error fetching self gym info:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// GET /api/gym/login-stats - Returns login counts per day for current week
router.get('/login-stats', authenticateToken, async (req, res) => {
  try {
    if (!hasRole(req.user, ['member'])) {
      return res.status(403).json({ message: 'Forbidden: gym_member only' });
    }

    const gym = await Gym.findById(req.user.gymId);
    if (!gym || !Array.isArray(gym.loginTimestamps)) {
      return res.status(200).json({ logins: [] });
    }

    const now = new Date();
    const startOfWeek = new Date(now);
    startOfWeek.setHours(0, 0, 0, 0);
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());

    const daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const loginCounts = Array(7).fill(0);

    gym.loginTimestamps.forEach(timestamp => {
      const date = new Date(timestamp);
      if (date >= startOfWeek && date <= now) {
        const dayIndex = date.getDay();
        loginCounts[dayIndex]++;
      }
    });

    const result = daysOfWeek.map((day, index) => ({
      day,
      count: loginCounts[index]
    }));

    return res.status(200).json({ logins: result });
  } catch (error) {
    console.error('Error generating login stats:', error);
    return res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});


// 📌 Generate a new invite code
router.post('/generate-invite', authenticateToken, async (req, res) => {
  const { role } = req.body;
  const generator = req.user;

  if (
    (generator.role === 'superadmin' && role === 'gym_owner') ||
    (generator.role === 'gym_owner' && role === 'gym_member')
  ) {
    try {
      if (role === 'gym_member') {
        await ensureCanCreateMemberInvite(generator.gymId);
      }
    } catch (error) {
      return res.status(error.statusCode || 500).json({
        message: error.message || 'Could not create invite.',
        usage: error.usage
          ? {
              activeMembers: error.usage.activeMembers,
              openMemberInvites: error.usage.openMemberInvites,
              usedSeats: error.usage.usedSeats,
              memberCap: error.usage.memberCap,
              remainingSeats: error.usage.remainingSeats,
            }
          : undefined,
      });
    }
    const code = Math.random().toString(36).substr(2, 8).toUpperCase();

    const { InviteCode } = require('../models/InviteCode');
    const newCode = new InviteCode({
      code,
      role,
      gymId: generator.gymId,
      generatedBy: generator.id,
    });

    await newCode.save();
    return res.status(201).json({ code });
  } else {
    return res.status(403).json({ message: 'Unauthorized to generate code for this role' });
  }
});

// 📌 Validate invite code
router.post('/validate-invite', async (req, res) => {
  let { code } = req.body;
  code = code.trim().toUpperCase();
  const { InviteCode } = require('../models/InviteCode');
  const invite = await InviteCode.findOne({ code, used: false });
  if (!invite) {
    return res.status(400).json({ message: 'Invalid or expired invite code' });
  }
  res.status(200).json({
    role: invite.role,
    gymId: invite.gymId,
    inviteId: invite._id,
  });
});

// GET /api/gym/:id - Return gym document by ID
router.get('/:id', async (req, res) => {
  try {
    const gym = await Gym.findById(req.params.id);
    if (!gym) {
      return res.status(404).json({ message: 'Gym not found' });
    }
    res.status(200).json({
      id: gym._id,
      name: gym.gymName,
      gymName: gym.gymName,
      email: gym.email,
      address: gym.address || '',
      contactNumber: gym.contactNumber || '',
      phone: gym.contactNumber || '',
      services: normalizeServices(gym.services),
      serviceSlugs: gym.serviceSlugs || normalizeServices(gym.services).map(serviceSlug),
      status: gym.status,
      platformPlan: gym.platformPlan || 'launch_50',
      memberCap: gym.memberCap || 50,
      planStatus: gym.planStatus || 'active',
      createdAt: gym.createdAt,
    });
  } catch (error) {
    console.error('Error fetching gym by ID:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});
// ✅ Update onboarding data (diet, workout, goals)
router.put('/onboarding', authenticateToken, async (req, res) => {
  try {
    if (!hasRole(req.user, ['member'])) {
      return res.status(403).json({ message: 'Only gym_members can update onboarding data' });
    }

    const updateFields = {};
    if (req.body.diet) {
      updateFields.diet = req.body.diet;
    }
    if (req.body.workout) {
      updateFields.workout = req.body.workout;
    }
    if (req.body.fitnessGoals) {
      updateFields.fitnessGoals = req.body.fitnessGoals;
    }

    if (!req.user.gymId) {
      return res.status(400).json({ message: 'No gym assigned to current user' });
    }

    const updated = await Gym.findByIdAndUpdate(req.user.gymId, { $set: updateFields }, { new: true });

    return res.status(200).json({ message: 'Onboarding data updated', gym: updated });
  } catch (error) {
    console.error('Error updating onboarding data:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// POST /api/gym/check-name - Check if a gym name already exists
router.post('/check-name', async (req, res) => {
  const { gymName } = req.body;
  if (!gymName) {
    return res.status(400).json({ exists: false, message: 'Gym name is required' });
  }
  const existing = await Gym.findOne({ gymName: gymName.trim() });
  res.status(200).json({ exists: !!existing });
});

// Export the router to be mounted in the main app under '/api/gym'
module.exports = router;
