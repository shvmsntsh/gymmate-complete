<template>
  <AdminShell
    :is-dark="isDark"
    title="Network Control"
    eyebrow="Platform Admin"
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
        <div class="network-selector">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">Select a gym</div>
              <h2 class="section-title">Choose what you are editing</h2>
              <p class="section-copy">
                Pick one gym first. The selected gym stays visible while you update plan, status, people, and access.
              </p>
            </div>
            <v-text-field
              v-model="gymSearch"
              class="network-search"
              density="comfortable"
              hide-details
              placeholder="Search gyms or owners"
              prepend-inner-icon="mdi-magnify"
              variant="outlined"
            />
          </div>

          <div class="network-gym-grid">
            <button
              v-for="gym in filteredGyms"
              :key="gym.id"
              type="button"
              class="network-gym-card"
              :class="{ 'network-gym-card--selected': selectedGym?.id === gym.id }"
              @click="selectGym(gym)"
            >
              <span>
                <strong>{{ gym.gymName }}</strong>
                <small>{{ gym.owner?.name || gym.owner?.email || "No owner assigned" }}</small>
              </span>
              <v-chip :color="gym.status === 'active' ? 'success' : 'error'" size="small" variant="tonal">
                {{ selectedGym?.id === gym.id ? "Selected" : gym.status }}
              </v-chip>
            </button>
          </div>

          <div v-if="selectedGym" class="network-context-bar">
            <div>
              <div class="table-overline">Selected gym</div>
              <h3>{{ selectedGym.gymName }}</h3>
              <p>{{ selectedGym.owner?.email || selectedGym.email || "No owner email" }} · {{ usageLabel(selectedGym) }}</p>
            </div>
            <div class="network-context-actions">
              <v-select
                :items="planTiers"
                item-title="name"
                item-value="key"
                :model-value="selectedGym.platformPlan"
                density="comfortable"
                hide-details
                label="Plan"
                variant="outlined"
                @update:model-value="(value) => updateGymPlan(selectedGym, value)"
              />
              <v-btn
                :color="selectedGym.status === 'active' ? 'error' : 'primary'"
                variant="tonal"
                :loading="busyKey === `gym-${selectedGym.id}`"
                @click="toggleGymStatus(selectedGym)"
              >
                {{ selectedGym.status === "active" ? "Deactivate gym" : "Activate gym" }}
              </v-btn>
            </div>
          </div>
        </div>

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
const gymSearch = ref("");
const selectedGym = ref(null);
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

const filteredGyms = computed(() => {
  const query = gymSearch.value.trim().toLowerCase();
  if (!query) return gyms.value;
  return gyms.value.filter((gym) =>
    [gym.gymName, gym.name, gym.email, gym.owner?.name, gym.owner?.email]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query)),
  );
});

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

function selectGym(gym) {
  selectedGym.value = gym;
  tab.value = "gyms";
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
    if (!selectedGym.value && gyms.value.length) {
      selectedGym.value = gyms.value[0];
    } else if (selectedGym.value) {
      selectedGym.value = gyms.value.find((gym) => gym.id === selectedGym.value.id) || gyms.value[0] || null;
    }
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
    if (selectedGym.value?.id === gym.id) {
      selectedGym.value = data.gym;
    }
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

.network-selector {
  display: grid;
  gap: 16px;
  margin-bottom: 18px;
}

.network-search {
  max-width: 340px;
}

.network-gym-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
}

.network-gym-card {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  min-height: 96px;
  padding: 16px;
  border: 1px solid var(--gm-border);
  border-radius: 16px;
  background: var(--gm-surface-muted);
  color: var(--gm-text);
  cursor: pointer;
  text-align: left;
}

.network-gym-card--selected {
  border-color: var(--gm-primary);
  background: color-mix(in srgb, var(--gm-primary) 12%, var(--gm-surface-strong));
  box-shadow: 0 16px 38px rgba(255, 82, 0, 0.12);
}

.network-gym-card strong,
.network-gym-card small {
  display: block;
}

.network-gym-card small {
  margin-top: 5px;
  color: var(--gm-text-soft);
}

.network-context-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  padding: 18px;
  border: 1px solid var(--gm-border-strong);
  border-radius: 18px;
  background: linear-gradient(135deg, color-mix(in srgb, var(--gm-primary) 10%, var(--gm-surface-strong)), var(--gm-surface-strong));
}

.network-context-bar h3,
.network-context-bar p {
  margin: 0;
}

.network-context-bar p {
  color: var(--gm-text-soft);
}

.network-context-actions {
  display: grid;
  grid-template-columns: minmax(220px, 1fr) auto;
  gap: 12px;
  align-items: center;
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
  color: var(--gm-text-soft);
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
  .network-gym-grid,
  .network-context-actions {
    grid-template-columns: 1fr;
  }

  .network-context-bar {
    align-items: stretch;
    flex-direction: column;
  }

  .network-inline-control {
    grid-template-columns: 1fr;
    min-width: 220px;
  }
}
</style>
