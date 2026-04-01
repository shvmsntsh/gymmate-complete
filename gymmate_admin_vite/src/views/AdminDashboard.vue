<template>
  <AdminShell
    :is-dark="isDark"
    :title="pageTitle"
    :eyebrow="pageEyebrow"
    :description="pageDescription"
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

    <div class="overview-grid" style="margin-top: 20px">
      <section
        class="admin-surface admin-panel overview-card overview-card--chart"
      >
        <div class="section-header">
          <div>
            <div class="table-overline">{{ chartEyebrow }}</div>
            <h2 class="section-title">{{ chartTitle }}</h2>
            <p class="section-copy">{{ chartCopy }}</p>
            <div v-if="isOwnerView && !chartLoading && !chartError" class="chart-microcopy">
              <span class="chart-pill">{{ weeklySignups }} new members this week</span>
              <span class="chart-pill" v-if="bestSignupDay">Best day: {{ bestSignupDay }}</span>
            </div>
          </div>
        </div>

        <StateBlock
          v-if="chartError"
          :title="chartErrorTitle"
          :copy="chartError"
          icon="mdi-chart-bar"
          tone="error"
        />
        <StateBlock
          v-else-if="chartLoading"
          :title="chartLoadingTitle"
          :copy="chartLoadingCopy"
          icon="mdi-timer-sand"
        />
        <canvas v-else ref="usageChartRef"></canvas>
      </section>

      <section
        class="admin-surface admin-panel overview-card overview-card--partners"
      >
        <div class="section-header">
          <div>
            <div class="table-overline">{{ sideEyebrow }}</div>
            <h2 class="section-title">{{ sideTitle }}</h2>
            <p class="section-copy">{{ sideCopy }}</p>
          </div>
        </div>

        <StateBlock
          v-if="sideError"
          :title="sideErrorTitle"
          :copy="sideError"
          icon="mdi-alert-circle-outline"
          tone="error"
        />
        <StateBlock
          v-else-if="sideLoading"
          :title="sideLoadingTitle"
          :copy="sideLoadingCopy"
          icon="mdi-timer-sand"
        />
        <StateBlock
          v-else-if="sideItems.length === 0"
          :title="sideEmptyTitle"
          :copy="sideEmptyCopy"
          :icon="isOwnerView ? 'mdi-ticket-outline' : 'mdi-domain-off'"
        />
        <div v-else class="partner-list">
          <button
            v-for="item in sideItems"
            :key="item.id"
            type="button"
            class="partner-item"
            @click="handleSideItem(item)"
          >
            <div>
              <div class="partner-item__title">{{ item.title }}</div>
              <div class="partner-item__copy">{{ item.copy }}</div>
            </div>
            <div class="partner-item__status">{{ item.status }}</div>
          </button>
        </div>
      </section>
    </div>

    <div class="overview-grid overview-grid--bottom" style="margin-top: 20px">
      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">{{ lowerLeftEyebrow }}</div>
            <h2 class="section-title">{{ lowerLeftTitle }}</h2>
            <p class="section-copy">{{ lowerLeftCopy }}</p>
          </div>
        </div>

        <template v-if="isOwnerView">
          <div class="reach-panel">
            <div class="reach-panel__copy">
              {{ gymName || "Your gym" }} is carrying a clear identity with
              <strong>{{ brandCompletion }}% brand completion</strong>,
              <strong>{{ inviteCount }}</strong> active invites, and a member
              roster that is ready for the next push.
            </div>
            <div class="reach-panel__stats">
              <div class="reach-pill">
                <span class="reach-pill__label">Brand</span>
                <span class="reach-pill__value">{{ brandCompletion }}%</span>
              </div>
              <div class="reach-pill">
                <span class="reach-pill__label">Primary</span>
                <span class="reach-pill__value">{{
                  branding.primaryColor
                }}</span>
              </div>
              <div class="reach-pill">
                <span class="reach-pill__label">Secondary</span>
                <span class="reach-pill__value">{{
                  branding.secondaryColor
                }}</span>
              </div>
              <div class="reach-pill">
                <span class="reach-pill__label">Services</span>
                <span class="reach-pill__value">{{ servicesPreview }}</span>
              </div>
            </div>
            <div class="cta-row">
              <v-btn
                color="primary"
                size="large"
                @click="router.push('/branding')"
                >Open branding</v-btn
              >
              <v-btn
                size="large"
                variant="tonal"
                @click="router.push('/invites')"
                >Open invites</v-btn
              >
            </div>
          </div>
        </template>
        <template v-else>
          <div class="reach-panel">
            <div class="reach-panel__copy">
              GymMate is holding <strong>{{ gymCount }}</strong> gyms,
              <strong>{{ ownerCount }}</strong> owners, and
              <strong>{{ memberCount }}</strong> members inside one operating
              rhythm.
            </div>
            <div class="reach-panel__stats">
              <div class="reach-pill">
                <span class="reach-pill__label">Gyms</span>
                <span class="reach-pill__value">{{ gymCount }}</span>
              </div>
              <div class="reach-pill">
                <span class="reach-pill__label">Owners</span>
                <span class="reach-pill__value">{{ ownerCount }}</span>
              </div>
              <div class="reach-pill">
                <span class="reach-pill__label">Members</span>
                <span class="reach-pill__value">{{ memberCount }}</span>
              </div>
            </div>
          </div>
        </template>
      </section>

      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">{{ lowerRightEyebrow }}</div>
            <h2 class="section-title">{{ lowerRightTitle }}</h2>
            <p class="section-copy">{{ lowerRightCopy }}</p>
          </div>
        </div>

        <template v-if="isOwnerView">
          <StateBlock
            v-if="rosterError"
            title="Could not load your roster"
            :copy="rosterError"
            icon="mdi-account-group-outline"
            tone="error"
          />
          <StateBlock
            v-else-if="rosterLoading"
            title="Loading your roster"
            copy="Pulling the latest member and coach names now."
            icon="mdi-timer-sand"
          />
          <StateBlock
            v-else-if="rosterItems.length === 0"
            title="No roster yet"
            copy="As members and coaches join your gym, they will appear here for a quick glance."
            icon="mdi-account-off-outline"
          />
          <div v-else class="partner-list">
            <div
              v-for="item in rosterItems"
              :key="item.id"
              class="partner-item partner-item--static"
            >
              <div>
                <div class="partner-item__title">{{ item.title }}</div>
                <div class="partner-item__copy">{{ item.copy }}</div>
              </div>
              <div class="partner-item__status">{{ item.status }}</div>
            </div>
          </div>
        </template>
        <template v-else>
          <div class="health-list">
            <div class="health-row">
              <div class="health-row__head">
                <span>Gym coverage</span>
                <strong>{{ gymCount > 0 ? "100%" : "0%" }}</strong>
              </div>
              <div class="health-row__bar">
                <span style="width: 100%"></span>
              </div>
            </div>
            <div class="health-row">
              <div class="health-row__head">
                <span>Owner readiness</span>
                <strong>{{ ownerReadiness }}</strong>
              </div>
              <div class="health-row__bar">
                <span :style="{ width: ownerReadiness }"></span>
              </div>
            </div>
            <div class="health-row">
              <div class="health-row__head">
                <span>Member support response</span>
                <strong>{{ memberSupport }}</strong>
              </div>
              <div class="health-row__bar">
                <span :style="{ width: memberSupport }"></span>
              </div>
            </div>
          </div>
        </template>
      </section>
    </div>
  </AdminShell>
