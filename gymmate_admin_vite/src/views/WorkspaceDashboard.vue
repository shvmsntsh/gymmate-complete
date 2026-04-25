<template>
  <AdminShell
    :is-dark="isDark"
    title="Command Center"
    eyebrow="Gym Operations"
    description="Daily health, pending work, and revenue signals for the gym team."
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
              <div class="table-overline">Priority Queue</div>
              <h2 class="section-title">Work that needs a decision</h2>
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
              <div class="table-overline">Today</div>
              <h2 class="section-title">Attendance and classes</h2>
            </div>
          </div>
          <div class="workspace-stack">
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
              <div class="table-overline">CRM</div>
              <h2 class="section-title">Fresh leads</h2>
            </div>
            <v-btn icon="mdi-arrow-right" variant="text" @click="router.push('/crm')" />
          </div>
          <div class="workspace-stack">
            <div v-for="lead in leadQueue" :key="lead.id" class="workspace-row">
              <div>
                <strong>{{ lead.name }}</strong>
                <span>{{ lead.status }} · {{ lead.phone || lead.email || "No contact" }}</span>
              </div>
              <b>{{ lead.source }}</b>
            </div>
          </div>
        </section>

        <section class="workspace-panel">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">Billing</div>
              <h2 class="section-title">Recent collections</h2>
            </div>
            <v-btn icon="mdi-arrow-right" variant="text" @click="router.push('/payments')" />
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
              <b>{{ money(payment.amount) }}</b>
            </div>
          </div>
        </section>

        <section class="workspace-panel">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">Roadmap</div>
              <h2 class="section-title">Next modules</h2>
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
import { apiFetch, clearAdminSession } from "../lib/api";
import { formatDateTimeUs } from "../lib/date";
import { useAdminTheme } from "../composables/useAdminTheme";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const loading = ref(true);
const error = ref("");
const dashboard = ref({ kpis: {}, queues: {} });

function money(value) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(Number(value || 0));
}

const metrics = computed(() => {
  const kpis = dashboard.value.kpis || {};
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
  {
    title: `${dashboard.value.kpis?.openLeads || 0} leads`,
    copy: "Call, qualify, or schedule a trial.",
    icon: "mdi-account-search-outline",
    to: "/crm",
  },
  {
    title: `${dashboard.value.kpis?.dues || 0} dues`,
    copy: "Review payment status and receipts.",
    icon: "mdi-cash-register",
    to: "/payments",
  },
  {
    title: `${dashboard.value.kpis?.expiringMemberships || 0} renewals`,
    copy: "Memberships ending in the next 14 days.",
    icon: "mdi-card-account-details-outline",
    to: "/membership",
  },
  {
    title: `${dashboard.value.kpis?.staffCount || 0} staff`,
    copy: "Review workload and permissions.",
    icon: "mdi-badge-account-horizontal-outline",
    to: "/staff",
  },
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
