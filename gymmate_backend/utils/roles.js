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

// Baseline permissions granted to EVERY gym_staff account unconditionally.
// Kept intentionally minimal: workspace.access only lets a staff member load
// the empty workspace shell and log in — it exposes no member, payment, or
// announcement data. Every other capability (members.view, members.manage,
// announcements.manage, membership.requests.manage, payments.manage,
// receipts.view, etc.) must come from the owner's explicit per-staff
// staffCapabilities selection via getExplicitStaffPermissions() below.
// STAFF_FULL_PERMISSIONS lists every permission a staff member CAN be
// granted (used by OWNER_PERMISSIONS, which is unrestricted), separate from
// the baseline that's actually auto-granted.
const STAFF_BASELINE_PERMISSIONS = new Set([
  'workspace.access',
]);

const STAFF_FULL_PERMISSIONS = new Set([
  'workspace.access',
  'members.view',
  'members.manage',
  'announcements.manage',
  'membership.requests.manage',
  'payments.manage',
  'receipts.view',
]);

const OWNER_PERMISSIONS = new Set([
  ...STAFF_FULL_PERMISSIONS,
  'membership.plans.manage',
  'biometric.manage',
  'staff.manage',
  'campaigns.manage',
  'settings.manage',
  'inventory.manage',
  'ai.insights.view',
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

// staffCapabilities is defined via dot-notation schema paths (e.g.
// 'workspace.access', 'announcements.manage'), which Mongoose compiles into
// genuinely NESTED subdocuments — a saved doc looks like
// { workspace: { access: true }, announcements: { manage: true } }, not a
// flat object with dotted keys. This recursively flattens it back into
// dotted permission strings ('workspace.access', 'announcements.manage'),
// mirroring flattenCapabilityEntries() in gymmate_admin_vite/src/lib/api.js.
// A shallow Object.entries() here would only see top-level keys like
// 'workspace' — Boolean({access:true}) is true, so it wouldn't error, but
// permissionKey('workspace') never matches a real permission string like
// 'workspace.access', silently discarding every explicit grant.
function flattenStaffCapabilities(source, prefix = '') {
  if (!source || typeof source !== 'object') return [];
  return Object.entries(source).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === 'object') {
      return flattenStaffCapabilities(value, path);
    }
    return value ? [path] : [];
  });
}

function getExplicitStaffPermissions(subject) {
  const raw = subject?.staffCapabilities;
  if (!raw) return [];
  // Normalize Mongoose (sub)documents to a plain object before recursing,
  // so we only ever walk real data fields, not Mongoose internals/methods.
  const capabilities = typeof raw.toObject === 'function' ? raw.toObject() : raw;
  return flattenStaffCapabilities(capabilities)
    .map((key) => permissionKey(key))
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
    STAFF_BASELINE_PERMISSIONS.forEach((permission) => permissions.add(permission));
    getExplicitStaffPermissions(subject).forEach((permission) =>
      permissions.add(permission),
    );
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
  // Every permission a staff member CAN be granted (via staffCapabilities).
  // Not auto-granted — see STAFF_BASELINE_PERMISSIONS above for what's
  // actually unconditional.
  STAFF_PERMISSIONS: Array.from(STAFF_FULL_PERMISSIONS),
};
