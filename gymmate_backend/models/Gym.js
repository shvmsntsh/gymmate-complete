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
    enum: ['superadmin', 'admin', 'member'],
    default: 'admin'
  }
});

module.exports = mongoose.model('Gym', gymSchema);