import { createRouter, createWebHistory } from "vue-router";
import {
  canAccessAdminRoute,
  getAdminRole,
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
    path: "/dashboard",
    name: "AdminDashboard",
    component: () => import("../views/AdminDashboard.vue"),
    meta: { protected: true, routeAccess: "AdminDashboard" },
  },
  {
    path: "/manage-members",
    name: "ManageMembers",
    component: () => import("../views/ManageMembers.vue"),
    meta: { protected: true, routeAccess: "ManageMembers" },
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

  if (to.meta?.routeAccess && !canAccessAdminRoute(to.meta.routeAccess, role)) {
    next({ name: "AdminDashboard" });
    return;
  }

  next();
});

export default router;
