import { createRouter, createWebHistory } from "vue-router";
import {
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
    meta: { protected: true },
  },
  {
    path: "/manage-members",
    name: "ManageMembers",
    component: () => import("../views/ManageMembers.vue"),
    meta: { protected: true },
  },
  {
    path: "/invites",
    name: "Invites",
    component: () => import("../views/InvitesView.vue"),
    meta: { protected: true },
  },
  {
    path: "/branding",
    name: "BrandingStudio",
    component: () => import("../views/BrandingStudio.vue"),
    meta: { protected: true, ownerOnly: true },
  },
  {
    path: "/gyms/:id",
    name: "GymDetails",
    component: () => import("../views/GymDetails.vue"),
    meta: { protected: true, adminOnly: true },
  },
];

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

router.beforeEach((to, _from, next) => {
  const authenticated = isAdminAuthenticated();
  const role = getAdminRole();

  if (to.name === "Login" && authenticated && hasWorkspaceAccess()) {
    next({ name: "AdminDashboard" });
    return;
  }

  if (to.meta?.protected && !hasWorkspaceAccess()) {
    next({ name: "Login" });
    return;
  }

  if (to.meta?.adminOnly && role !== "admin") {
    next({ name: "AdminDashboard" });
    return;
  }

  if (to.meta?.ownerOnly && role !== "owner") {
    next({ name: "AdminDashboard" });
    return;
  }

  if (to.name === "RegisterGym" && authenticated && role !== "admin") {
    next({ name: "AdminDashboard" });
    return;
  }

  next();
});

export default router;
