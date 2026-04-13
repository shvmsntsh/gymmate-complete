const express = require('express');
const router = express.Router();

const { authenticateToken } = require('../middleware/authMiddleware');
const userController = require('../controllers/userController');
const planLogController = require('../controllers/planLogController');
const operationsController = require('../controllers/operationsController');
const memberMembershipController = require('../controllers/memberMembershipController');

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

router.get('/me/membership', memberMembershipController.getMyMembership);
router.get('/me/membership-options', memberMembershipController.getMyMembershipOptions);
router.get('/me/membership-requests', memberMembershipController.getMyMembershipRequests);
router.post('/me/membership-requests', memberMembershipController.createMembershipRequest);
router.get('/me/entitlements', memberMembershipController.getMyEntitlements);

module.exports = router;
