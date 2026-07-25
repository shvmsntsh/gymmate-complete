/** Read-only: locate the test announcement created during permission testing. */
require('dotenv').config();
const mongoose = require('mongoose');
const Announcement = require('../models/Announcement');

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  const docs = await Announcement.find({ title: /QA permission test/i }).lean();
  console.log(JSON.stringify(docs, null, 2));
  await mongoose.disconnect();
})();
