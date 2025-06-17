const mongoose = require('mongoose');

const gymSchema = new mongoose.Schema({
  name: String,
  email: { type: String, required: true, unique: true },
  password: String,
  address: String,
  contactNumber: String,
  services: [String],
  role: {
    type: String,
    enum: ['superadmin', 'admin'],
    default: 'admin'
  }
});

module.exports = mongoose.model('Gym', gymSchema);