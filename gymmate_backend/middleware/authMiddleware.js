const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Gym = require('../models/Gym');
const { normalizeRole, hasRole, hasPermission } = require('../utils/roles');

const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];

  if (!authHeader) {
    return res.status(403).json({ message: 'No token provided' });
  }

  const token = authHeader.split(' ')[1];

  if (!token) {
    return res.status(403).json({ message: 'Token missing in Authorization header' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findById(decoded.id);
    if (user) {
      user.normalizedRole = normalizeRole(user.role);
      req.user = user;
      return next();
    }

    const gym = await Gym.findById(decoded.id);
    if (gym) {
      req.user = {
        ...gym.toObject(),
        id: gym._id.toString(),
        _id: gym._id,
        email: gym.email,
        role: gym.role,
        gymId: decoded.gymId || gym._id.toString(),
        gymName: gym.gymName,
        normalizedRole: normalizeRole(gym.role),
        tokenType: 'gym',
      };
      return next();
    }

    return res.status(401).json({ message: 'User not found' });
  } catch (error) {
    return res.status(403).json({ message: 'Invalid or expired token' });
  }
};

// Alias for compatibility with route files
const protect = authenticateToken;

// Role-based access control middleware
const requireRole = (roles) => (req, res, next) => {
  if (!req.user || !hasRole(req.user, roles)) {
    return res.status(403).json({ message: 'Forbidden: insufficient role' });
  }
  next();
};

const requirePermission = (permission) => (req, res, next) => {
  if (!req.user || !hasPermission(req.user, permission)) {
    return res.status(403).json({ message: 'Forbidden: insufficient permission' });
  }
  next();
};

module.exports = {
  authenticateToken,
  protect,
  requireRole,
  requirePermission,
  normalizeRole,
  hasRole,
  hasPermission,
};
