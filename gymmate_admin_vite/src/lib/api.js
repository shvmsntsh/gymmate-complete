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

const normalizeRole = (role) => {
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

export const API_BASE_URL = normalizeBase(
  import.meta.env.VITE_API_BASE_URL || inferDefaultBase(),
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

export function isAdminSession() {
  return getAdminRole() === "admin";
}

export function isOwnerSession() {
  return getAdminRole() === "owner";
}

export function hasWorkspaceAccess() {
  const role = getAdminRole();
  return role === "admin" || role === "owner" || role === "staff";
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
