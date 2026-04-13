const express = require('express');

const { authenticateToken } = require('../middleware/authMiddleware');
const ownerController = require('../controllers/ownerController');
const operationsController = require('../controllers/operationsController');
const membershipController = require('../controllers/membershipController');

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
router.get('/membership-requests/:requestId', operationsController.getMembershipRequest);
router.patch('/membership-requests/:requestId', operationsController.updateMembershipRequest);
router.post('/payments', operationsController.recordPayment);
router.get('/biometric/providers', operationsController.listBiometricProviders);
router.get('/biometric/settings', operationsController.getBiometricSettings);
router.put('/biometric/settings', operationsController.upsertBiometricSettings);
router.post('/biometric/sync', operationsController.syncBiometricPilot);

router.get('/membership-templates', membershipController.getTemplates);
router.post('/membership-templates', membershipController.createTemplate);
router.patch('/membership-templates/:templateId', membershipController.updateTemplate);
router.delete('/membership-templates/:templateId', membershipController.deleteTemplate);
router.get('/membership-requests-new', membershipController.getRequests);
router.get('/membership-requests-new/:requestId', membershipController.getRequestById);
router.get('/membership-requests-new/:requestId/decision-preview', membershipController.getRequestDecisionPreview);
router.post('/membership-requests-new/:requestId/verify-payment', membershipController.verifyPayment);
router.post('/membership-requests-new/:requestId/approve', membershipController.approveRequest);
router.post('/membership-requests-new/:requestId/reject', membershipController.rejectRequest);
router.get('/member-memberships', membershipController.getAllMemberMemberships);
router.get('/members/:memberId/memberships', membershipController.getMemberMemberships);
router.post('/members/:memberId/memberships', membershipController.assignMembership);
router.post('/memberships/:membershipId/adjust', membershipController.adjustMembership);
router.post('/memberships/:membershipId/unfreeze', membershipController.unfreezeMembership);
router.post('/memberships/:membershipId/cancel', membershipController.cancelMembership);
router.get('/membership-audit-logs', membershipController.getAuditLogs);

module.exports = router;