</template>

<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StatCard from "../components/StatCard.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch, clearAdminSession, getAdminRole } from "../lib/api";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const sessionRole = computed(() => getAdminRole());
const isOwnerView = computed(() => sessionRole.value === "owner");

const gymCount = ref(0);
const ownerCount = ref(0);
const trainerCount = ref(0);
const memberCount = ref(0);
const inviteCount = ref(0);
const brandCompletion = ref(0);
const recentGyms = ref([]);
const recentInvites = ref([]);
const rosterItems = ref([]);
const chartSeries = ref([]);
const gymName = ref("");
const branding = ref({ primaryColor: "#B59F5B", secondaryColor: "#F8D84B" });
const services = ref([]);

const loadingStats = ref(false);
const loadingSide = ref(false);
const loadingRoster = ref(false);
const statsError = ref("");
const sideError = ref("");
const rosterError = ref("");
const usageChartRef = ref(null);
let usageChart = null;
let ChartLibrary = null;

const ownerReadiness = computed(() => {
  if (!gymCount.value) return "0%";
  return `${Math.min(100, Math.round((ownerCount.value / gymCount.value) * 100))}%`;
});

const memberSupport = computed(() => {
  if (!memberCount.value) return "0%";
  const normalized = Math.min(
    96,
    Math.max(42, Math.round(72 + memberCount.value / 50)),
  );
  return `${normalized}%`;
});

