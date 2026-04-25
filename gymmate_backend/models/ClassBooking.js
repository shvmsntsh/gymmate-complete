const mongoose = require('mongoose');

const classBookingSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    sessionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ClassSession',
      required: true,
      index: true,
    },
    memberId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['booked', 'cancelled', 'attended', 'no_show'],
      default: 'booked',
      index: true,
    },
    bookedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    cancelledAt: {
      type: Date,
      default: null,
    },
    attendedAt: {
      type: Date,
      default: null,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
      maxlength: 500,
    },
  },
  { timestamps: true },
);

classBookingSchema.index({ sessionId: 1, memberId: 1 }, { unique: true });
classBookingSchema.index({ gymId: 1, status: 1, createdAt: -1 });

module.exports = mongoose.model('ClassBooking', classBookingSchema);
