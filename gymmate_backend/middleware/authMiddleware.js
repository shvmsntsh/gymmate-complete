const jwt = require('jsonwebtoken');

const authenticateToken = (req, res, next) => {
  console.log('🔐 Incoming Authorization header:', req.headers['authorization']);
  const authHeader = req.headers['authorization'];

  if (!authHeader) {
    return res.status(403).json({ message: 'No token provided' });
  }

  const token = authHeader.split(' ')[1]; // Extract token from "Bearer <token>"

  if (!token) {
    return res.status(403).json({ message: 'Token missing in Authorization header' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    console.log('🛡️ Token verified, decoded user:', decoded);
    req.user = decoded;
    next(); // proceed to the actual route
  } catch (error) {
    return res.status(403).json({ message: 'Invalid or expired token', error: error.message });
  }
};

module.exports = { authenticateToken };