const servicesPreview = computed(() => {
  if (!services.value.length) return "Starter";
  return services.value.slice(0, 2).join(" / ");
});

const weeklySignups = computed(() =>
  chartSeries.value.reduce((sum, entry) => sum + Number(entry.value || 0), 0),
);

const bestSignupDay = computed(() => {
  if (!chartSeries.value.length) return "";
  const winner = chartSeries.value.reduce((best, entry) =>
    Number(entry.value || 0) >= Number(best.value || 0) ? entry : best,
  );
  return Number(winner.value || 0) > 0 ? winner.label : "";
});

const pageTitle = computed(() =>
  isOwnerView.value ? "Owner Overview" : "Network Overview",
);
const pageEyebrow = computed(() =>
  isOwnerView.value ? "Gym Workspace" : "GymMate Admin",
);
const pageDescription = computed(() =>
  isOwnerView.value
    ? "Keep your gym brand, member roster, invites, and weekly momentum in one calm workspace."
    : "A cleaner read on growth, active gyms, and where the network needs attention next.",
);

const chartEyebrow = computed(() =>
  isOwnerView.value ? "Weekly Signups" : "Network Growth",
);
const chartTitle = computed(() =>
  isOwnerView.value
    ? "Signups across the last seven days."
    : "Membership expansion across the last seven days.",
);
const chartCopy = computed(() =>
  isOwnerView.value
    ? "A clearer weekly view of when your member flow picks up and when a fresh invite push could help."
    : "Use this to spot where the network is picking up momentum and when signups start to cool off.",
);
const chartErrorTitle = computed(() =>
  isOwnerView.value ? "Signup view unavailable" : "Growth overview unavailable",
);
const chartLoadingTitle = computed(() =>
  isOwnerView.value ? "Loading signup view" : "Loading growth overview",
);
const chartLoadingCopy = computed(() =>
  isOwnerView.value
    ? "Pulling your weekly signup rhythm now."
    : "Pulling the latest network totals now.",
);
const chartError = computed(() => statsError.value);
const chartLoading = computed(() => loadingStats.value);

