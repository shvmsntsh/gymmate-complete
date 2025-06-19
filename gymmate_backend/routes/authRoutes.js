const express = require('express');
const router = express.Router();
const User = require('../models/User');
const jwt = require('jsonwebtoken');
const { InviteCode } = require('../models/InviteCode');

// POST /api/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required.' });
    }

    const user = await User.findOne({ email, password });
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const token = jwt.sign(
      {
        id: user._id,
        email: user.email,
        role: user.role,
        gymId: user.gymId
      },
      'mysecretkey',
      { expiresIn: '2h' }
    );

    res.json({ token });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// POST /api/invite/generate
router.post('/invite/generate', (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ message: 'No token provided' });

    const token = authHeader.split(' ')[1];
    if (!token) return res.status(401).json({ message: 'Token format invalid' });

    const decoded = jwt.verify(token, 'mysecretkey');
    const { role, gymId, email } = decoded;

    if (!req.body.role) return res.status(400).json({ message: 'Target role is required' });

    // Use gymName from body if user is superadmin; otherwise, force use from token
    let gymName = decoded.gymName || req.body.gymName;
    if (!gymName) return res.status(400).json({ message: 'gymName is required' });

    const inviteCode = Math.random().toString(36).substring(2, 10).toUpperCase();

    const invite = new InviteCode({
      code: inviteCode,
      role: req.body.role,
      gymName,
      used: false,
    });

    invite.save().then(() => {
      res.status(201).json({ message: 'Invite code generated', code: inviteCode });
    }).catch((err) => {
      res.status(500).json({ message: 'Error saving invite', error: err.message });
    });
  } catch (err) {
    res.status(401).json({ message: 'Invalid or expired token', error: err.message });
  }
});

module.exports = router;
