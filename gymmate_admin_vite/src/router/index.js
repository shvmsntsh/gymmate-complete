import { createRouter, createWebHistory } from "vue-router";
import {
  canAccessAdminRoute,
  getAdminRole,
  getAdminSession,
  hasWorkspaceAccess,
  isAdminAuthenticated,
} from "../lib/api";

const routes = [
  {
    path: "/",
    name: "Home",
    component: () => import("../views/HomePage.vue"),
  },
  {
    path: "/login",
    name: "Login",
    component: () => import("../views/LoginPage.vue"),
  },
  {
    path: "/register-gym",
    name: "RegisterGym",
    component: () => import("../views/RegisterGym.vue"),
  },
  {
    path: "/forgot-password",
    name: "ForgotPassword",
    component: () => import("../views/ForgotPassword.vue"),
  },
  {
    path: "/receipt/:token",
    name: "PublicReceipt",
    component: () => import("../views/PublicReceipt.vue"),
  },
  {
    path: "/dashboard",
    name: "AdminDashboard",
    component: () => import("../views/WorkspaceDashboard.vue"),
    meta: { protected: true, routeAccess: "AdminDashboard" },
  },
  {
    path: "/crm",
    name: "CrmWorkspace",
    component: () => import("../views/WorkspaceModule.vue"),
    props: { moduleKey: "crm" },
    meta: { protected: true, routeAccess: "CrmWorkspace" },
  },
  {
    path: "/members",
    name: "MemberWorkspace",
    component: () => import("../views/WorkspaceModule.vue"),
    props: { moduleKey: "members" },
    meta: { protected: true, routeAccess: "MemberWorkspace" },
  },
  {
    path: "/payments",
    name: "PaymentWorkspace",
    component: () => import("../views/WorkspaceModule.vue"),
    props: { moduleKey: "payments" },
    meta: { protected: true, routeAccess: "PaymentWorkspace" },
  },
  {
    path: "/attendance",
    name: "AttendanceWorkspace",
    component: () => import("../views/WorkspaceModule.vue"),
    props: { moduleKey: "attendance" },
    meta: { protected: true, routeAccess: "AttendanceWorkspace" },
  },
  {
    path: "/classes",
    name: "ClassesWorkspace",
    component: () => import("../views/WorkspaceModule.vue"),
    props: { moduleKey: "classes" },
    meta: { protected: true, routeAccess: "ClassesWorkspace" },
  },
  {
    path: "/staff",
    name: "StaffWorkspace",
    component: () => import("../views/WorkspaceModule.vue"),
    props: { moduleKey: "staff" },
    meta: { protected: true, routeAccess: "StaffWorkspace" },
  },
  {
    path: "/manage-members",
    name: "ManageMembers",
    component: () => import("../views/ManageMembers.vue"),
    meta: { protected: true, routeAccess: "ManageMembers" },
  },
  {
    path: "/network",
    name: "NetworkControl",
    component: () => import("../views/NetworkControl.vue"),
    meta: { protected: true, routeAccess: "NetworkControl" },
  },
  {
    path: "/system-health",
    name: "SystemHealth",
    component: () => import("../views/SystemHealthView.vue"),
    meta: { protected: true, routeAccess: "SystemHealth" },
  },
  {
    path: "/settings",
    name: "Settings",
    component: () => import("../views/SettingsView.vue"),
    meta: { protected: true, routeAccess: "Settings" },
  },
  {
    path: "/announcements",
    name: "Announcements",
    component: () => import("../views/AnnouncementsView.vue"),
    meta: { protected: true, routeAccess: "Announcements" },
  },
  {
    path: "/membership",
    name: "MembershipOps",
    component: () => import("../views/MembershipView.vue"),
    meta: { protected: true, routeAccess: "MembershipOps" },
  },
  {
    path: "/membership-new",
    name: "Membership",
    component: () => import("../views/MembershipView.vue"),
    meta: { protected: true, routeAccess: "Membership" },
  },
  {
    path: "/biometric",
    name: "BiometricOps",
    component: () => import("../views/BiometricOpsView.vue"),
    meta: { protected: true, routeAccess: "BiometricOps" },
  },
  {
    path: "/invites",
    name: "Invites",
    component: () => import("../views/InvitesView.vue"),
    meta: { protected: true, routeAccess: "Invites" },
  },
  {
    path: "/branding",
    name: "BrandingStudio",
    component: () => import("../views/BrandingStudio.vue"),
    meta: { protected: true, routeAccess: "BrandingStudio" },
  },
  {
    path: "/gyms/:id",
    name: "GymDetails",
    component: () => import("../views/GymDetails.vue"),
    meta: { protected: true, routeAccess: "GymDetails" },
  },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

router.beforeEach((to, _from, next) => {
  const authenticated = isAdminAuthenticated();
  const role = getAdminRole();
  const session = getAdminSession();

  if (
    (to.name === "Home" || to.name === "Login") &&
    authenticated &&
    hasWorkspaceAccess()
  ) {
    next({ name: "AdminDashboard" });
    return;
  }

  if (to.meta?.protected && !hasWorkspaceAccess()) {
    next({ name: "Login" });
    return;
  }

  if (to.meta?.routeAccess && !canAccessAdminRoute(to.meta.routeAccess, session?.user ? session : role)) {
    next({ name: "AdminDashboard" });
    return;
  }

  next();
});

export default router;
