const ROLE_ALIASES = {
  superadmin: 'admin',
  admin: 'admin',
  gym_owner: 'owner',
  owner: 'owner',
  gym_staff: 'staff',
  staff: 'staff',
  gym_trainer: 'trainer',
  trainer: 'trainer',
  gym_member: 'member',
  member: 'member',
};

const STAFF_PERMISSIONS = new Set([
  'workspace.access',
  'members.manage',
  'announcements.manage',
  'membership.requests.manage',
  'payments.manage',
]);

const OWNER_PERMISSIONS = new Set([
  ...STAFF_PERMISSIONS,
  'membership.plans.manage',
  'biometric.manage',
]);

const ADMIN_PERMISSIONS = new Set([
  ...OWNER_PERMISSIONS,
  'gyms.manage',
]);

const TRAINER_PERMISSIONS = new Set([
  'coach.assigned_members',
  'messages.trainer',
]);

function permissionKey(flag) {
  if (!flag) return null;
  return String(flag).trim();
}

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

function getExplicitStaffPermissions(subject) {
  const capabilities = subject?.staffCapabilities || {};
  return Object.entries(capabilities)
    .filter(([, enabled]) => Boolean(enabled))
    .map(([key]) => permissionKey(key))
    .filter(Boolean);
}

function getPermissions(subject) {
  const subjectRole = normalizeRole(subject?.normalizedRole || subject?.role || subject);
  const permissions = new Set();

  if (subjectRole === 'admin') {
    ADMIN_PERMISSIONS.forEach((permission) => permissions.add(permission));
  }

  if (subjectRole === 'owner') {
    OWNER_PERMISSIONS.forEach((permission) => permissions.add(permission));
  }

  if (subjectRole === 'staff') {
    STAFF_PERMISSIONS.forEach((permission) => permissions.add(permission));
  }

  if (subjectRole === 'trainer') {
    TRAINER_PERMISSIONS.forEach((permission) => permissions.add(permission));
    getExplicitStaffPermissions(subject).forEach((permission) =>
      permissions.add(permission),
    );
  }

  return Array.from(permissions);
}

function hasPermission(subject, permission) {
  return getPermissions(subject).includes(permissionKey(permission));
}

module.exports = {
  normalizeRole,
  hasRole,
  hasPermission,
  getPermissions,
  STAFF_PERMISSIONS: Array.from(STAFF_PERMISSIONS),
};
