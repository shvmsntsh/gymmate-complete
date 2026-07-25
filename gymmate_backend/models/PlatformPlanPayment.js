const mongoose = require('mongoose');

// Immutable ledger of manually-recorded platform payments — a gym owner
// pays GymMate outside the app (cash/UPI/bank transfer), and a superadmin
// records it here via POST /api/admin/gyms/:gymId/plan-payment. Create +
// list only; there is no update/delete route, matching the audit-trail
// pattern already used for Gym.planUpdatedBy/planUpdatedAt.
const platformPlanPaymentSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    planKey: {
      type: String,
      required: true,
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
      enum: ['cash', 'upi', 'bank_transfer', 'cheque', 'other'],
      required: true,
    },
    periodStart: {
      type: Date,
      required: true,
    },
    periodEnd: {
      type: Date,
      required: true,
    },
    reference: {
      type: String,
      default: '',
      trim: true,
      maxlength: 200,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
      maxlength: 1000,
    },
    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true },
);

platformPlanPaymentSchema.index({ gymId: 1, createdAt: -1 });

module.exports = mongoose.model('PlatformPlanPayment', platformPlanPaymentSchema);
