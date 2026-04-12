<template>
  <AdminShell
    :is-dark="isDark"
    title="Network Control"
    eyebrow="Superadmin"
    description="Manage gyms, people, plan caps, invite locks, and service analytics."
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <div class="overview-metrics">
      <StatCard
        v-for="metric in metrics"
        :key="metric.label"
        :label="metric.label"
        :value="metric.value"
        :icon="metric.icon"
        :hint="metric.hint"
      />
    </div>

    <section class="admin-surface admin-panel network-panel">
      <div class="section-header">
        <div>
          <div class="table-overline">Ops Control Center</div>
          <h2 class="section-title">Gyms, users, tiers, invites, and services</h2>
          <p class="section-copy">
            Keep launch operations manual where they need judgment and automatic where they need guardrails.
          </p>
        </div>
        <v-btn color="primary" variant="tonal" :loading="loading" @click="loadAll">
          Refresh
        </v-btn>
      </div>

      <StateBlock
        v-if="error"
        title="Could not load network control"
        :copy="error"
        icon="mdi-alert-circle-outline"
        tone="error"
      />

      <template v-else>
        <v-tabs v-model="tab" class="network-tabs">
          <v-tab value="gyms">Gyms</v-tab>
          <v-tab value="people">People</v-tab>
          <v-tab value="usage">Plan Usage</v-tab>
          <v-tab value="invites">Invites</v-tab>
          <v-tab value="services">Services</v-tab>
        </v-tabs>

        <v-window v-model="tab" class="network-window">
          <v-window-item value="gyms">
            <v-data-table
              class="admin-table"
              :headers="gymHeaders"
              :items="gyms"
              :loading="loading"
              density="comfortable"
              item-value="id"
            >
              <template #item.plan="{ item }">
                <div class="network-inline-control">
                  <v-select
                    :items="planTiers"
                    item-title="name"
                    item-value="key"
                    :model-value="(item.raw || item).platformPlan"
                    density="compact"
                    hide-details
                    variant="outlined"
                    @update:model-value="(value) => updateGymPlan(item.raw || item, value)"
                  />
                  <v-text-field
                    v-if="(item.raw || item).platformPlan === 'custom'"
                    :model-value="(item.raw || item).memberCap"
                    density="compact"
                    hide-details
                    inputmode="numeric"
                    variant="outlined"
                    @change="(event) => updateGymCap(item.raw || item, event.target.value)"
                  />
                </div>
              </template>

              <template #item.usage="{ item }">
                <v-chip :color="usageTone(item.raw || item)" variant="tonal" size="small">
                  {{ usageLabel(item.raw || item) }}
                </v-chip>
              </template>

              <template #item.status="{ item }">
                <v-chip
                  :color="(item.raw || item).status === 'active' ? 'primary' : 'error'"
                  size="small"
                  variant="tonal"
                >
                  {{ (item.raw || item).status }}
                </v-chip>
              </template>

              <template #item.actions="{ item }">
                <v-btn
                  size="small"
                  variant="tonal"
                  :color="(item.raw || item).status === 'active' ? 'error' : 'primary'"
                  :loading="busyKey === `gym-${(item.raw || item).id}`"
                  @click="toggleGymStatus(item.raw || item)"
                >
                  {{ (item.raw || item).status === "active" ? "Deactivate" : "Activate" }}
                </v-btn>
              </template>
            </v-data-table>
          </v-window-item>

          <v-window-item value="people">
            <v-data-table
              class="admin-table"
              :headers="userHeaders"
              :items="users"
              :loading="loading"
              density="comfortable"
              item-value="id"
            >
              <template #item.accountStatus="{ item }">
                <v-chip
                  :color="(item.raw || item).accountStatus === 'active' ? 'primary' : 'error'"
                  size="small"
                  variant="tonal"
                >
                  {{ (item.raw || item).accountStatus }}
                </v-chip>
              </template>
              <template #item.roleControl="{ item }">
                <v-select
                  :items="roleOptions"
                  item-title="label"
                  item-value="value"
                  :model-value="(item.raw || item).role"
                  density="compact"
                  hide-details
                  variant="outlined"
                  @update:model-value="(value) => updateUserRole(item.raw || item, value)"
                />
              </template>
              <template #item.actions="{ item }">
                <v-btn
                  size="small"
                  variant="tonal"
                  :color="(item.raw || item).accountStatus === 'active' ? 'error' : 'primary'"
                  :loading="busyKey === `user-${(item.raw || item).id}`"
                  @click="toggleUserStatus(item.raw || item)"
                >
                  {{ (item.raw || item).accountStatus === "active" ? "Deactivate" : "Activate" }}
                </v-btn>
              </template>
            </v-data-table>
          </v-window-item>

          <v-window-item value="usage">
            <div class="usage-grid">
              <div
                v-for="gym in gyms"
                :key="gym.id"
                class="usage-card admin-surface admin-surface--muted"
              >
                <div>
                  <div class="usage-card__title">{{ gym.gymName }}</div>
                  <div class="usage-card__copy">
                    {{ gym.platformPlanName }} · {{ usageLabel(gym) }}
                  </div>
                </div>
                <v-progress-linear
                  :model-value="usagePercent(gym)"
                  :color="usageTone(gym)"
                  height="10"
                  rounded
                />
              </div>
            </div>
          </v-window-item>

          <v-window-item value="invites">
            <v-data-table
              class="admin-table"
              :headers="inviteHeaders"
              :items="invites"
              :loading="loading"
              density="comfortable"
              item-value="id"
            >
              <template #item.used="{ item }">
                <v-chip
                  :color="(item.raw || item).used ? 'primary' : 'warning'"
                  size="small"
                  variant="tonal"
                >
                  {{ (item.raw || item).used ? "Claimed" : "Open" }}
                </v-chip>
              </template>
            </v-data-table>
          </v-window-item>

          <v-window-item value="services">
            <div class="service-list">
              <div
                v-for="service in services"
                :key="service.slug"
                class="service-row"
              >
                <span>{{ service.name }}</span>
                <v-chip color="primary" size="small" variant="tonal">
                  {{ service.gymCount }} gyms
                </v-chip>
              </div>
            </div>
          </v-window-item>
        </v-window>
      </template>
    </section>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">
      {{ snackbarText }}
    </v-snackbar>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StatCard from "../components/StatCard.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch, clearAdminSession } from "../lib/api";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const tab = ref("gyms");
