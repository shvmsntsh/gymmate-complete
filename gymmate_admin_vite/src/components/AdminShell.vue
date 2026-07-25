<template>
  <v-app :theme="isDark ? 'dark' : 'light'">
    <div
      class="admin-shell"
      :class="{
        'admin-shell--collapsed': sidebarCollapsed,
        'admin-shell--drawer-open': drawerOpen,
      }"
    >
        <div
          v-if="drawerOpen"
          class="admin-shell__scrim"
          @click="drawerOpen = false"
        />
      <aside class="admin-shell__sidebar admin-surface">
        <AdminBrand
          compact
          :brand-name="sidebarDisplayName"
          :logo-url="sidebarLogoUrl"
          :mark-image-url="sidebarMarkUrl"
          :wordmark-url="sidebarWordmarkUrl"
          :hide-glyph="!sidebarCollapsed && Boolean(sidebarWordmarkUrl)"
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
          <div
            v-for="group in navGroups"
            :key="group.label"
            class="admin-shell__nav-group"
          >
            <div class="admin-shell__nav-group-label">{{ group.label }}</div>
            <button
              v-for="item in group.items"
              :key="item.to"
              type="button"
              class="admin-shell__nav-item"
              :class="{ 'admin-shell__nav-item--active': item.active }"
              @click="goTo(item.to)"
            >
              <span class="admin-shell__nav-icon"
                ><v-icon :icon="item.icon"
              /></span>
              <span class="admin-shell__nav-label" :title="item.label">{{ item.label }}</span>
            </button>
          </div>
        </nav>

        <SidebarOnboardingChip />

        <div
          class="admin-shell__sidebar-footer admin-surface admin-surface--muted"
        >
          <div class="admin-shell__profile">
            <div class="admin-shell__avatar">{{ userInitials }}</div>
            <div class="admin-shell__profile-copy">
              <div class="sidebar-callout__title">{{ userName }}</div>
              <div class="sidebar-callout__copy">{{ userRoleLabel }}</div>
            </div>
            <button
              type="button"
              class="admin-shell__logout-icon"
              aria-label="Logout"
              @click="$emit('logout')"
            >
              <v-icon icon="mdi-logout" />
            </button>
          </div>
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
            <QuickAddMenu v-if="sessionRole === 'owner' || sessionRole === 'staff'" />
            <slot name="header-actions"></slot>
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
import { computed, onMounted, onUnmounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import AdminBrand from "./AdminBrand.vue";
import QuickAddMenu from "./QuickAddMenu.vue";
import SidebarOnboardingChip from "./SidebarOnboardingChip.vue";
import { apiFetch, getAdminRole, getAdminSession, getGroupedAdminNavItems } from "../lib/api";

const props = defineProps({
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
const BRANDING_UPDATED_EVENT = "gymmate-branding-updated";
const sidebarDisplayName = computed(() =>
  sidebarLogoUrl.value ? sidebarBrandName.value : "GymMate",
);
const assetBase = import.meta.env.BASE_URL;
const sidebarMarkUrl = computed(() =>
  sidebarLogoUrl.value
    ? ""
    : `${assetBase}images/${props.isDark ? "gymmate_logo_mark_light.png" : "gymmate_logo_mark_dark.png"}`,
);
const sidebarWordmarkUrl = computed(() =>
  sidebarLogoUrl.value
    ? ""
    : `${assetBase}images/${props.isDark ? "gymmate_logo_light.png" : "gymmate_logo_dark.png"}`,
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

const userName = computed(() => session.value?.user?.name || sidebarBrandName.value || "GymMate User");
const userRoleLabel = computed(() =>
  sessionRole.value === "admin"
    ? "Platform Admin"
    : sessionRole.value === "owner"
      ? "Gym Owner"
      : sessionRole.value === "staff"
        ? "Staff"
      : sessionRole.value === "trainer"
        ? "Trainer"
        : "Workspace User",
);
const userInitials = computed(() =>
  userName.value
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("") || "GM",
);

const navGroups = computed(() => {
  return getGroupedAdminNavItems(route.path, session.value);
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
  window.addEventListener(BRANDING_UPDATED_EVENT, loadGymBranding);
});

onUnmounted(() => {
  window.removeEventListener(BRANDING_UPDATED_EVENT, loadGymBranding);
});
</script>
