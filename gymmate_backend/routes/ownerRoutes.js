const express = require('express');

const { authenticateToken } = require('../middleware/authMiddleware');
const ownerController = require('../controllers/ownerController');
const operationsController = require('../controllers/operationsController');

const router = express.Router();

router.use(authenticateToken);

router.get('/trainers', ownerController.getOwnerTrainers);
router.get('/assignments', ownerController.getOwnerAssignments);
router.put('/members/:memberId/assignment', ownerController.assignMemberToTrainer);
router.delete('/members/:memberId/assignment', ownerController.unassignMember);
router.get('/member-workspace', operationsController.getMemberWorkspace);
router.put('/members/:memberId/membership', operationsController.assignMemberMembership);
router.get('/announcements', operationsController.listAnnouncements);
router.post('/announcements', operationsController.createAnnouncement);
router.get('/assets/:assetId', operationsController.streamMediaAssetForOwner);
router.get('/membership-plans', operationsController.listMembershipPlans);
router.post('/membership-plans', operationsController.upsertMembershipPlan);
router.put('/membership-plans/:planId', operationsController.upsertMembershipPlan);
router.get('/membership-requests', operationsController.listMembershipRequests);
router.patch('/membership-requests/:requestId', operationsController.updateMembershipRequest);
router.post('/payments', operationsController.recordPayment);
router.get('/biometric/providers', operationsController.listBiometricProviders);
router.get('/biometric/settings', operationsController.getBiometricSettings);
router.put('/biometric/settings', operationsController.upsertBiometricSettings);
router.post('/biometric/sync', operationsController.syncBiometricPilot);

module.exports = router;
