const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/authMiddleware');
const userController = require('../controllers/userController');
const planLogController = require('../controllers/planLogController');
const operationsController = require('../controllers/operationsController');

router.use(authenticateToken);

router.get(
  '/progress-participation',
  userController.getMemberProgressParticipation,
);

router.get('/plan-log', planLogController.getMemberPlanLog);
router.put('/plan-log', planLogController.upsertMemberPlanLog);
router.get('/announcements', operationsController.listMemberAnnouncements);
router.post('/announcements/:deliveryId/read', operationsController.markAnnouncementRead);
router.get('/membership', operationsController.getMemberMembershipSummary);
router.post('/membership-requests', operationsController.createMemberMembershipRequest);
router.get('/assets/:assetId', operationsController.streamMediaAssetForMember);

module.exports = router;
