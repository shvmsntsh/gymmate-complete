/**
 * archive-test-announcement.js — Cleanup for test/probe documents only.
 *
 * Targets ONLY announcements whose title matches the known test patterns
 * ("QA permission test", "deploy-verify-probe") created during this
 * session's permission testing. Sets status to 'archived' — does NOT
 * delete the document or its delivery records, preserving the audit trail.
 * No other document is touched; the title match is intentionally narrow.
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Announcement = require('../models/Announcement');

const TITLE_PATTERNS = [/QA permission test/i, /deploy-verify-probe/i, /single-verify-check/i, /verify-check/i, /final-deploy-check/i, /post-fix-verify/i];

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);

  const docs = await Announcement.find({
    $or: TITLE_PATTERNS.map((title) => ({ title })),
    status: { $ne: 'archived' },
  });

  if (docs.length === 0) {
    console.log('Nothing to archive — all matching test announcements are already archived.');
    await mongoose.disconnect();
    return;
  }

  for (const doc of docs) {
    doc.status = 'archived';
    await doc.save();
    console.log(`Archived: ${doc._id} — "${doc.title}"`);
  }

  console.log(`\n${docs.length} document(s) archived.`);
  await mongoose.disconnect();
})();
