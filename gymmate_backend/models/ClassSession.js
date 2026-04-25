const mongoose = require('mongoose');

const classSessionSchema = new mongoose.Schema(
  {
    gymId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Gym',
      required: true,
      index: true,
    },
    templateId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ClassTemplate',
      required: true,
      index: true,
    },
    trainerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
      index: true,
    },
    startsAt: {
      type: Date,
      required: true,
      index: true,
    },
    endsAt: {
      type: Date,
      required: true,
    },
    capacity: {
      type: Number,
      default: 10,
      min: 1,
      max: 500,
    },
    status: {
      type: String,
      enum: ['scheduled', 'open', 'full', 'completed', 'cancelled'],
      default: 'scheduled',
      index: true,
    },
    location: {
      type: String,
      default: '',
      trim: true,
      maxlength: 120,
    },
    notes: {
      type: String,
      default: '',
      trim: true,
      maxlength: 800,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
  },
  { timestamps: true },
);

classSessionSchema.index({ gymId: 1, startsAt: 1, status: 1 });

module.exports = mongoose.model('ClassSession', classSessionSchema);