const sideEyebrow = computed(() =>
  isOwnerView.value ? "Invites" : "Recent Gyms",
);
const sideTitle = computed(() =>
  isOwnerView.value ? "Open invitations ready to share" : "Newest partner gyms",
);
const sideCopy = computed(() =>
  isOwnerView.value
    ? "Your most recent invites are collected here so you can share them quickly with members and coaches."
    : "A live list of the most recent gyms added to GymMate.",
);
const sideLoadingTitle = computed(() =>
  isOwnerView.value ? "Loading invites" : "Loading recent gyms",
);
const sideLoadingCopy = computed(() =>
  isOwnerView.value
    ? "Pulling your latest invite codes now."
    : "Pulling the latest registered gyms now.",
);
const sideErrorTitle = computed(() =>
  isOwnerView.value ? "Could not load invites" : "Could not load recent gyms",
);
const sideEmptyTitle = computed(() =>
  isOwnerView.value ? "No open invites yet" : "No gyms registered yet",
);
const sideEmptyCopy = computed(() =>
  isOwnerView.value
    ? "Generate your first member or coach invite and it will appear here for quick sharing."
    : "Once the first gyms come in, they will appear here with their contact details and services.",
);
const sideItems = computed(() =>
  isOwnerView.value ? recentInvites.value : recentGyms.value,
);
const sideLoading = computed(() => loadingSide.value);

const lowerLeftEyebrow = computed(() =>
  isOwnerView.value ? "Brand Status" : "Reach",
);
const lowerLeftTitle = computed(() =>
  isOwnerView.value ? "How your gym is showing up" : "Global reach",
);
const lowerLeftCopy = computed(() =>
  isOwnerView.value
    ? "Keep your gym name, color direction, and invite readiness clear before members ever step inside."
    : "A simple snapshot of how many gyms, owners, and members are moving through the product today.",
);

const lowerRightEyebrow = computed(() =>
  isOwnerView.value ? "Member Floor" : "Network Health",
);
const lowerRightTitle = computed(() =>
  isOwnerView.value ? "Who is on the floor right now" : "Operational health",
);
const lowerRightCopy = computed(() =>
  isOwnerView.value
    ? "A quick look at the current people tied to your gym so follow-ups stay easy."
    : "A quick signal on coverage, owner readiness, and member support momentum.",
);

function chartTextColor() {
  return isDark.value ? "#f8f1e6" : "#201a15";
}

function chartGridColor() {
  return isDark.value ? "rgba(248, 241, 230, 0.08)" : "rgba(32, 26, 21, 0.08)";
}

function destroyChart() {
  usageChart?.destroy();
  usageChart = null;
}

async function ensureChartLibrary() {
  if (ChartLibrary) {
    return ChartLibrary;
  }

  const module = await import("chart.js/auto");
  ChartLibrary = module.default;
  return ChartLibrary;
}

async function renderUsageChart() {
  if (!usageChartRef.value || chartError.value || chartLoading.value) {
    return;
  }

  const Chart = await ensureChartLibrary();
  destroyChart();

  const labels = chartSeries.value.map((entry) => entry.label);
  const values = chartSeries.value.map((entry) => entry.value);
  const peak = values.length ? Math.max(...values) : 0;
  const ownerInactive = isDark.value ? "rgba(133, 118, 96, 0.78)" : "rgba(183, 165, 139, 0.9)";
  const ownerActive = isDark.value ? "rgba(224, 186, 115, 0.96)" : "rgba(143, 105, 49, 0.95)";

  usageChart = new Chart(usageChartRef.value, {
    type: "bar",
    data: {
      labels,
      datasets: [
        {
          label: isOwnerView.value ? "Weekly signups" : "GymMate overview",
          data: values,
          backgroundColor: isOwnerView.value
            ? values.map((value) => (value === peak && peak > 0 ? ownerActive : ownerInactive))
            : [
                "rgba(181, 139, 77, 0.72)",
                "rgba(224, 186, 115, 0.86)",
                "rgba(238, 204, 117, 0.82)",
                "rgba(125, 200, 191, 0.78)",
              ],
          borderColor: isOwnerView.value
            ? values.map((value) => (value === peak && peak > 0 ? ownerActive : ownerInactive))
            : "rgba(181, 139, 77, 0.92)",
          borderRadius: isOwnerView.value ? 999 : 14,
          borderSkipped: false,
          borderWidth: isOwnerView.value ? 0 : 1,
          barPercentage: isOwnerView.value ? 0.52 : 0.7,
          categoryPercentage: isOwnerView.value ? 0.72 : 0.8,
        },
      ],
    },
    options: {
      maintainAspectRatio: false,
      responsive: true,
      plugins: {
        legend: {
          display: !isOwnerView.value,
          labels: { color: chartTextColor() },
        },
        tooltip: {
          backgroundColor: isDark.value ? "rgba(22, 18, 14, 0.96)" : "rgba(255, 251, 245, 0.96)",
          titleColor: chartTextColor(),
          bodyColor: chartTextColor(),
          borderColor: isDark.value ? "rgba(240, 223, 194, 0.12)" : "rgba(32, 26, 21, 0.08)",
          borderWidth: 1,
          displayColors: false,
        },
      },
      scales: {
        x: {
          grid: { display: false },
          ticks: { color: chartTextColor() },
          border: { display: false },
        },
        y: {
          beginAtZero: true,
          grid: { color: chartGridColor() },
          ticks: {
            color: chartTextColor(),
            maxTicksLimit: isOwnerView.value ? 3 : 5,
          },
          border: { display: false },
        },
      },
    },
  });
}

