const DEFAULT_SERVICE_NAMES = [
  'Strength Training',
  'Cardio',
  'Personal Training',
  'Yoga',
  'Pilates',
  'CrossFit',
  'HIIT',
  'Zumba',
  'Boxing/MMA',
  'Swimming',
  'Physiotherapy',
  'Nutrition Coaching',
  'Sauna/Steam',
  'Locker',
  'Group Classes',
  'Kids Fitness',
  'Sports Conditioning',
  'Recovery/Mobility',
];

function normalizeServiceName(value) {
  return String(value || '')
    .trim()
    .replace(/\s+/g, ' ');
}

function serviceSlug(value) {
  return normalizeServiceName(value)
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function normalizeServices(services) {
  const raw = Array.isArray(services)
    ? services.flatMap((service) => String(service || '').split(','))
    : typeof services === 'string'
      ? services.split(',')
      : [];

  const seen = new Set();
  return raw
    .map(normalizeServiceName)
    .filter(Boolean)
    .filter((service) => {
      const slug = serviceSlug(service);
      if (!slug || seen.has(slug)) return false;
      seen.add(slug);
      return true;
    });
}

function servicesToCatalogItems(services) {
  return normalizeServices(services).map((name) => ({
    name,
    slug: serviceSlug(name),
  }));
}

module.exports = {
  DEFAULT_SERVICE_NAMES,
  normalizeServiceName,
  normalizeServices,
  serviceSlug,
  servicesToCatalogItems,
};
