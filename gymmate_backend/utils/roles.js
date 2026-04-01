const ROLE_ALIASES = {
  superadmin: 'admin',
  admin: 'admin',
  gym_owner: 'owner',
  owner: 'owner',
  gym_trainer: 'trainer',
  trainer: 'trainer',
  gym_member: 'member',
  member: 'member',
};

function normalizeRole(role) {
  if (!role) return null;
  return ROLE_ALIASES[String(role).trim().toLowerCase()] || null;
}

function hasRole(subject, allowedRoles) {
  const subjectRole = normalizeRole(subject?.normalizedRole || subject?.role || subject);
  if (!subjectRole) return false;

  return allowedRoles
    .map(normalizeRole)
    .filter(Boolean)
    .includes(subjectRole);
}

module.exports = {
  normalizeRole,
  hasRole,
};
