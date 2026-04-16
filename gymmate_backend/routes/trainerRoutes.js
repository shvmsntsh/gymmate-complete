const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/authMiddleware');
const trainerController = require('../controllers/trainerController');

router.use(authenticateToken);

router.get(
  '/attendance-progress',
  trainerController.getTrainerAttendanceProgress,
);
router.get('/dashboard', trainerController.getTrainerDashboard);
router.get('/clients', trainerController.getTrainerClients);
router.get('/clients/:memberId/summary', trainerController.getTrainerClientSummary);
router.get('/clients/:memberId/activity', trainerController.getTrainerClientActivity);

module.exports = router;
