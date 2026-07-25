/** Read-only document counter. Used to prove --dry-run writes nothing. */
require('dotenv').config();
const mongoose = require('mongoose');

const models = {
  User: require('../models/User'),
  Gym: require('../models/Gym'),
  InviteCode: require('../models/InviteCode').InviteCode,
  MembershipPlanCatalog: require('../models/MembershipPlanCatalog'),
  MemberMembership: require('../models/MemberMembership'),
  PaymentEntry: require('../models/PaymentEntry'),
  AttendanceEvent: require('../models/AttendanceEvent'),
  TrainerAssignment: require('../models/TrainerAssignment'),
  Announcement: require('../models/Announcement'),
};

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);
  const out = {};
  for (const [name, M] of Object.entries(models)) {
    out[name] = await M.countDocuments({});
  }
  console.log(JSON.stringify(out));
  await mongoose.disconnect();
})();