const loading = ref(false);
const error = ref("");
const busyKey = ref("");
const snackbar = ref(false);
const snackbarText = ref("");
const snackbarColor = ref("success");
const overview = ref({ counts: {} });
const gyms = ref([]);
const users = ref([]);
const invites = ref([]);
const services = ref([]);
const planTiers = ref([]);

const gymHeaders = [
  { title: "Gym", key: "gymName" },
  { title: "Owner", key: "owner.name" },
  { title: "Plan", key: "plan", sortable: false },
  { title: "Usage", key: "usage", sortable: false },
  { title: "Status", key: "status" },
  { title: "Actions", key: "actions", sortable: false },
];

const userHeaders = [
  { title: "Name", key: "name" },
  { title: "Email", key: "email" },
  { title: "Role", key: "roleControl", sortable: false },
  { title: "Gym", key: "gymName" },
  { title: "Status", key: "accountStatus" },
  { title: "Actions", key: "actions", sortable: false },
];

const roleOptions = [
  { label: "Superadmin", value: "superadmin" },
  { label: "Admin", value: "admin" },
  { label: "Owner", value: "gym_owner" },
  { label: "Staff", value: "gym_staff" },
  { label: "Trainer", value: "gym_trainer" },
  { label: "Member", value: "gym_member" },
];

const inviteHeaders = [
  { title: "Code", key: "code" },
  { title: "Role", key: "role" },
  { title: "Gym", key: "gymName" },
  { title: "Invitee", key: "inviteeName" },
  { title: "Status", key: "used" },
];

const metrics = computed(() => [
  {
    label: "Gyms",
    value: overview.value.counts?.gyms || 0,
    icon: "mdi-domain",
    hint: `${overview.value.counts?.activeGyms || 0} active`,
  },
  {
    label: "Members",
    value: overview.value.counts?.members || 0,
    icon: "mdi-account-group-outline",
    hint: "Registered network members",
  },
  {
    label: "Open Invites",
    value: overview.value.counts?.openInvites || 0,
    icon: "mdi-ticket-outline",
    hint: "Seats reserved by invite",
  },
  {
    label: "Trainers",
    value: overview.value.counts?.trainers || 0,
    icon: "mdi-dumbbell",
    hint: `${overview.value.counts?.staff || 0} staff`,
  },
]);

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

function usagePercent(gym) {
  const used = Number(gym.usage?.usedSeats || 0);
  const cap = Math.max(1, Number(gym.memberCap || gym.usage?.memberCap || 1));
  return Math.min(100, Math.round((used / cap) * 100));
}

function usageTone(gym) {
  const percent = usagePercent(gym);
  if (percent >= 100 || gym.planStatus === "locked") return "error";
  if (percent >= 80) return "warning";
  return "primary";
}

