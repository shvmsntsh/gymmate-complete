const express = require('express');
const router = express.Router();
const Gym = require('../models/Gym');

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

// Export the router to be mounted in the main app under '/api/gym'
module.exports = router;
