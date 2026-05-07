const normalizeBase = (value) => (value || "").replace(/\/$/, "");

const inferDefaultBase = () => {
  if (typeof window !== "undefined") {
    const { hostname, protocol } = window.location;
    const isLocalHost = hostname === "localhost" || hostname === "127.0.0.1";
    if (isLocalHost) {
      return `${protocol}//127.0.0.1:5050`;
    }
    return "";
  }
  return "https://gymmate-backend.vercel.app";
};

export const normalizeRole = (role) => {
  const value = String(role || "")
    .trim()
    .toLowerCase();

  if (value === "superadmin" || value === "admin") return "admin";
  if (value === "gym_owner" || value === "owner") return "owner";
  if (value === "gym_staff" || value === "staff") return "staff";
  if (value === "gym_trainer" || value === "trainer") return "trainer";
  if (value === "gym_member" || value === "member") return "member";

  return value;
};

const STAFF_PERMISSIONS = [
  "workspace.access",
  "members.view",
  "members.manage",
  "announcements.manage",
  "membership.requests.manage",
  "payments.manage",
  "receipts.view",
];

const OWNER_PERMISSIONS = [
  ...STAFF_PERMISSIONS,
  "billing.manage",
  "attendance.manage",
  "leads.manage",
  "classes.manage",
  "reports.view",
  "membership.plans.manage",
  "biometric.manage",
  "staff.manage",
  "campaigns.manage",
  "settings.manage",
  "inventory.manage",
  "ai.insights.view",
];
const ADMIN_PERMISSIONS = [...OWNER_PERMISSIONS, "gyms.manage"];

const ROLE_PERMISSIONS = {
  admin: ADMIN_PERMISSIONS,
  owner: OWNER_PERMISSIONS,
  staff: [],
  trainer: [],
};

function flattenCapabilityEntries(source, prefix = "") {
  if (!source || typeof source !== "object") return [];

  return Object.entries(source).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    if (value && typeof value === "object") {
      return flattenCapabilityEntries(value, path);
    }
    return value ? [path] : [];
  });
}

const ADMIN_ROUTE_RULES = {
  AdminDashboard: {
    nav: { icon: "mdi-view-dashboard-outline", label: "Dashboard", to: "/dashboard", group: "Today" },
    roles: ["admin", "owner", "staff"],
  },
  CrmWorkspace: {
    nav: { icon: "mdi-account-search-outline", label: "Leads", to: "/crm", group: "Growth" },
    roles: ["admin", "owner", "staff"],
    permissions: ["leads.manage"],
  },
  MemberWorkspace: {
    nav: { icon: "mdi-account-group-outline", label: "Members", to: "/members", group: "Front Desk" },
    roles: ["admin", "owner", "staff"],
    permissions: ["members.view", "members.manage"],
  },
  PaymentWorkspace: {
    nav: { icon: "mdi-cash-register", label: "Payments", to: "/payments", group: "Front Desk" },
    roles: ["admin", "owner", "staff"],
    permissions: ["billing.manage", "payments.manage"],
  },
  AttendanceWorkspace: {
    nav: { icon: "mdi-calendar-check-outline", label: "Attendance", to: "/attendance", group: "Front Desk" },
    roles: ["admin", "owner", "staff"],
    permissions: ["attendance.manage"],
  },
  ClassesWorkspace: {
    nav: { icon: "mdi-calendar-clock", label: "Classes & PT", to: "/classes", group: "Front Desk" },
    roles: ["admin", "owner", "staff", "trainer"],
    permissions: ["classes.manage"],
  },
  StaffWorkspace: {
    nav: { icon: "mdi-badge-account-horizontal-outline", label: "Staff", to: "/staff", group: "Setup" },
    roles: ["admin", "owner"],
    permissions: ["staff.manage"],
  },
  NetworkControl: {
    nav: { icon: "mdi-domain", label: "Gyms & Users", to: "/network", group: "Platform" },
    roles: ["admin"],
  },
  ManageMembers: {
    roles: ["admin", "owner", "staff"],
    permissions: ["members.manage"],
  },
  Announcements: {
    nav: { icon: "mdi-bullhorn-outline", label: "Announcements", to: "/announcements", group: "Growth" },
    roles: ["admin", "owner", "staff"],
  },
  MembershipOps: {
    nav: { icon: "mdi-card-account-details-outline", label: "Plans & Memberships", to: "/membership", group: "Setup" },
    roles: ["admin", "owner", "staff"],
    permissions: ["membership.requests.manage", "membership.plans.manage"],
  },
  Membership: {
    nav: { icon: "mdi-card-account-details-outline", label: "Plans & Memberships", to: "/membership", group: "Setup" },
    roles: ["admin", "owner", "staff"],
    permissions: ["membership.requests.manage", "membership.plans.manage"],
  },
  Invites: {
    nav: { icon: "mdi-ticket-confirmation-outline", label: "Invites", to: "/invites", group: "Growth" },
    roles: ["admin", "owner"],
  },
  BrandingStudio: {
    nav: { icon: "mdi-palette-outline", label: "Branding", to: "/branding", group: "Setup" },
    roles: ["owner"],
  },
  BiometricOps: {
    nav: { icon: "mdi-fingerprint", label: "Biometric Setup", to: "/biometric", group: "Setup" },
    roles: ["owner"],
  },
  RegisterGym: {
    nav: { icon: "mdi-domain-plus", label: "Register Gym", to: "/register-gym", group: "Platform" },
    roles: ["admin"],
  },
  SystemHealth: {
    nav: { icon: "mdi-heart-pulse", label: "System Health", to: "/system-health", group: "Platform" },
    roles: ["admin"],
  },
  Settings: {
    nav: { icon: "mdi-cog-outline", label: "Settings", to: "/settings", group: "Setup" },
    roles: ["admin", "owner", "staff", "trainer"],
  },
  GymDetails: {
    roles: ["admin"],
  },
  ForgotPassword: {
    roles: ["admin", "owner", "staff"],
  },
};

