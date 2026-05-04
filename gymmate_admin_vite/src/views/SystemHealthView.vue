<template>
  <AdminShell
    :is-dark="isDark"
    title="System Health"
    eyebrow="Platform monitoring"
    description="Quick checks for API availability, database connection, and browser deployment context."
    @logout="logout"
  >
    <StateBlock
      v-if="error"
      title="Could not check system health"
      :copy="error"
      icon="mdi-alert-circle-outline"
      tone="error"
    />

    <div class="workspace-kpis">
      <StatCard
        v-for="metric in metrics"
        :key="metric.label"
        :label="metric.label"
        :value="metric.value"
        :icon="metric.icon"
        :hint="metric.hint"
      />
    </div>

    <section class="workspace-panel">
      <div class="workspace-section-head">
        <div>
          <div class="table-overline">Health check</div>
          <h2 class="section-title">API and database status</h2>
          <p class="section-copy">Uses the existing health endpoint. No destructive checks are run.</p>
        </div>
        <v-btn color="primary" variant="tonal" :loading="loading" @click="checkHealth">
          <v-icon start icon="mdi-refresh" />
          Refresh
        </v-btn>
      </div>

      <div class="health-grid">
        <div class="health-card">
          <v-icon icon="mdi-api" />
          <div>
            <strong>Backend API</strong>
            <span>{{ apiBase || "Same origin" }}</span>
          </div>
          <v-chip :color="healthy ? 'success' : 'error'" variant="tonal">
            {{ healthy ? "Online" : "Needs attention" }}
          </v-chip>
        </div>
        <div class="health-card">
          <v-icon icon="mdi-database-check-outline" />
          <div>
            <strong>Database</strong>
            <span>{{ healthPayload?.ok ? "Connected through health check" : "Not confirmed" }}</span>
          </div>
          <v-chip :color="healthPayload?.ok ? 'success' : 'warning'" variant="tonal">
            {{ healthPayload?.ok ? "Ready" : "Unknown" }}
          </v-chip>
        </div>
      </div>
    </section>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import StatCard from "../components/StatCard.vue";
import { API_BASE_URL, clearAdminSession } from "../lib/api";
import { useAdminTheme } from "../composables/useAdminTheme";

const router = useRouter();
const { isDark } = useAdminTheme();
const loading = ref(false);
const error = ref("");
const healthPayload = ref(null);
const checkedAt = ref("");
const apiBase = API_BASE_URL;

const healthy = computed(() => Boolean(healthPayload.value?.ok));
const metrics = computed(() => [
  {
    label: "API",
    value: healthy.value ? "Online" : "Check",
    icon: "mdi-api",
    hint: apiBase || "Same origin deployment",
  },
  {
    label: "Database",
    value: healthy.value ? "Ready" : "Unknown",
    icon: "mdi-database",
    hint: "Reported by /api/health",
  },
  {
    label: "Last Check",
    value: checkedAt.value || "Pending",
    icon: "mdi-clock-outline",
    hint: "Local browser time",
  },
]);

async function checkHealth() {
  loading.value = true;
  error.value = "";
  try {
    const res = await fetch(`${apiBase}/api/health`);
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || "Health check failed.");
    healthPayload.value = data;
    checkedAt.value = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  } catch (err) {
    healthPayload.value = null;
    error.value = err?.message || "Health check failed.";
  } finally {
    loading.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(checkHealth);
</script>
