const express = require('express');
const router = express.Router();
const Gym = require('../models/Gym');
const jwt = require('jsonwebtoken');
const { authenticateToken } = require('../middleware/authMiddleware');

router.post('/register', async (req, res) => {
  console.log('🔔 Received POST /register');
  console.log('📦 Request body:', req.body);

  try {
    const { gymName, email, password, address, contactNumber, services } = req.body;

    if (!gymName || !email) {
      return res.status(400).json({ message: 'Name and email are required' });
    }

    // 🧹 Clean up falsy/null diet, workout, fitnessGoals fields and log them
    ['diet', 'workout', 'fitnessGoals'].forEach(field => {
      if (!req.body[field]) {
        console.log(`🧹 Cleaning up falsy or null field: ${field}`);
        delete req.body[field];
      }
    });

    const existingGym = await Gym.findOne({ email });
    if (existingGym) {
      return res.status(400).json({ message: 'Gym already exists' });
    }

    // Determine actual role based on existing gym count and gym name
    let assignedRole;
    const totalGyms = await Gym.countDocuments({});
    if (totalGyms === 0) {
      assignedRole = 'superadmin'; // First user becomes superadmin
    } else {
      const existingGymWithSameName = await Gym.findOne({ gymName });
      if (existingGymWithSameName) {
        assignedRole = 'gym_member'; // User registering with existing gym name becomes a member
      } else {
        assignedRole = 'gym_owner'; // New gym name means this is a new gym owner
      }
    }

    const newGymData = {
      gymName,
      email,
      password,
      address,
      contactNumber,
      services,
      role: assignedRole,
    };

    if (req.body.diet) newGymData.diet = req.body.diet;
    if (req.body.workout) newGymData.workout = req.body.workout;
    if (req.body.fitnessGoals) newGymData.fitnessGoals = req.body.fitnessGoals;

    console.log('🛠 Final gym data to be saved:', newGymData);
    const newGym = new Gym(newGymData);

    await newGym.save();

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
      console.log(`✅ Marking invite code ${invite.code} as used by ${email}`);
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
    } else {
      console.log('⚠️ No valid invite code matched for update.');
    }

    res.status(201).json({ message: 'Gym registered successfully', gym: newGym });
  } catch (error) {
    console.error('❌ Error:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// ✅ Gym Login Route
router.post('/login', async (req, res) => {
  console.log('🔐 Received POST /login');
  console.log('📥 Request body:', req.body);

  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const gym = await Gym.findOne({ email });
    if (!gym || gym.password !== password) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    const token = jwt.sign(
      { id: gym._id, email: gym.email, role: gym.role, gymId: gym._id },
      process.env.JWT_SECRET || 'defaultsecret',
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
    console.error('❌ Error during login:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// ✅ Get all services from all gyms
router.get('/services', async (req, res) => {
  try {
    const gyms = await Gym.find({}, 'services'); // Only fetch the 'services' field from all gyms
    const services = gyms.flatMap(g => g.services || []);
    const uniqueServices = [...new Set(services)];
    res.status(200).json({ services: uniqueServices });
  } catch (error) {
    console.error('❌ Error fetching services:', error);
    res.status(500).json({ message: 'Failed to fetch services', error: error.message });
  }
});

// GET /api/gym/members
router.get('/members', authenticateToken, async (req, res) => {
  try {
    console.log(`🔎 Fetching members for role: ${req.user.role}, gymId: ${req.user.gymId}`);

    let gyms;
    if (req.user.role === 'superadmin') {
      gyms = await Gym.find({});
    } else if (req.user.role === 'gym_owner') {
      const owner = await Gym.findById(req.user.gymId);
      gyms = await Gym.find({ role: 'gym_member', gymName: owner.gymName });
    } else if (req.user.role === 'gym_member') {
      gyms = await Gym.find({ _id: req.user.gymId });
    } else {
      return res.status(403).json({ message: 'Unauthorized' });
    }

    res.status(200).json({ members: gyms });
  } catch (error) {
    console.error('❌ Error fetching members:', error);
    res.status(500).json({ message: 'Error fetching members', error: error.message });
  }
});

// GET /api/gym/all-members (superadmin only)
router.get('/all-members', authenticateToken, async (req, res) => {
  if (req.user.role !== 'superadmin') {
    return res.status(403).json({ message: 'Forbidden: superadmin only' });
  }
  try {
    const gyms = await Gym.find({});
    return res.status(200).json({ members: gyms });
  } catch (error) {
    console.error('Error fetching all members:', error);
    return res.status(500).json({ message: 'Error fetching all members' });
  }
});

// GET /api/gym/self - Returns the current logged-in gym user
router.get('/self', authenticateToken, async (req, res) => {
  try {
    const gym = await Gym.findById(req.user.id);
    if (!gym) {
      return res.status(404).json({ message: 'Gym not found' });
    }
    res.status(200).json({ member: gym });
  } catch (error) {
    console.error('❌ Error fetching self gym info:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// GET /api/gym/login-stats - Returns login counts per day for current week
router.get('/login-stats', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'gym_member') {
      return res.status(403).json({ message: 'Forbidden: gym_member only' });
    }

    const gym = await Gym.findById(req.user.id);
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
    console.error('❌ Error generating login stats:', error);
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
  const { code } = req.body;

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
    res.status(200).json(gym); // Send raw gym document
  } catch (error) {
    console.error('❌ Error fetching gym by ID:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});
// ✅ Update onboarding data (diet, workout, goals)
router.put('/onboarding', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'gym_member') {
      return res.status(403).json({ message: 'Only gym_members can update onboarding data' });
    }

    const updateFields = {};
    if (req.body.diet) updateFields.diet = req.body.diet;
    if (req.body.workout) updateFields.workout = req.body.workout;
    if (req.body.fitnessGoals) updateFields.fitnessGoals = req.body.fitnessGoals;

    const updated = await Gym.findByIdAndUpdate(req.user.id, { $set: updateFields }, { new: true });

    return res.status(200).json({ message: 'Onboarding data updated', gym: updated });
  } catch (error) {
    console.error('❌ Error updating onboarding data:', error);
    res.status(500).json({ message: 'Internal server error', error: error.message });
  }
});

// Export the router to be mounted in the main app under '/api/gym'
module.exports = router;