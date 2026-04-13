const mongoose = require('mongoose');

const membershipAuditLogSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    memberId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    entityType: {
      type: String,
      enum: ['membership_template', 'member_membership', 'membership_change_request'],
      required: true,
    },
    entityId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
    },
    action: {
      type: String,
      required: true,
      enum: [
        'created',
        'updated',
        'activated',
        'queued',
        'deactivated',
        'expired',
        'frozen',
        'unfrozen',
        'renewed',
        'upgraded',
        'downgraded',
        'canceled',
        'rejected',
        'payment_verified',
        'payment_received',
        'request_approved',
        'request_rejected',
        'request_submitted',
        'owner_adjusted',
        'entitlements_updated',
      ],
    },
    performedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    payload: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  { timestamps: true }
);

membershipAuditLogSchema.index({ gymId: 1, memberId: 1, createdAt: -1 });
membershipAuditLogSchema.index({ entityType: 1, entityId: 1 });
membershipAuditLogSchema.index({ createdAt: -1 });

module.exports = mongoose.model('MembershipAuditLog', membershipAuditLogSchema);
