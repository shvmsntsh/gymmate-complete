/**
 * archive-test-announcement.js — Cleanup for ONE specific test document.
 *
 * Targets exactly _id 6a64a9773e5a1c6c149d5161 (verified via
 * find-test-announcement.js as the "QA permission test" announcement
 * created accidentally during permission testing). Sets status to
 * 'archived' — does NOT delete the document or its delivery records,
 * preserving the audit trail. No other document is touched.
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Announcement = require('../models/Announcement');

const TARGET_ID = '6a64a9773e5a1c6c149d5161';
const EXPECTED_TITLE = 'QA permission test - should be rejected';

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);

  const doc = await Announcement.findById(TARGET_ID);
  if (!doc) {
    console.log('Document not found — nothing to do.');
    await mongoose.disconnect();
    return;
  }
  if (doc.title !== EXPECTED_TITLE) {
    console.error(`SAFETY ABORT: title mismatch. Expected "${EXPECTED_TITLE}", found "${doc.title}". Not touching this document.`);
    await mongoose.disconnect();
    process.exit(1);
  }

  doc.status = 'archived';
  await doc.save();
  console.log(`Archived: ${doc._id} — "${doc.title}" (status: ${doc.status})`);

  await mongoose.disconnect();
})();
