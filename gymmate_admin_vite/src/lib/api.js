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
  "members.manage",
  "announcements.manage",
  "membership.requests.manage",
  "payments.manage",
];

const OWNER_PERMISSIONS = [...STAFF_PERMISSIONS, "membership.plans.manage"];
const ADMIN_PERMISSIONS = [...OWNER_PERMISSIONS, "gyms.manage"];

const ROLE_PERMISSIONS = {
  admin: ADMIN_PERMISSIONS,
  owner: OWNER_PERMISSIONS,
  staff: STAFF_PERMISSIONS,
};

const ADMIN_ROUTE_RULES = {
  AdminDashboard: {
    nav: { icon: "mdi-view-dashboard-outline", label: "Dashboard", to: "/dashboard" },
    roles: ["admin", "owner", "staff"],
  },
  ManageMembers: {
    nav: { icon: "mdi-account-group-outline", label: "Members", to: "/manage-members" },
    roles: ["admin", "owner", "staff"],
  },
  Announcements: {
    nav: { icon: "mdi-bullhorn-outline", label: "Announcements", to: "/announcements" },
    roles: ["admin", "owner", "staff"],
  },
  MembershipOps: {
    nav: { icon: "mdi-card-account-details-outline", label: "Membership", to: "/membership" },
    roles: ["admin", "owner", "staff"],
  },
  Membership: {
    nav: { icon: "mdi-card-account-details-outline", label: "Membership", to: "/membership" },
    roles: ["admin", "owner", "staff"],
  },
  Invites: {
    nav: { icon: "mdi-ticket-confirmation-outline", label: "Invites", to: "/invites" },
    roles: ["admin", "owner"],
  },
  BrandingStudio: {
    nav: { icon: "mdi-palette-outline", label: "Branding", to: "/branding" },
    roles: ["owner"],
  },
  BiometricOps: {
    nav: { icon: "mdi-fingerprint", label: "Biometric", to: "/biometric" },
    roles: ["owner"],
  },
  RegisterGym: {
    nav: { icon: "mdi-domain-plus", label: "Register Gym", to: "/register-gym" },
    roles: ["admin"],
  },
  GymDetails: {
    roles: ["admin"],
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
  const role =
    typeof input === "string"
      ? normalizeRole(input)
      : normalizeRole(input?.user?.normalizedRole || input?.user?.role) ||
        (input ? null : getAdminRole());

  return ROLE_PERMISSIONS[role] || [];
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

  const role =
    typeof input === "string"
      ? normalizeRole(input)
      : normalizeRole(input?.user?.normalizedRole || input?.user?.role) ||
        (input ? null : getAdminRole());

  return rule.roles.includes(role);
}

export function getAdminNavItems(currentPath, input = null) {
  const seenTargets = new Set();

  return Object.entries(ADMIN_ROUTE_RULES)
    .filter(([routeName, rule]) => rule.nav && canAccessAdminRoute(routeName, input))
    .filter(([, rule]) => {
      if (seenTargets.has(rule.nav.to)) return false;
      seenTargets.add(rule.nav.to);
      return true;
    })
    .map(([, rule]) => ({
      ...rule.nav,
      active:
        currentPath === rule.nav.to ||
        (rule.nav.to === "/membership" && currentPath === "/membership-new"),
    }));
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
