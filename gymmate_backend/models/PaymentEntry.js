const mongoose = require('mongoose');

const paymentEntrySchema = new mongoose.Schema(
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
      required: true,
      index: true,
    },
    membershipId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MemberMembership',
      default: null,
    },
    membershipRequestId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'MembershipChangeRequest',
      default: null,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    mode: {
      type: String,
      enum: ['cash', 'upi', 'card', 'online', 'manual', 'waived'],
      required: true,
    },
    reference: {
      type: String,
      default: '',
      trim: true,
      maxlength: 120,
    },
    note: {
      type: String,
      default: '',
      trim: true,
      maxlength: 500,
    },
    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    recordedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true },
);

paymentEntrySchema.index({ gymId: 1, memberId: 1, recordedAt: -1 });

module.exports = mongoose.model('PaymentEntry', paymentEntrySchema);
