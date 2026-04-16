const express = require('express');
const receiptController = require('../controllers/receiptController');

const router = express.Router();

router.get('/:token', receiptController.getPublicReceipt);

module.exports = router;
