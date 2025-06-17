const express = require('express');
const router = express.Router();
const Gym = require('../models/Gym');
const jwt = require('jsonwebtoken');

// Authentication middleware to verify JWT and attach gym info
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'Authorization header missing or malformed' });
  }
  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET || 'defaultsecret');
    req.gymUser = payload;  // { id, email, role }
    next();
  } catch (err) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

router.post('/register', async (req, res) => {
  console.log('🔔 Received POST /register');
  console.log('📦 Request body:', req.body);

  try {
    const { name, email, password, address, contactNumber, services } = req.body;

    if (!name || !email) {
      return res.status(400).json({ message: 'Name and email are required' });
    }

    const existingGym = await Gym.findOne({ email });
    if (existingGym) {
      return res.status(400).json({ message: 'Gym already exists' });
    }

    const newGym = new Gym({ name, email, password, address, contactNumber, services });
    await newGym.save();

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
      { id: gym._id, email: gym.email, role: gym.role },
      process.env.JWT_SECRET || 'defaultsecret',
      { expiresIn: '2h' }
    );
    return res.status(200).json({
      message: 'Login successful',
      token,
      gymId: gym._id,
      gymName: gym.name,
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
// Admins see only their own gym entry; superadmins see all gyms.
router.get('/members', authMiddleware, async (req, res) => {
  try {
    if (req.gymUser.role === 'superadmin') {
      const gyms = await Gym.find({});
      return res.status(200).json({ members: gyms });
    } else {
      const gym = await Gym.findById(req.gymUser.id);
      return res.status(200).json({ members: gym ? [gym] : [] });
    }
  } catch (error) {
    console.error('Error fetching members:', error);
    return res.status(500).json({ message: 'Error fetching members' });
  }
});

// GET /api/gym/all-members (superadmin only)
router.get('/all-members', authMiddleware, async (req, res) => {
  if (req.gymUser.role !== 'superadmin') {
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

// Export the router to be mounted in the main app under '/api/gym'
module.exports = router;