function usageLabel(gym) {
  const used = Number(gym.usage?.usedSeats || 0);
  const cap = Number(gym.memberCap || gym.usage?.memberCap || 0);
  return `${used}/${cap} seats`;
}

async function loadAll() {
  loading.value = true;
  error.value = "";
  try {
    const [overviewRes, gymsRes, usersRes, invitesRes, servicesRes] = await Promise.all([
      apiFetch("/api/admin/network/overview"),
      apiFetch("/api/admin/gyms"),
      apiFetch("/api/admin/users"),
      apiFetch("/api/admin/invites"),
      apiFetch("/api/admin/service-analytics"),
    ]);
    const [overviewData, gymsData, usersData, invitesData, servicesData] = await Promise.all([
      overviewRes.json(),
      gymsRes.json(),
      usersRes.json(),
      invitesRes.json(),
      servicesRes.json(),
    ]);
    const failed = [overviewRes, gymsRes, usersRes, invitesRes, servicesRes].find((res) => !res.ok);
    if (failed) {
      throw new Error(
        overviewData.message ||
          gymsData.message ||
          usersData.message ||
          invitesData.message ||
          servicesData.message ||
          "Could not load network control.",
      );
    }
    overview.value = overviewData;
    gyms.value = gymsData.gyms || [];
    users.value = usersData.users || [];
    invites.value = invitesData.invites || [];
    services.value = servicesData.services || [];
    planTiers.value = gymsData.planTiers || overviewData.planTiers || [];
  } catch (err) {
    error.value = err?.message || "Could not load network control.";
  } finally {
    loading.value = false;
  }
}

async function patchGym(gym, body) {
  busyKey.value = `gym-${gym.id}`;
  try {
    const res = await apiFetch(`/api/admin/gyms/${gym.id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not update gym.");
    gyms.value = gyms.value.map((row) => (row.id === gym.id ? data.gym : row));
    showMessage("Gym updated.");
  } catch (err) {
    showMessage(err?.message || "Could not update gym.", "error");
  } finally {
    busyKey.value = "";
  }
}

function updateGymPlan(gym, platformPlan) {
  const tier = planTiers.value.find((item) => item.key === platformPlan);
  const body = { platformPlan, planStatus: "active" };
  if (tier?.memberCap) body.memberCap = tier.memberCap;
  patchGym(gym, body);
}

function updateGymCap(gym, memberCap) {
  patchGym(gym, { platformPlan: "custom", memberCap });
}

function toggleGymStatus(gym) {
  patchGym(gym, { status: gym.status === "active" ? "inactive" : "active" });
}

async function toggleUserStatus(user) {
  busyKey.value = `user-${user.id}`;
  try {
    const res = await apiFetch(`/api/admin/users/${user.id}`, {
      method: "PATCH",
      body: JSON.stringify({
        accountStatus: user.accountStatus === "active" ? "deactivated" : "active",
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not update user.");
    users.value = users.value.map((row) => (row.id === user.id ? data.user : row));
    showMessage("User updated.");
  } catch (err) {
    showMessage(err?.message || "Could not update user.", "error");
  } finally {
    busyKey.value = "";
  }
}

async function updateUserRole(user, role) {
  busyKey.value = `user-${user.id}`;
  try {
    const res = await apiFetch(`/api/admin/users/${user.id}`, {
      method: "PATCH",
      body: JSON.stringify({ role, gymId: user.gymId }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not update user role.");
    users.value = users.value.map((row) => (row.id === user.id ? data.user : row));
    showMessage("User role updated.");
  } catch (err) {
    showMessage(err?.message || "Could not update user role.", "error");
  } finally {
    busyKey.value = "";
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(loadAll);
</script>

<style scoped>
.network-panel {
  margin-top: 20px;
}

.network-tabs {
  margin-top: 12px;
}

.network-window {
  margin-top: 18px;
}

.network-inline-control {
  display: grid;
  grid-template-columns: minmax(170px, 1fr) minmax(90px, 110px);
  gap: 8px;
  min-width: 280px;
}

.usage-grid {
  display: grid;
  gap: 14px;
}

.usage-card {
  display: grid;
  gap: 12px;
  padding: 16px;
  border-radius: 16px;
}

.usage-card__title {
  font-weight: 800;
}

.usage-card__copy {
  color: var(--gm-text-muted);
  margin-top: 4px;
}

.service-list {
  display: grid;
  gap: 10px;
}

.service-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 16px;
  border: 1px solid rgba(181, 159, 91, 0.18);
  border-radius: 16px;
}

@media (max-width: 760px) {
  .network-inline-control {
    grid-template-columns: 1fr;
    min-width: 220px;
  }
}
</style>
