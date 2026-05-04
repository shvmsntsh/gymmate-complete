<template>
  <AdminShell
    :is-dark="isDark"
    title="Command Center"
    :eyebrow="isSuperadmin ? 'Platform Command' : 'Gym Operations'"
    :description="isSuperadmin ? 'Network-wide gyms, users, activity, and health signals.' : 'Daily health, pending work, and revenue signals for the gym team.'"
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <StateBlock
      v-if="error"
      title="Could not load command center"
      :copy="error"
      icon="mdi-alert-circle-outline"
      tone="error"
    />
    <StateBlock
      v-else-if="loading"
      title="Loading command center"
      copy="Pulling live operations, revenue, attendance, leads, and classes."
      icon="mdi-timer-sand"
    />
    <template v-else>
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

      <div class="workspace-band workspace-band--split">
        <section class="workspace-panel workspace-panel--wide">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">{{ isSuperadmin ? 'Network Queue' : 'Priority Queue' }}</div>
              <h2 class="section-title">{{ isSuperadmin ? 'Platform areas to monitor' : 'Work that needs a decision' }}</h2>
            </div>
            <v-btn variant="tonal" color="primary" @click="fetchDashboard">
              <v-icon start icon="mdi-refresh" />
              Refresh
            </v-btn>
          </div>

          <div class="workspace-action-grid">
            <button
              v-for="action in actions"
              :key="action.to"
              class="workspace-action"
              type="button"
              @click="router.push(action.to)"
            >
              <v-icon :icon="action.icon" />
              <span>
                <strong>{{ action.title }}</strong>
                <small>{{ action.copy }}</small>
              </span>
            </button>
          </div>
        </section>

        <section class="workspace-panel">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">{{ isSuperadmin ? 'Health' : 'Today' }}</div>
              <h2 class="section-title">{{ isSuperadmin ? 'API and database' : 'Attendance and classes' }}</h2>
            </div>
          </div>
          <div v-if="isSuperadmin" class="workspace-stack">
            <div class="workspace-row">
              <div>
                <strong>Backend API</strong>
                <span>{{ dashboard.health?.ok ? "Health check passed" : "Open System Health for details" }}</span>
              </div>
              <b>{{ dashboard.health?.ok ? "Online" : "Review" }}</b>
            </div>
          </div>
          <div v-else class="workspace-stack">
            <div
              v-for="session in classQueue"
              :key="session.id"
              class="workspace-row"
            >
              <div>
                <strong>{{ session.template?.name || "Class session" }}</strong>
                <span>{{ formatDateTimeUs(session.startsAt) }}</span>
              </div>
              <b>{{ session.bookedCount }}/{{ session.capacity }}</b>
            </div>
            <StateBlock
              v-if="classQueue.length === 0"
              title="No classes today"
              copy="Create class sessions from the Classes/PT workspace."
              icon="mdi-calendar-clock"
            />
          </div>
        </section>
      </div>

      <div class="workspace-band workspace-band--three">
        <section class="workspace-panel">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">{{ isSuperadmin ? 'Gyms' : 'CRM' }}</div>
              <h2 class="section-title">{{ isSuperadmin ? 'Recent gyms' : 'Fresh leads' }}</h2>
            </div>
            <v-btn icon="mdi-arrow-right" variant="text" @click="router.push(isSuperadmin ? '/network' : '/crm')" />
          </div>
          <div class="workspace-stack">
            <div v-for="lead in leadQueue" :key="lead.id" class="workspace-row">
              <div>
                <strong>{{ lead.name }}</strong>
                <span>{{ isSuperadmin ? lead.status : `${lead.status} · ${lead.phone || lead.email || "No contact"}` }}</span>
              </div>
              <b>{{ lead.source || lead.usage }}</b>
            </div>
          </div>
        </section>

        <section class="workspace-panel">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">{{ isSuperadmin ? 'People' : 'Billing' }}</div>
              <h2 class="section-title">{{ isSuperadmin ? 'Users by role' : 'Recent collections' }}</h2>
            </div>
            <v-btn icon="mdi-arrow-right" variant="text" @click="router.push(isSuperadmin ? '/network' : '/payments')" />
          </div>
          <div class="workspace-stack">
            <div
              v-for="payment in paymentQueue"
              :key="payment.id"
              class="workspace-row"
            >
              <div>
                <strong>{{ payment.member?.name || "Member" }}</strong>
                <span>{{ formatDateTimeUs(payment.recordedAt) }} · {{ payment.mode }}</span>
              </div>
              <b>{{ isSuperadmin ? payment.amount : money(payment.amount) }}</b>
            </div>
          </div>
        </section>

        <section class="workspace-panel">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">{{ isSuperadmin ? 'Admin' : 'Roadmap' }}</div>
              <h2 class="section-title">{{ isSuperadmin ? 'Platform tools' : 'Next modules' }}</h2>
            </div>
          </div>
          <div class="workspace-stack">
            <div
              v-for="item in roadmap"
              :key="item"
              class="workspace-row workspace-row--plain"
            >
              <span>{{ item }}</span>
            </div>
          </div>
        </section>
      </div>
    </template>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import StatCard from "../components/StatCard.vue";
