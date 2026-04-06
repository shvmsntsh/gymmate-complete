const express = require('express');

const { authenticateToken } = require('../middleware/authMiddleware');
const messageController = require('../controllers/messageController');

const router = express.Router();

router.use(authenticateToken);

router.get('/conversations', messageController.getConversations);
router.post('/conversations', messageController.createConversation);
router.get('/conversations/:id/messages', messageController.getConversationMessages);
router.post('/conversations/:id/messages', messageController.postMessage);

module.exports = router;
