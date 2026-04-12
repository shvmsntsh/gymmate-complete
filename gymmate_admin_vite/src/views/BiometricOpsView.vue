<template>
  <AdminShell
    :is-dark="isDark"
    title="Biometric Pilot"
    eyebrow="Optional Attendance Sync"
    description="Enable biometrics only for gyms that need it, with a provider dropdown ready for future vendors."
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <section class="admin-surface admin-panel">
      <StateBlock
        v-if="error"
        title="Could not load biometric settings"
        :copy="error"
        icon="mdi-alert-circle-outline"
        tone="error"
      />

      <div class="section-header">
        <div>
          <div class="table-overline">Provider Setup</div>
          <h2 class="section-title">Pilot one biometric vendor per gym</h2>
          <p class="section-copy">
            This module is optional. It stays disabled for gyms that do not connect a device.
          </p>
        </div>
      </div>

      <div class="biometric-grid">
        <v-select
          v-model="form.providerKey"
          :items="providerOptions"
          item-title="title"
          item-value="value"
          label="Biometric provider"
          variant="outlined"
        />
        <v-switch
          v-model="form.enabled"
          color="primary"
          label="Enable for this gym"
          inset
        />
        <v-text-field
          v-model="form.config.baseUrl"
          label="API base URL"
          variant="outlined"
          placeholder="https://biometric-vendor.example.com"
        />
        <v-text-field
          v-model="form.config.deviceCode"
          label="Device code"
          variant="outlined"
          placeholder="IDENTIX-01"
        />
      </div>

      <v-textarea
        v-model="form.config.apiKey"
        label="API key / token"
        variant="outlined"
        rows="2"
        auto-grow
        placeholder="Store the pilot credential here for now."
      />

      <div class="cta-row">
        <v-btn color="primary" :loading="saving" @click="saveSettings">
          Save settings
        </v-btn>
        <v-btn
          variant="tonal"
          :loading="syncing"
          :disabled="!form.enabled"
          @click="runSync"
        >
          Run pilot sync
        </v-btn>
      </div>

      <div class="section-header section-header--spaced">
        <div>
          <div class="table-overline">Current State</div>
          <h2 class="section-title">Last sync status</h2>
        </div>
      </div>

      <div class="status-grid">
        <div class="summary-pill">
          <div class="summary-label">Provider</div>
          <div class="summary-value">{{ activeProviderLabel }}</div>
        </div>
        <div class="summary-pill">
          <div class="summary-label">Enabled</div>
          <div class="summary-value">{{ form.enabled ? "Yes" : "No" }}</div>
        </div>
        <div class="summary-pill">
          <div class="summary-label">Last Status</div>
          <div class="summary-value">{{ statusLabel }}</div>
        </div>
      </div>

      <p v-if="integration.lastSyncAt" class="section-copy status-copy">
        Last synced at {{ formatDate(integration.lastSyncAt) }}
      </p>
      <p v-if="integration.lastSyncError" class="section-copy status-copy">
        Last error: {{ integration.lastSyncError }}
      </p>
    </section>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch, clearAdminSession } from "../lib/api";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();

const error = ref("");
const saving = ref(false);
const syncing = ref(false);
const providers = ref([]);
const integration = ref({
  providerKey: "identix",
  enabled: false,
  config: {},
  lastSyncAt: null,
  lastSyncStatus: "never",
  lastSyncError: "",
});
const form = ref({
  providerKey: "identix",
  enabled: false,
  config: {
    baseUrl: "",
    deviceCode: "",
    apiKey: "",
  },
});

const providerOptions = computed(() =>
  providers.value.map((provider) => ({
    title: provider.label,
    value: provider.key,
  })),
);

const activeProviderLabel = computed(() => {
  const match = providers.value.find((provider) => provider.key === form.value.providerKey);
  return match?.label || "Identix";
});

const statusLabel = computed(() =>
  String(integration.value.lastSyncStatus || "never").replaceAll("_", " "),
);

function logout() {
  clearAdminSession();
  router.push("/login");
}

function hydrateForm(nextIntegration) {
  integration.value = nextIntegration;
  form.value = {
    providerKey: nextIntegration.providerKey || "identix",
    enabled: Boolean(nextIntegration.enabled),
    config: {
      baseUrl: nextIntegration.config?.baseUrl || "",
      deviceCode: nextIntegration.config?.deviceCode || "",
      apiKey: nextIntegration.config?.apiKey || "",
    },
  };
}

function formatDate(value) {
  if (!value) return "Never";
  return new Date(value).toLocaleString("en-GB");
}

async function fetchSettings() {
  error.value = "";
  try {
    const res = await apiFetch("/api/owner/biometric/settings");
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "Could not load biometric settings.");
    }
    providers.value = data.providers || [];
    hydrateForm(data.integration || integration.value);
  } catch (err) {
    error.value = err?.message || "Could not load biometric settings.";
  }
}

async function saveSettings() {
  saving.value = true;
  error.value = "";
  try {
    const res = await apiFetch("/api/owner/biometric/settings", {
      method: "PUT",
      body: JSON.stringify(form.value),
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "Could not save biometric settings.");
    }
    hydrateForm(data.integration || integration.value);
  } catch (err) {
    error.value = err?.message || "Could not save biometric settings.";
  } finally {
    saving.value = false;
  }
}

async function runSync() {
  syncing.value = true;
  error.value = "";
  try {
    const res = await apiFetch("/api/owner/biometric/sync", {
      method: "POST",
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "Could not run pilot sync.");
    }
    hydrateForm(data.integration || integration.value);
  } catch (err) {
    error.value = err?.message || "Could not run pilot sync.";
  } finally {
    syncing.value = false;
  }
}

onMounted(fetchSettings);
</script>

<style scoped>
.biometric-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 12px;
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.status-copy {
  margin-top: 12px;
}

.section-header--spaced {
  margin-top: 28px;
}

@media (max-width: 820px) {
  .biometric-grid,
  .status-grid {
    grid-template-columns: 1fr;
  }
}
</style>
