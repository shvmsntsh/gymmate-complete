const express = require('express');
const { authenticateToken, requireRole } = require('../middleware/authMiddleware');
const adminController = require('../controllers/adminController');

const router = express.Router();

router.use(authenticateToken, requireRole(['admin']));

router.get('/network/overview', adminController.getNetworkOverview);
router.get('/gyms', adminController.listGyms);
router.patch('/gyms/:gymId', adminController.updateGym);
router.get('/gyms/:gymId/billing', adminController.getGymBilling);
router.post('/gyms/:gymId/plan-payment', adminController.recordPlanPayment);
router.post('/gyms/:gymId/plan-unassign', adminController.unassignPlan);
router.get('/users', adminController.listUsers);
router.patch('/users/:userId', adminController.updateUser);
router.get('/invites', adminController.listInvites);
router.get('/service-analytics', adminController.getServiceAnalytics);

module.exports = router;
