/** Read-only: locate all test/probe announcements created during permission testing. */
require('dotenv').config();
const mongoose = require('mongoose');
const Announcement = require('../models/Announcement');

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  const docs = await Announcement.find({
    $or: [
      { title: /QA permission test/i },
      { title: /deploy-verify-probe/i },
    ],
  }).lean();
  console.log(JSON.stringify(docs.map(d => ({ id: d._id, title: d.title, status: d.status })), null, 2));
  console.log(`\nTotal matching: ${docs.length}`);
  await mongoose.disconnect();
})();
