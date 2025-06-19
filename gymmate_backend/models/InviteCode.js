const mongoose = require('mongoose');

const inviteCodeSchema = new mongoose.Schema({
  code: { type: String, required: true, unique: true },
  role: { type: String, required: true },
  gymId: { type: mongoose.Schema.Types.ObjectId, ref: 'Gym' },
  used: { type: Boolean, default: false },
  usedBy: { type: String, default: null },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

const InviteCode = mongoose.model('InviteCode', inviteCodeSchema);

async function markInviteCodeAsUsed(inviteCode, email) {
  const inviteDoc = await InviteCode.findOne({ code: inviteCode, used: false });

  if (!inviteDoc) {
    throw new Error('Invalid or already used invite code');
  }

  inviteDoc.used = true;
  inviteDoc.updatedAt = new Date();
  inviteDoc.usedBy = email;

  try {
    await inviteDoc.save();
    console.log(`✅ Invite code ${inviteCode} marked as used by ${email}`);
  } catch (saveErr) {
    console.error(`❌ Failed to save invite code usage:`, saveErr);
    throw new Error('Failed to mark invite code as used');
  }

  return {
    role: inviteDoc.role,
    gymId: inviteDoc.gymId
  };
}

module.exports = {
  InviteCode,
  markInviteCodeAsUsed
};