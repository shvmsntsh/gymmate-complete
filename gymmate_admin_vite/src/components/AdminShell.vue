<template>
  <v-app :theme="isDark ? 'dark' : 'light'">
    <div
      class="admin-shell"
      :class="{
        'admin-shell--collapsed': sidebarCollapsed,
        'admin-shell--drawer-open': drawerOpen,
      }"
    >
      <button
        v-if="drawerOpen"
        class="admin-shell__scrim"
        type="button"
        aria-label="Close navigation"
        @click="drawerOpen = false"
      />
      <aside class="admin-shell__sidebar admin-surface">
        <AdminBrand
          compact
          :brand-name="sidebarDisplayName"
          :logo-url="sidebarLogoUrl"
        />
        <div class="admin-shell__eyebrow">{{ workspaceLabel }}</div>
        <button
          type="button"
          class="admin-shell__collapse"
          @click="sidebarCollapsed = !sidebarCollapsed"
        >
          <v-icon :icon="sidebarCollapsed ? 'mdi-chevron-right' : 'mdi-chevron-left'" />
        </button>

        <nav class="admin-shell__nav">
          <button
            v-for="item in navItems"
            :key="item.to"
            type="button"
            class="admin-shell__nav-item"
            :class="{ 'admin-shell__nav-item--active': item.active }"
            @click="goTo(item.to)"
          >
            <span class="admin-shell__nav-icon"
              ><v-icon :icon="item.icon"
            /></span>
            <span class="admin-shell__nav-label">{{ item.label }}</span>
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
          <v-btn
            class="admin-shell__menu"
            icon="mdi-menu"
            variant="tonal"
            aria-label="Open navigation"
            @click="drawerOpen = true"
          />
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
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import AdminBrand from "./AdminBrand.vue";
import AdminThemeToggle from "./AdminThemeToggle.vue";
import { apiFetch, getAdminNavItems, getAdminRole, getAdminSession } from "../lib/api";

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
const session = computed(() => getAdminSession());
const sidebarBrandName = ref("");
const sidebarLogoUrl = ref("");
const sidebarCollapsed = ref(false);
const drawerOpen = ref(false);
const sidebarDisplayName = computed(() =>
  sidebarLogoUrl.value ? sidebarBrandName.value : "",
);

const workspaceLabel = computed(() =>
  sessionRole.value === "admin"
    ? "Admin Workspace"
    : sessionRole.value === "owner"
    ? "Owner Workspace"
    : sessionRole.value === "staff"
      ? "Staff Workspace"
      : "Management Suite",
);

const sidebarTitle = computed(() =>
  sessionRole.value === "admin"
    ? "Network Control"
    : sessionRole.value === "owner"
      ? "Gym Studio"
      : "Your Fitness HQ",
);

const sidebarCopy = computed(() =>
  sessionRole.value === "admin"
    ? "Manage gyms, owner access, invites, and shared operations from one clear control room."
    : sessionRole.value === "owner"
    ? "Keep your brand, invites, members, and daily gym rhythm in one focused workspace."
    : "Keep your gyms, members, invites, and day-to-day operations in one calm control room.",
);

const navItems = computed(() => {
  return getAdminNavItems(route.path, sessionRole.value);
});

function goTo(path) {
  drawerOpen.value = false;
  router.push(path);
}

async function loadGymBranding() {
  const role = sessionRole.value;
  const gymId = session.value?.user?.gymId;

  if (!gymId || (role !== "owner" && role !== "staff")) {
    sidebarBrandName.value = "";
    sidebarLogoUrl.value = "";
    return;
  }

  try {
    const res = await apiFetch("/api/gym/self");
    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "Failed to load gym branding");
    }

    const gym = data.gym || data.member || {};
    sidebarBrandName.value = gym.gymName || gym.name || "";
    sidebarLogoUrl.value = gym.branding?.logoUrl || "";
  } catch {
    sidebarBrandName.value = "";
    sidebarLogoUrl.value = "";
  }
}

onMounted(() => {
  loadGymBranding();
});
</script>
