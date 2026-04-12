const PLATFORM_PLAN_TIERS = [
  { key: 'launch_50', name: 'Launch 50', memberCap: 50 },
  { key: 'studio_100', name: 'Studio 100', memberCap: 100 },
  { key: 'growth_1000', name: 'Growth 1000', memberCap: 1000 },
  { key: 'scale_5000', name: 'Scale 5000', memberCap: 5000 },
  { key: 'enterprise_10000', name: 'Enterprise 10000', memberCap: 10000 },
  { key: 'custom', name: 'Custom', memberCap: null },
];

const DEFAULT_PLATFORM_PLAN_KEY = 'launch_50';

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

module.exports = {
  DEFAULT_PLATFORM_PLAN_KEY,
  PLATFORM_PLAN_TIERS,
  getPlanCap,
  getPlanTier,
};