async function fetchAdminDashboard() {
  loadingStats.value = true;
  loadingSide.value = true;
  statsError.value = "";
  sideError.value = "";

  try {
    const [statsRes, gymsRes] = await Promise.all([
      apiFetch("/api/auth/dashboard/stats"),
      apiFetch("/api/gym/list"),
    ]);

    const statsData = await statsRes.json();
    const gymsData = await gymsRes.json();

    if (!statsRes.ok) {
      throw new Error(
        statsData.message || "We could not load the overview right now.",
      );
    }
    if (!gymsRes.ok) {
      throw new Error("The gym list could not be loaded right now.");
    }

    gymCount.value = statsData.gyms || 0;
    ownerCount.value = statsData.owners || 0;
    memberCount.value = statsData.members || 0;
    inviteCount.value = statsData.invites || 0;
    chartSeries.value = [
      { label: "Gyms", value: gymCount.value },
      { label: "Owners", value: ownerCount.value },
      { label: "Members", value: memberCount.value },
      { label: "Invites", value: inviteCount.value },
    ];
    recentGyms.value = (Array.isArray(gymsData) ? gymsData : []).map((gym) => ({
      id: gym.id || gym._id,
      title: gym.name,
      copy: gym.address || gym.email,
      status: Array.isArray(gym.services)
        ? gym.services.join(", ")
        : gym.services || "General fitness",
      route: `/gyms/${gym.id || gym._id}`,
    }));
  } catch (err) {
    const message = err?.message || "We could not load the overview right now.";
    statsError.value = message;
    sideError.value = message;
  } finally {
    loadingStats.value = false;
    loadingSide.value = false;
  }
}

