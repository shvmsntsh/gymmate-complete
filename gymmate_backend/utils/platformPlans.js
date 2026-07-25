// Platform pricing tiers — per-active-member pricing, matching the
// GymMate training/pricing deck exactly. memberCap is a SOFT band used to
// size the tier and to nudge upgrades; it is not a hard seat block (see
// utils/gymLimits.js — isLocked is driven by planStatus, not cap overage).
const PLATFORM_PLAN_TIERS = [
  { key: 'starter', name: 'Starter', memberCap: 100, pricePerMember: 18, floorPrice: 899 },
  { key: 'growth', name: 'Growth', memberCap: 500, pricePerMember: 15, floorPrice: 0 },
  { key: 'pro', name: 'Pro', memberCap: 1000, pricePerMember: 12, floorPrice: 0 },
  { key: 'elite', name: 'Elite', memberCap: null, pricePerMember: 10, floorPrice: 0 },
  { key: 'custom', name: 'Custom', memberCap: null, pricePerMember: null, floorPrice: null },
];

const DEFAULT_PLATFORM_PLAN_KEY = 'starter';

function getPlanTier(key) {
  return (
    PLATFORM_PLAN_TIERS.find((tier) => tier.key === key) ||
    PLATFORM_PLAN_TIERS.find((tier) => tier.key === DEFAULT_PLATFORM_PLAN_KEY)
  );
}

function getPlanCap(key, customCap) {
  const tier = getPlanTier(key);
  if (tier.key === 'custom') {
    const parsed = Number(customCap);
    return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 50;
  }
  return tier.memberCap;
}

// Monthly amount due = max(floor, activeMembers * pricePerMember).
// For 'custom' tier, rate/floor come from the gym's own override fields
// (Gym.customPricePerMember / Gym.customFloorPrice) since Custom is
// negotiated per gym, not fixed in this table.
function getMonthlyAmountDue(key, activeMemberCount, customPricePerMember, customFloorPrice) {
  const tier = getPlanTier(key);
  const count = Number.isFinite(Number(activeMemberCount)) ? Math.max(0, Number(activeMemberCount)) : 0;

  let rate = tier.pricePerMember;
  let floor = tier.floorPrice;
  if (tier.key === 'custom') {
    rate = Number.isFinite(Number(customPricePerMember)) ? Number(customPricePerMember) : 0;
    floor = Number.isFinite(Number(customFloorPrice)) ? Number(customFloorPrice) : 0;
  }

  const metered = count * (rate || 0);
  return Math.max(floor || 0, metered);
}

module.exports = {
  DEFAULT_PLATFORM_PLAN_KEY,
  PLATFORM_PLAN_TIERS,
  getPlanCap,
  getPlanTier,
  getMonthlyAmountDue,
};
