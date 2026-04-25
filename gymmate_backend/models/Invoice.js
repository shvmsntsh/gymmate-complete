const mongoose = require('mongoose');

const invoiceSchema = new mongoose.Schema(
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
    paymentEntryId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'PaymentEntry',
      default: null,
    },
    receiptId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'BillingReceipt',
      default: null,
    },
    invoiceNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['draft', 'issued', 'paid', 'void'],
      default: 'issued',
      index: true,
    },
    subtotal: {
      type: Number,
      default: 0,
      min: 0,
    },
    taxAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    total: {
      type: Number,
      default: 0,
      min: 0,
    },
    gstin: {
      type: String,
      default: '',
      trim: true,
      maxlength: 40,
    },
    hsnSac: {
      type: String,
      default: '',
      trim: true,
      maxlength: 40,
    },
    issuedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true },
);

invoiceSchema.index({ gymId: 1, issuedAt: -1 });

module.exports = mongoose.model('Invoice', invoiceSchema);
