/**
 * repair-stuck-invite-claim.js — Undo a partially-completed quick-login
 * caused by a cold-start function timeout mid-request.
 *
 * Targets ONE specific invite code. Resets it to unused (matching the
 * pre-claim state) ONLY if the linked User never actually finished
 * registering (registered:false) — i.e., the claim never truly completed.
 * Does not touch any other document.
 */
require('dotenv').config();
const mongoose = require('mongoose');
const { InviteCode } = require('../models/InviteCode');
const User = require('../models/User');

const CODE = process.argv[2];
if (!CODE) {
  console.error('Usage: node repair-stuck-invite-claim.js <CODE>');
  process.exit(1);
}

(async () => {
  await mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI);

  const invite = await InviteCode.findOne({ code: CODE });
  if (!invite) {
    console.log('No invite found with that code.');
    await mongoose.disconnect();
    return;
  }
  if (!invite.used) {
    console.log('Invite is already unused — nothing to repair.');
    await mongoose.disconnect();
    return;
  }

  const user = await User.findOne({ phone_number: invite.inviteePhone, role: invite.role });
  if (user && user.registered) {
    console.log('SAFETY ABORT: linked user already completed registration. Not touching this invite.');
    await mongoose.disconnect();
    process.exit(1);
  }

  invite.used = false;
  invite.usedAt = null;
  invite.usedBy = null;
  await invite.save();
  console.log(`Repaired: ${invite.code} reset to unused (user registered=${user?.registered ?? 'no user found'})`);

  await mongoose.disconnect();
})();