import { API_BASE_URL, apiFetch, clearAdminSession, getAdminRole } from "../lib/api";
import { formatDateTimeUs } from "../lib/date";
import { useAdminTheme } from "../composables/useAdminTheme";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const loading = ref(true);
const error = ref("");
const dashboard = ref({ kpis: {}, queues: {} });
const isSuperadmin = computed(() => getAdminRole() === "admin");

function money(value) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(Number(value || 0));
}

const metrics = computed(() => {
  const kpis = dashboard.value.kpis || {};
  if (isSuperadmin.value) {
    return [
      { label: "Total Gyms", value: kpis.gyms || 0, icon: "mdi-domain", hint: `${kpis.activeGyms || 0} active gyms.` },
      { label: "Active Members", value: kpis.members || 0, icon: "mdi-account-group-outline", hint: "Members across the platform." },
      { label: "Owners", value: kpis.owners || 0, icon: "mdi-account-tie-outline", hint: `${kpis.staff || 0} staff and ${kpis.trainers || 0} trainers.` },
      { label: "Open Invites", value: kpis.openInvites || 0, icon: "mdi-ticket-outline", hint: "Unclaimed platform invites." },
      { label: "Blocked Gyms", value: kpis.blockedGyms || 0, icon: "mdi-domain-off", hint: "Inactive gyms needing review." },
      { label: "System", value: dashboard.value.health?.ok ? "Online" : "Review", icon: "mdi-heart-pulse", hint: "Health endpoint status." },
    ];
  }
  return [
    {
      label: "Active Members",
      value: kpis.activeMembers || 0,
      icon: "mdi-account-group-outline",
      hint: "Current active member base.",
    },
    {
      label: "Open Leads",
      value: kpis.openLeads || 0,
      icon: "mdi-account-search-outline",
      hint: "New or active follow-ups.",
    },
    {
      label: "Check-ins Today",
      value: kpis.todayCheckIns || 0,
      icon: "mdi-calendar-check-outline",
      hint: "Manual and biometric visits.",
    },
    {
      label: "Revenue Today",
      value: money(kpis.revenueToday || 0),
      icon: "mdi-cash-register",
      hint: `${kpis.paymentsToday || 0} payments recorded.`,
    },
    {
      label: "Dues",
      value: kpis.dues || 0,
      icon: "mdi-receipt-clock-outline",
      hint: "Unpaid or review memberships.",
    },
    {
      label: "Class Fill",
      value: `${kpis.classFillRate || 0}%`,
      icon: "mdi-calendar-clock",
      hint: `${kpis.classesToday || 0} sessions today.`,
    },
  ];
});

