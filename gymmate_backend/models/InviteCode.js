const mongoose = require('mongoose');

const inviteCodeSchema = new mongoose.Schema({
  code: { type: String, required: true, unique: true },
  role: { type: String, required: true },
  gymId: { type: mongoose.Schema.Types.ObjectId, ref: 'Gym', required: function() { return ['gym_member', 'gym_trainer', 'gym_staff'].includes(this.role); } },
  gymName: { type: String },
  inviteeName: { type: String, default: '' },
  inviteeEmail: { type: String, default: '' },
  inviteePhone: { type: String, default: '' },
  used: { type: Boolean, default: false },
  usedBy: { type: mongoose.Schema.Types.Mixed, default: null },
  usedAt: { type: Date, default: null },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
}, { timestamps: true });

inviteCodeSchema.index({ gymId: 1, role: 1, used: 1 });
inviteCodeSchema.index({ inviteePhone: 1, role: 1, used: 1 });

inviteCodeSchema.post('save', function(error, doc, next) {
  if (error) {
    console.error('❌ InviteCode schema validation error:', error);
  }
  next(error);
});


const InviteCode = mongoose.model('InviteCode', inviteCodeSchema);

async function markInviteCodeAsUsed(inviteCode, email) {
  const inviteDoc = await InviteCode.findOne({ code: inviteCode, used: false });

  if (!inviteDoc) {
    throw new Error('Invalid or already used invite code');
  }

  inviteDoc.used = true;
  inviteDoc.usedAt = new Date();
  inviteDoc.usedBy = email;

  try {
    const saved = await inviteDoc.save();
  } catch (saveErr) {
    console.error(`❌ Failed to save invite code usage:`, saveErr);
    console.error('🚨 Current inviteDoc state before save failure:', inviteDoc.toObject());
    throw new Error('Failed to mark invite code as used');
  }

  const result = {
    role: inviteDoc.role,
    gymId: inviteDoc.gymId
  };

  return result;
}

module.exports = {
  InviteCode,
  markInviteCodeAsUsed
};
