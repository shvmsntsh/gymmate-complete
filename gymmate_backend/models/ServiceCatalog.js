const mongoose = require('mongoose');

const serviceCatalogSchema = new mongoose.Schema({
  name: { type: String, required: true },
  slug: { type: String, required: true, unique: true },
  source: {
    type: String,
    enum: ['default', 'custom'],
    default: 'default',
  },
  usageCount: { type: Number, default: 0 },
}, { timestamps: true });

module.exports = mongoose.model('ServiceCatalog', serviceCatalogSchema);