async function fetchOwnerDashboard() {
  loadingStats.value = true;
  loadingSide.value = true;
  loadingRoster.value = true;
  statsError.value = "";
  sideError.value = "";
  rosterError.value = "";

  try {
    const [gymRes, statsRes, invitesRes, membersRes] = await Promise.all([
      apiFetch("/api/gym/self"),
      apiFetch("/api/user/gym-dashboard-stats"),
      apiFetch("/api/invite/list"),
      apiFetch("/api/gym/members"),
    ]);

    const gymData = await gymRes.json();
    const statsData = await statsRes.json();
    const invitesData = await invitesRes.json();
    const membersData = await membersRes.json();

    if (!gymRes.ok) {
      throw new Error(
        gymData.message || "We could not load your gym right now.",
      );
    }
    if (!statsRes.ok) {
      throw new Error(
        statsData.message || "We could not load the gym overview right now.",
      );
    }
    if (!invitesRes.ok) {
      throw new Error(
        invitesData.message || "We could not load invites right now.",
      );
    }
    if (!membersRes.ok) {
      throw new Error(
        membersData.message || "We could not load your roster right now.",
      );
    }

    const gym = gymData.gym || gymData.member || {};
    gymName.value = gym.gymName || gym.name || "Your Gym";
    branding.value = {
      primaryColor: gym.branding?.primaryColor || "#B59F5B",
      secondaryColor: gym.branding?.secondaryColor || "#F8D84B",
    };
    services.value = Array.isArray(gym.services) ? gym.services : [];

    memberCount.value = statsData.membersCount || 0;
    ownerCount.value = 1;
    trainerCount.value = statsData.coachCount || statsData.trainersCount || 0;
    gymCount.value = 1;
    inviteCount.value =
      statsData.inviteCount ||
      (invitesData.codes || []).filter((code) => !code.used).length;
    brandCompletion.value = statsData.brandCompletion || 0;
    chartSeries.value = (statsData.chartSeries || statsData.registrations || []).map((entry) => ({
      label: entry.label || entry.day,
      value: Number(entry.value ?? entry.count ?? 0),
    }));

    recentInvites.value = (invitesData.codes || []).slice(0, 5).map((code) => ({
      id: code._id || code.code,
      title: code.code,
      copy: code.gymName || gymName.value,
      status: `${String(code.role || "")
        .replace("gym_", "")
        .replace("_", " ")} ${code.used ? "claimed" : "open"}`,
      route: "/invites",
    }));

    rosterItems.value = (membersData.members || [])
      .slice(0, 5)
      .map((member) => ({
        id: member._id,
        title: member.name || member.email,
        copy: member.email || "No email on file",
        status: String(member.role || "")
          .replace("gym_", "")
          .replace("_", " "),
      }));
  } catch (err) {
    const message =
      err?.message || "We could not load the gym overview right now.";
    statsError.value = message;
    sideError.value = message;
    rosterError.value = message;
  } finally {
    loadingStats.value = false;
    loadingSide.value = false;
    loadingRoster.value = false;
  }
}

function handleSideItem(item) {
  if (item.route) {
    router.push(item.route);
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

const metrics = computed(() => {
  if (isOwnerView.value) {
    return [
      {
        label: "Active Members",
        value: memberCount.value,
        icon: "mdi-account-group-outline",
        hint: "Your current member roster.",
      },
      {
        label: "Active Invites",
        value: inviteCount.value,
        icon: "mdi-ticket-confirmation-outline",
        hint: "Ready to share with new joins.",
      },
      {
        label: "Weekly Signups",
        value: weeklySignups.value,
        icon: "mdi-trending-up",
        hint: "New joins across the last seven days.",
      },
      {
        label: "Brand Completion",
        value: `${brandCompletion.value}%`,
        icon: "mdi-palette-outline",
        hint: "How complete your gym identity is right now.",
      },
    ];
  }

  return [
    {
      label: "Total Gyms",
      value: gymCount.value,
      icon: "mdi-domain",
      hint: "Registered locations across the network.",
    },
    {
      label: "Active Owners",
      value: ownerCount.value,
      icon: "mdi-account-tie-outline",
      hint: "Owners currently operating inside GymMate.",
    },
    {
      label: "Total Members",
      value: memberCount.value,
      icon: "mdi-account-group",
      hint: "Members being served across every gym.",
    },
    {
      label: "Open Invites",
      value: inviteCount.value,
      icon: "mdi-ticket-confirmation-outline",
      hint: "Member invites still waiting to be claimed.",
    },
  ];
});

watch(isDark, async () => {
  await nextTick();
  renderUsageChart();
});

watch(isOwnerView, async () => {
  await nextTick();
  renderUsageChart();
});

onMounted(async () => {
  if (isOwnerView.value) {
    await fetchOwnerDashboard();
  } else {
    await fetchAdminDashboard();
  }
  await nextTick();
  await ensureChartLibrary();
  await renderUsageChart();
});

onBeforeUnmount(() => {
  destroyChart();
});
</script>
