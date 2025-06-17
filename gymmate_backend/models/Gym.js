const mongoose = require('mongoose');

const gymSchema = new mongoose.Schema({
  name: String,
  email: { type: String, required: true, unique: true },
  password: String,
  address: String,
  contactNumber: String,
  services: [String]
});

module.exports = mongoose.model('Gym', gymSchema);