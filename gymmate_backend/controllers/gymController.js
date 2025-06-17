const Gym = require('../models/Gym');

exports.registerGym = async (req, res) => {
  try {
    const gym = new Gym(req.body);
    const savedGym = await gym.save();
    res.status(201).json({ message: 'Gym registered successfully', gym: savedGym });
  } catch (error) {
    res.status(400).json({ message: 'Error registering gym', error: error.message });
  }
};