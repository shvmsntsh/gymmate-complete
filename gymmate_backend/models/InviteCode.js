const mongoose = require('mongoose');

const inviteCodeSchema = new mongoose.Schema({
  code: { type: String, required: true, unique: true },
  role: { type: String, required: true },
  gymId: { type: mongoose.Schema.Types.ObjectId, ref: 'Gym', required: function() { return this.role === 'gym_member'; } },
  gymName: { type: String },
  used: { type: Boolean, default: false },
  usedBy: { type: String, default: null },
}, { timestamps: true });

inviteCodeSchema.post('save', function(error, doc, next) {
  if (error) {
    console.error('❌ InviteCode schema validation error:', error);
  }
  next(error);
});

console.log('📦 InviteCode model loaded');

const InviteCode = mongoose.model('InviteCode', inviteCodeSchema);

async function markInviteCodeAsUsed(inviteCode, email) {
  console.log(`🔍 Searching for invite code: ${inviteCode}`);
  const inviteDoc = await InviteCode.findOne({ code: inviteCode, used: false });
  console.log('✅ Invite code document found:', inviteDoc);

  if (!inviteDoc) {
    throw new Error('Invalid or already used invite code');
  }

  inviteDoc.used = true;
  inviteDoc.updatedAt = new Date();
  inviteDoc.usedBy = email;

  try {
    const saved = await inviteDoc.save();
    console.log(`✅ Invite code ${inviteCode} marked as used by ${email}`);
    console.log('📄 Saved InviteCode document:', saved.toObject());
  } catch (saveErr) {
    console.error(`❌ Failed to save invite code usage:`, saveErr);
    console.error('🚨 Current inviteDoc state before save failure:', inviteDoc.toObject());
    throw new Error('Failed to mark invite code as used');
  }

  const result = {
    role: inviteDoc.role,
    gymId: inviteDoc.gymId
  };

  console.log('📤 Returning invite info:', result);
  return result;
}

module.exports = {
  InviteCode,
  markInviteCodeAsUsed
};