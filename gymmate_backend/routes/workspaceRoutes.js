const express = require('express');
const { authenticateToken } = require('../middleware/authMiddleware');
const workspaceController = require('../controllers/workspaceController');

const router = express.Router();

router.use(authenticateToken);

router.get('/dashboard', workspaceController.getDashboard);

router.get('/leads', workspaceController.listLeads);
router.post('/leads', workspaceController.createLead);
router.patch('/leads/:leadId', workspaceController.updateLead);
router.post('/leads/:leadId/activities', workspaceController.addLeadActivity);

router.get('/members', workspaceController.listMembers);
router.get('/members/:memberId', workspaceController.getMemberDetail);

router.get('/payments', workspaceController.listPayments);
router.post('/payments', workspaceController.recordPayment);

router.get('/attendance', workspaceController.listAttendance);
router.post('/attendance', workspaceController.recordAttendance);

router.get('/classes', workspaceController.listClasses);
router.post('/classes/templates', workspaceController.createClassTemplate);
router.post('/classes/sessions', workspaceController.createClassSession);
router.post('/classes/sessions/:sessionId/bookings', workspaceController.createClassBooking);
router.patch('/classes/bookings/:bookingId', workspaceController.updateClassBooking);

router.get('/staff', workspaceController.listStaff);
router.post('/staff', workspaceController.createStaff);
router.patch('/staff/:userId/capabilities', workspaceController.updateStaffCapabilities);

module.exports = router;
