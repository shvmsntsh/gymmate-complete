<template>
  <AdminShell
    :is-dark="isDark"
    title="Settings"
    eyebrow="Workspace preferences"
    description="Control local admin appearance without changing gym data."
    @logout="logout"
  >
    <section class="workspace-panel settings-panel">
      <div class="workspace-section-head">
        <div>
          <div class="table-overline">Appearance</div>
          <h2 class="section-title">Choose light, dark, or system</h2>
          <p class="section-copy">
            This setting is saved only for this browser and follows the mobile-matched GymMate palette.
          </p>
        </div>
      </div>

      <div class="settings-options">
        <button
          v-for="option in options"
          :key="option.value"
          type="button"
          class="settings-option"
          :class="{ 'settings-option--active': selectedMode === option.value }"
          @click="chooseTheme(option.value)"
        >
          <v-icon :icon="option.icon" />
          <span>
            <strong>{{ option.label }}</strong>
            <small>{{ option.copy }}</small>
          </span>
        </button>
      </div>

      <div class="settings-preview">
        <div>
          <div class="table-overline">Live preview</div>
          <h3>GymMate Admin</h3>
          <p>Cards, text, buttons, and borders update instantly.</p>
        </div>
        <v-btn color="primary" variant="flat">Primary action</v-btn>
      </div>
    </section>
  </AdminShell>
</template>

<script setup>
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import { clearAdminSession } from "../lib/api";
import { useAdminTheme } from "../composables/useAdminTheme";

const THEME_KEY = "gymmate_theme";
const router = useRouter();
const { isDark, setSystemTheme, setTheme } = useAdminTheme();
const selectedMode = ref("system");

const options = [
  {
    label: "System",
    value: "system",
    icon: "mdi-theme-light-dark",
    copy: "Follow this device automatically.",
  },
  {
    label: "Light",
    value: "light",
    icon: "mdi-white-balance-sunny",
    copy: "Warm cream workspace for daytime use.",
  },
  {
    label: "Dark",
    value: "dark",
    icon: "mdi-moon-waning-crescent",
    copy: "Dark GymMate surfaces matching the mobile app.",
  },
];

function chooseTheme(mode) {
  selectedMode.value = mode;
  if (mode === "system") {
    setSystemTheme();
  } else {
    setTheme(mode);
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(() => {
  const saved = localStorage.getItem(THEME_KEY);
  selectedMode.value = saved === "light" || saved === "dark" ? saved : "system";
});
</script>
