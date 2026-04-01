const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/authMiddleware');
const userController = require('../controllers/userController');

router.use(authenticateToken);

router.get(
  '/progress-participation',
  userController.getMemberProgressParticipation,
);

module.exports = router;
