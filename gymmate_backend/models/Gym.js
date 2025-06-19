const mongoose = require('mongoose');

const gymSchema = new mongoose.Schema({
  gymName: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: String,
  address: String,
  contactNumber: String,
  services: [String],
  role: {
    
    type: String,
    enum: ['superadmin', 'gym_owner', 'gym_member'],
    default: 'gym_owner'
  }
});

module.exports = mongoose.model('Gym', gymSchema);