export const API_BASE_URL = normalizeBase(
  import.meta.env?.VITE_API_BASE_URL || inferDefaultBase(),
);

const TOKEN_KEY = "gymmate_admin_token";
const SESSION_KEY = "gymmate_admin_session";

export function getAdminToken() {
  return localStorage.getItem(TOKEN_KEY) || "";
}

export function getAdminSession() {
  try {
    return JSON.parse(localStorage.getItem(SESSION_KEY) || "{}");
  } catch {
    return {};
  }
}

export function getAdminRole() {
  const session = getAdminSession();
  return normalizeRole(session?.user?.normalizedRole || session?.user?.role);
}

export function getAdminPermissions(input = null) {
  const session = input || getAdminSession();
  const role =
    typeof input === "string"
      ? normalizeRole(input)
      : normalizeRole(input?.user?.normalizedRole || input?.user?.role) ||
        (input ? null : getAdminRole());

  const basePermissions = ROLE_PERMISSIONS[role] || [];
  const explicit = flattenCapabilityEntries(session?.user?.staffCapabilities || {});

  return Array.from(new Set([...basePermissions, ...explicit]));
}

export function hasAdminPermission(permission, input = null) {
  return getAdminPermissions(input).includes(String(permission || "").trim());
}

export function isAdminSession() {
  return getAdminRole() === "admin";
}

export function isOwnerSession() {
  return getAdminRole() === "owner";
}

export function hasWorkspaceAccess(input = null) {
  return hasAdminPermission("workspace.access", input);
}

export function canAccessAdminRoute(routeName, input = null) {
  const rule = ADMIN_ROUTE_RULES[routeName];
  if (!rule) return true;

  const permissions = getAdminPermissions(input);
  const role =
    typeof input === "string"
      ? normalizeRole(input)
      : normalizeRole(input?.user?.normalizedRole || input?.user?.role) ||
        (input ? null : getAdminRole());

  if (!rule.roles.includes(role)) return false;
  if (!rule.permissions?.length || role === "admin" || role === "owner") return true;
  return rule.permissions.some((permission) => permissions.includes(permission));
}

export function getAdminNavItems(currentPath, input = null) {
  const seenTargets = new Set();
  const role =
    typeof input === "string"
      ? normalizeRole(input)
      : normalizeRole(input?.user?.normalizedRole || input?.user?.role) ||
        (input ? null : getAdminRole());

  return Object.entries(ADMIN_ROUTE_RULES)
    .filter(([routeName, rule]) => rule.nav && canAccessAdminRoute(routeName, input))
    .filter(([routeName]) => {
      if (role !== "admin") return true;
      return ["AdminDashboard", "NetworkControl", "Invites", "SystemHealth", "Settings", "RegisterGym"].includes(routeName);
    })
    .filter(([, rule]) => {
      if (seenTargets.has(rule.nav.to)) return false;
      seenTargets.add(rule.nav.to);
      return true;
    })
    .map(([, rule]) => ({
      ...rule.nav,
      group:
        role === "admin" && rule.nav.to !== "/settings"
          ? "Platform"
          : rule.nav.group,
      active:
        currentPath === rule.nav.to ||
        (rule.nav.to === "/membership" && currentPath === "/membership-new"),
    }));
}

export function getGroupedAdminNavItems(currentPath, input = null) {
  const role =
    typeof input === "string"
      ? normalizeRole(input)
      : normalizeRole(input?.user?.normalizedRole || input?.user?.role) ||
        (input ? null : getAdminRole());
  const groupOrder = role === "admin"
    ? ["Platform", "Setup"]
    : ["Today", "Front Desk", "Growth", "Setup"];
  const fallbackGroup = role === "admin" ? "Platform" : "More";
  const groups = new Map();

  getAdminNavItems(currentPath, input).forEach((item) => {
    const groupName = item.group || fallbackGroup;
    if (!groups.has(groupName)) {
      groups.set(groupName, []);
    }
    groups.get(groupName).push(item);
  });

  return Array.from(groups.entries())
    .sort(([a], [b]) => {
      const aIndex = groupOrder.indexOf(a);
      const bIndex = groupOrder.indexOf(b);
      return (aIndex === -1 ? 99 : aIndex) - (bIndex === -1 ? 99 : bIndex);
    })
    .map(([label, items]) => ({ label, items }));
}

export function getAdminDefaultRoute(input = null) {
  const role =
    typeof input === "string"
      ? normalizeRole(input)
      : normalizeRole(input?.user?.normalizedRole || input?.user?.role) ||
        (input ? null : getAdminRole());
  const firstAllowed = getAdminNavItems("", input)[0]?.to;

  if (role === "trainer" && canAccessAdminRoute("ClassesWorkspace", input)) {
    return "/classes";
  }

  return firstAllowed || "/settings";
}

export function setAdminSession(payload) {
  if (payload?.token) {
    localStorage.setItem(TOKEN_KEY, payload.token);
  }
  localStorage.setItem(SESSION_KEY, JSON.stringify(payload || {}));
  localStorage.setItem("gymmate_logged_in", "true");
}

export function clearAdminSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(SESSION_KEY);
  localStorage.removeItem("gymmate_logged_in");
}

export function isAdminAuthenticated() {
  return Boolean(getAdminToken());
}

export async function apiFetch(path, options = {}) {
  const headers = {
    ...(options.body ? { "Content-Type": "application/json" } : {}),
    ...(options.headers || {}),
  };

  if (!options.skipAuth) {
    const token = getAdminToken();
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
  }

  return fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  });
}
