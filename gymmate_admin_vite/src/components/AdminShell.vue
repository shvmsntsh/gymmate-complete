<template>
  <v-app :theme="isDark ? 'dark' : 'light'">
    <div class="admin-shell">
      <aside class="admin-shell__sidebar admin-surface">
        <AdminBrand compact />
        <div class="admin-shell__eyebrow">{{ workspaceLabel }}</div>

        <nav class="admin-shell__nav">
          <button
            v-for="item in navItems"
            :key="item.to"
            type="button"
            class="admin-shell__nav-item"
            :class="{ 'admin-shell__nav-item--active': item.active }"
            @click="router.push(item.to)"
          >
            <span class="admin-shell__nav-icon"
              ><v-icon :icon="item.icon"
            /></span>
            <span>{{ item.label }}</span>
          </button>
        </nav>

        <div
          class="admin-shell__sidebar-footer admin-surface admin-surface--muted"
        >
          <div class="sidebar-callout__title">{{ sidebarTitle }}</div>
          <div class="sidebar-callout__copy">{{ sidebarCopy }}</div>
        </div>
      </aside>

      <main class="admin-shell__main">
        <header class="admin-shell__header admin-surface">
          <div>
            <div class="eyebrow">{{ eyebrow }}</div>
            <h1 class="page-title">{{ title }}</h1>
            <p v-if="description" class="page-description">{{ description }}</p>
          </div>

          <div class="admin-shell__actions">
            <slot name="header-actions"></slot>
            <AdminThemeToggle
              :is-dark="isDark"
              @toggle="$emit('toggle-theme')"
            />
            <v-btn
              class="admin-logout-btn"
              variant="tonal"
              @click="$emit('logout')"
            >
              <v-icon start icon="mdi-logout" />
              Logout
            </v-btn>
          </div>
        </header>

        <section class="admin-shell__content">
          <slot></slot>
        </section>
      </main>
    </div>
  </v-app>
</template>

<script setup>
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import AdminBrand from "./AdminBrand.vue";
import AdminThemeToggle from "./AdminThemeToggle.vue";
import { getAdminRole } from "../lib/api";

defineProps({
  description: {
    type: String,
    default: "",
  },
  eyebrow: {
    type: String,
    default: "GymMate Admin",
  },
  isDark: {
    type: Boolean,
    default: false,
  },
  title: {
    type: String,
    required: true,
  },
});

defineEmits(["toggle-theme", "logout"]);

const route = useRoute();
const router = useRouter();
const sessionRole = computed(() => getAdminRole());

const workspaceLabel = computed(() =>
  sessionRole.value === "owner"
    ? "Owner Workspace"
    : sessionRole.value === "staff"
      ? "Staff Workspace"
      : "Management Suite",
);

const sidebarTitle = computed(() =>
  sessionRole.value === "owner" ? "Gym Studio" : "Your Fitness HQ",
);

const sidebarCopy = computed(() =>
  sessionRole.value === "owner"
    ? "Keep your brand, invites, members, and daily gym rhythm in one focused workspace."
    : "Keep your gyms, members, invites, and day-to-day operations in one calm control room.",
);

const navItems = computed(() => {
  const currentPath = route.path;

  if (sessionRole.value === "owner") {
    return [
      {
        active: currentPath === "/dashboard",
        icon: "mdi-view-dashboard-outline",
        label: "Dashboard",
        to: "/dashboard",
      },
      {
        active: currentPath === "/manage-members",
        icon: "mdi-account-group-outline",
        label: "Members",
        to: "/manage-members",
      },
      {
        active: currentPath === "/announcements",
        icon: "mdi-bullhorn-outline",
        label: "Announcements",
        to: "/announcements",
      },
      {
        active: currentPath === "/membership",
        icon: "mdi-card-account-details-outline",
        label: "Membership",
        to: "/membership",
      },
      {
        active: currentPath === "/biometric",
        icon: "mdi-fingerprint",
        label: "Biometric",
        to: "/biometric",
      },
      {
        active: currentPath === "/invites",
        icon: "mdi-ticket-confirmation-outline",
        label: "Invites",
        to: "/invites",
      },
      {
        active: currentPath === "/branding",
        icon: "mdi-palette-outline",
        label: "Branding",
        to: "/branding",
      },
    ];
  }

  return [
    {
      active: currentPath === "/dashboard",
      icon: "mdi-view-dashboard-outline",
      label: "Dashboard",
      to: "/dashboard",
    },
    {
      active: currentPath === "/manage-members",
      icon: "mdi-account-group-outline",
      label: "Members",
      to: "/manage-members",
    },
    {
      active: currentPath === "/announcements",
      icon: "mdi-bullhorn-outline",
      label: "Announcements",
      to: "/announcements",
    },
    {
      active: currentPath === "/membership",
      icon: "mdi-card-account-details-outline",
      label: "Membership",
      to: "/membership",
    },
    {
      active: currentPath === "/register-gym",
      icon: "mdi-domain-plus",
      label: "Register Gym",
      to: "/register-gym",
    },
  ];
});
</script>