const actions = computed(() => [
  ...(isSuperadmin.value
    ? [
        { title: "Gyms & users", copy: "Manage gyms, owners, staff, plan caps, and account status.", icon: "mdi-domain", to: "/network" },
        { title: "Invites", copy: "Create and review gym owner invite codes.", icon: "mdi-ticket-confirmation-outline", to: "/invites" },
        { title: "System health", copy: "Check backend and database availability.", icon: "mdi-heart-pulse", to: "/system-health" },
        { title: "Settings", copy: "Change local appearance mode.", icon: "mdi-cog-outline", to: "/settings" },
      ]
    : [
        { title: `${dashboard.value.kpis?.openLeads || 0} leads`, copy: "Call, qualify, or schedule a trial.", icon: "mdi-account-search-outline", to: "/crm" },
        { title: `${dashboard.value.kpis?.dues || 0} dues`, copy: "Review payment status and receipts.", icon: "mdi-cash-register", to: "/payments" },
        { title: `${dashboard.value.kpis?.expiringMemberships || 0} renewals`, copy: "Memberships ending in the next 14 days.", icon: "mdi-card-account-details-outline", to: "/membership" },
        { title: `${dashboard.value.kpis?.staffCount || 0} staff`, copy: "Review workload and permissions.", icon: "mdi-badge-account-horizontal-outline", to: "/staff" },
      ]),
]);

const leadQueue = computed(() => dashboard.value.queues?.leads || []);
const paymentQueue = computed(() => dashboard.value.queues?.payments || []);
const classQueue = computed(() => dashboard.value.queues?.classes || []);
const roadmap = [
  "WhatsApp automation",
  "Campaign segments",
  "AI business insights",
  "Inventory and POS",
  "Rewards and referrals",
];

async function fetchDashboard() {
  loading.value = true;
  error.value = "";
  try {
    if (isSuperadmin.value) {
      const [overviewRes, gymsRes, healthRes] = await Promise.all([
        apiFetch("/api/admin/network/overview"),
        apiFetch("/api/admin/gyms"),
        fetch(`${API_BASE_URL}/api/health`).catch(() => null),
      ]);
      const [overviewData, gymsData, healthData] = await Promise.all([
        overviewRes.json(),
        gymsRes.json(),
        healthRes?.json?.() || Promise.resolve({ ok: false }),
      ]);
      if (!overviewRes.ok) throw new Error(overviewData.message || "Could not load platform dashboard.");
      const counts = overviewData.counts || {};
      dashboard.value = {
        kpis: {
          gyms: counts.gyms || 0,
          activeGyms: counts.activeGyms || 0,
          blockedGyms: Math.max(0, (counts.gyms || 0) - (counts.activeGyms || 0)),
          members: counts.members || 0,
          owners: counts.owners || 0,
          staff: counts.staff || 0,
          trainers: counts.trainers || 0,
          openInvites: counts.openInvites || 0,
        },
        queues: {
          leads: (gymsData.gyms || overviewData.recentGyms || []).slice(0, 5).map((gym) => ({
            id: gym.id,
            name: gym.gymName || gym.name,
            status: `${gym.status || "active"} · ${gym.owner?.name || "No owner assigned"}`,
            source: `${gym.usage?.usedSeats || 0}/${gym.memberCap || gym.usage?.memberCap || 0} seats`,
          })),
          payments: [
            { id: "owners", member: { name: "Owners" }, mode: "Platform", amount: counts.owners || 0, recordedAt: new Date() },
            { id: "staff", member: { name: "Staff" }, mode: "Platform", amount: counts.staff || 0, recordedAt: new Date() },
            { id: "trainers", member: { name: "Trainers" }, mode: "Platform", amount: counts.trainers || 0, recordedAt: new Date() },
          ],
          classes: [],
        },
        health: healthData || { ok: false },
      };
      return;
    }
    const res = await apiFetch("/api/workspace/dashboard");
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "Could not load workspace dashboard.");
    }
    dashboard.value = data;
  } catch (err) {
    error.value = err?.message || "Could not load workspace dashboard.";
  } finally {
    loading.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(fetchDashboard);
</script>
