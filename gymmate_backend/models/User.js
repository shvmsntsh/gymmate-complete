const mongoose = require('mongoose');

const gymSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
  },
  ownerName: String,
  email: {
    type: String,
    required: true,
    unique: true,
  },
  phone: String,
  address: String,
  registrationDate: {
    type: Date,
    default: Date.now,
  },
  facilities: [String], // e.g., ['gym', 'pool', 'cafe', 'parking']
  offers: [
    {
      title: String,
      description: String,
      price: Number,
      durationInDays: Number,
    }
  ]
});

module.exports = mongoose.model('Gym', gymSchema);