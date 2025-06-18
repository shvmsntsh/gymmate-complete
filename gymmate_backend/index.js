const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcrypt');
const Gym = require('./models/Gym');
const gymRoutes = require('./routes/gymRoutes');

const app = express();
const PORT = process.env.PORT || 5050;

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection
mongoose.connect('mongodb://127.0.0.1:27017/gymmate', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('✅ MongoDB connected'))
.catch(err => console.error('❌ MongoDB connection error:', err));

// Mount gym routes for services and other gym-related endpoints
app.use('/api/gym', gymRoutes);

// Registration Route
app.post('/api/gym/register', async (req, res) => {
  try {
    const { gymName, email, password } = req.body;
    const existingGym = await Gym.findOne({ email });
    if (existingGym) {
      return res.status(400).json({ message: 'Gym with this email already exists' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const newGym = new Gym({ gymName, email, password: hashedPassword, role: 'member' });
    await newGym.save();
    res.status(201).json({ message: 'Gym registered successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Login Route
app.post('/api/gym/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const gym = await Gym.findOne({ email });
    if (!gym) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    const isMatch = await bcrypt.compare(password, gym.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid email or password' });
    }

    res.json({ message: 'Login successful', gymId: gym._id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server error' });
  }
});

// Admin Stats Endpoints
app.get('/api/stats/gyms', async (req, res) => {
  try {
    const count = await Gym.countDocuments();
    res.json({ totalGyms: count });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to fetch gym count' });
  }
});

app.get('/api/stats/services', async (req, res) => {
  try {
    const gyms = await Gym.find();
    const allServices = gyms.flatMap(gym => gym.services || []);
    const uniqueServices = [...new Set(allServices)];
    res.json({ totalServices: uniqueServices.length });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to fetch service count' });
  }
});

app.get('/api/stats/members', async (req, res) => {
  try {
    // Placeholder: will be updated when Member schema is ready
    res.json({ totalMembers: 0 });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to fetch member count' });
  }
});

app.get('/api/admin/dashboard', async (req, res) => {
  try {
    const gyms = await Gym.find();
    const totalGyms = gyms.length;
    const totalServices = [...new Set(gyms.flatMap(g => g.services || []))].length;
    const totalMembers = 0; // Will update when member collection is added

    res.json({
      stats: {
        gyms: totalGyms,
        services: totalServices,
        members: totalMembers,
      }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to fetch dashboard stats' });
  }
});

// List Members Endpoint
app.get('/api/members', async (req, res) => {
  console.log('🔍 /api/members endpoint hit');
  try {
    const gyms = await Gym.find({}, 'name email contactNumber');
    const members = gyms.map(gym => ({
      gymName: gym.name,
      email: gym.email,
      contact: gym.contactNumber
    }));
    res.json({ members });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to fetch members' });
  }
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
});
