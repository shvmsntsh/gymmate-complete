const Gym = require('../models/Gym');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

exports.registerGym = async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name?.trim() || !email?.trim()) {
      return res.status(400).json({ message: 'Name and email are required' });
    }
    const gym = new Gym({
      gymName: name.trim(),
      email,
      password,
      role: role === 'superadmin' ? 'superadmin' : 'admin'
    });
    // If this is the first registration and no superadmin exists, make this user a superadmin
    if (role !== 'superadmin') {
      const superadminCount = await Gym.countDocuments({ role: 'superadmin' });
      if (superadminCount === 0) {
        gym.role = 'superadmin';
      }
    }
    const savedGym = await gym.save();
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
      process.env.JWT_SECRET || 'defaultsecret',
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