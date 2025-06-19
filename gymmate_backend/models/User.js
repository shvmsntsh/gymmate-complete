const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  // Full name of the user (owner or member)
  name: {
    type: String,
    required: true,
  },
  // Email used for login
  email: {
    type: String,
    required: true,
    unique: true,
  },
  // Hashed password
  password: {
    type: String,
    required: true,
  },
  // Role determines access level:
  // 'admin' = central builder's office (superadmin)
  // 'gym_owner' = society secretary (manages one gym)
  // 'gym_member' = flat owner (can only see own record)
  role: {
    type: String,
    enum: ['admin', 'gym_owner', 'gym_member'],
    default: 'gym_owner',
  },
  // Reference to associated Gym (only for gym_owner and gym_member)
  gymId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Gym',
  },
  // Date the user joined
  joinDate: {
    type: Date,
    default: Date.now,
  }
});

module.exports = mongoose.model('User', userSchema);