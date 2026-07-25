/**
 * migrate-platform-plans.js — Move existing gyms from the old platformPlan
 * enum (launch_50/studio_100/growth_1000/scale_5000/enterprise_10000/custom)
 * onto the new pricing tiers (starter/growth/pro/elite/custom).
 *
 * SAFETY: non-destructive. Only updates Gym.platformPlan and Gym.memberCap
 * (recomputed for the new tier). Never touches custom-tier gyms' existing
 * memberCap. Does NOT fabricate any PlatformPlanPayment history for
 * pre-existing gyms — their payment ledger starts empty; planPaidUntil
 * stays null until a superadmin records their first real payment.
 *
 * Usage:
 *   node scripts/migrate-platform-plans.js --dry-run
 *   node scripts/migrate-platform-plans.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const Gym = require('../models/Gym');
const { getPlanCap } = require('../utils/platformPlans');

const DRY_RUN = process.argv.includes('--dry-run');

// Mapped by nominal capacity, not by name — e.g. growth_1000 (cap 1000)
// maps to 'pro' (new cap 1000), not the new 'growth' tier (cap 500).
const OLD_TO_NEW = {
  launch_50: 'starter',
  studio_100: 'starter',
  growth_1000: 'pro',
  scale_5000: 'elite',
  enterprise_10000: 'elite',
  custom: 'custom',
};

async function main() {
  const MONGODB_URI = process.env.MONGODB_URI || process.env.MONGO_URI;
  if (!MONGODB_URI) {
    console.error('MONGODB_URI (or MONGO_URI) is required.');
    process.exit(1);
  }

  console.log(DRY_RUN ? 'DRY RUN — nothing will be written.' : 'LIVE RUN — writing to the database.');
  await mongoose.connect(MONGODB_URI);

  // Read raw (bypass the enum validator, which no longer accepts the old
  // values) so we can see every gym's current stored value.
  const gyms = await mongoose.connection.db.collection('gyms').find({}).toArray();

  let updated = 0;
  let skipped = 0;
  for (const gym of gyms) {
    const oldKey = gym.platformPlan;
    const newKey = OLD_TO_NEW[oldKey];

    if (!newKey) {
      console.log(`SKIP  ${gym.gymName || gym._id} — unrecognized platformPlan "${oldKey}"`);
      skipped += 1;
      continue;
    }
    if (oldKey === newKey) {
      console.log(`SKIP  ${gym.gymName || gym._id} — already "${newKey}"`);
      skipped += 1;
      continue;
    }

    // Custom-tier gyms keep their existing custom memberCap untouched.
    const newMemberCap = newKey === 'custom' ? gym.memberCap : getPlanCap(newKey);

    console.log(
      `${DRY_RUN ? 'WOULD UPDATE' : 'UPDATE'}  ${gym.gymName || gym._id}: ` +
      `platformPlan "${oldKey}" -> "${newKey}", memberCap ${gym.memberCap} -> ${newMemberCap}`,
    );

    if (!DRY_RUN) {
      await mongoose.connection.db.collection('gyms').updateOne(
        { _id: gym._id },
        { $set: { platformPlan: newKey, memberCap: newMemberCap } },
      );
    }
    updated += 1;
  }

  console.log('');
  console.log(`${DRY_RUN ? 'Would update' : 'Updated'}: ${updated}   Skipped: ${skipped}   Total: ${gyms.length}`);

  await mongoose.disconnect();
}

main().catch(async (err) => {
  console.error('FAILED:', err.message);
  try { await mongoose.disconnect(); } catch (_) {}
  process.exit(1);
});
