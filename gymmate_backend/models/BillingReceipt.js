const mongoose = require('mongoose');

const billingReceiptSchema = new mongoose.Schema(
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
      required: true,
      unique: true,
      index: true,
    },
    planName: {
      type: String,
      required: true,
      trim: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    currency: {
      type: String,
      default: 'INR',
    },
    paymentMethod: {
      type: String,
      default: '',
      trim: true,
    },
    paymentReference: {
      type: String,
      default: '',
      trim: true,
    },
    receiptNumber: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    publicToken: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    issuedAt: {
      type: Date,
      default: Date.now,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true },
);

billingReceiptSchema.index({ gymId: 1, memberId: 1, issuedAt: -1 });

module.exports = mongoose.model('BillingReceipt', billingReceiptSchema);
