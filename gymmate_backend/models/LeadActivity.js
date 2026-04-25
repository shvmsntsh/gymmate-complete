const mongoose = require('mongoose');

const leadActivitySchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    leadId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Lead',
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ['note', 'call', 'whatsapp', 'visit', 'trial', 'status_change', 'assignment', 'conversion'],
      default: 'note',
    },
    note: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1200,
    },
    nextFollowUpAt: {
      type: Date,
      default: null,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  { timestamps: true },
);

leadActivitySchema.index({ leadId: 1, createdAt: -1 });

module.exports = mongoose.model('LeadActivity', leadActivitySchema);
