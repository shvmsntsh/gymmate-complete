<template>
  <AdminShell
    :is-dark="isDark"
    :title="config.title"
    :eyebrow="config.eyebrow"
    :description="config.description"
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <StateBlock
      v-if="error"
      :title="`Could not load ${config.title}`"
      :copy="error"
      icon="mdi-alert-circle-outline"
      tone="error"
    />
    <StateBlock
      v-else-if="loading"
      :title="`Loading ${config.title}`"
      :copy="config.loadingCopy"
      icon="mdi-timer-sand"
    />
    <template v-else>
      <div class="workspace-band workspace-band--split">
        <section class="workspace-panel workspace-panel--wide">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">{{ config.primaryOverline }}</div>
              <h2 class="section-title">{{ config.primaryTitle }}</h2>
            </div>
            <v-btn variant="tonal" color="primary" @click="fetchData">
              <v-icon start icon="mdi-refresh" />
              Refresh
            </v-btn>
          </div>

          <div class="workspace-table-wrap">
            <table class="workspace-table">
              <thead>
                <tr>
                  <th v-for="column in config.columns" :key="column.key">
                    {{ column.label }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in tableRows" :key="row.id">
                  <td v-for="column in config.columns" :key="column.key">
                    <button
                      v-if="column.action"
                      type="button"
                      class="admin-table-link"
                      @click="selectRow(row)"
                    >
                      {{ displayCell(row, column) }}
                    </button>
                    <span v-else>{{ displayCell(row, column) }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <StateBlock
            v-if="tableRows.length === 0"
            :title="config.emptyTitle"
            :copy="config.emptyCopy"
            :icon="config.icon"
          />
        </section>

        <section class="workspace-panel">
          <div class="workspace-section-head">
            <div>
              <div class="table-overline">{{ config.formOverline }}</div>
              <h2 class="section-title">{{ config.formTitle }}</h2>
            </div>
          </div>

          <v-form class="workspace-form" @submit.prevent="submitForm">
            <template v-if="moduleKey === 'crm'">
              <v-text-field v-model="form.name" label="Name" density="comfortable" variant="outlined" hide-details="auto" />
              <v-text-field v-model="form.phone" label="Phone" density="comfortable" variant="outlined" hide-details="auto" />
              <v-text-field v-model="form.email" label="Email" density="comfortable" variant="outlined" hide-details="auto" />
              <v-select v-model="form.source" :items="leadSources" label="Source" density="comfortable" variant="outlined" hide-details="auto" />
              <v-text-field v-model="form.goal" label="Goal" density="comfortable" variant="outlined" hide-details="auto" />
              <v-text-field v-model="form.nextFollowUpAt" label="Next follow-up" type="datetime-local" density="comfortable" variant="outlined" hide-details="auto" />
            </template>

            <template v-else-if="moduleKey === 'payments'">
              <v-select v-model="form.memberId" :items="memberOptions" item-title="label" item-value="value" label="Member" density="comfortable" variant="outlined" hide-details="auto" />
              <v-text-field v-model="form.amount" label="Amount" type="number" density="comfortable" variant="outlined" hide-details="auto" />
              <v-select v-model="form.mode" :items="paymentModes" label="Mode" density="comfortable" variant="outlined" hide-details="auto" />
              <v-text-field v-model="form.reference" label="Reference" density="comfortable" variant="outlined" hide-details="auto" />
              <v-checkbox v-model="form.issueInvoice" label="Issue GST-ready invoice stub" density="compact" hide-details />
            </template>

            <template v-else-if="moduleKey === 'attendance'">
              <v-select v-model="form.memberId" :items="memberOptions" item-title="label" item-value="value" label="Member" density="comfortable" variant="outlined" hide-details="auto" />
              <v-select v-model="form.eventType" :items="attendanceTypes" label="Event" density="comfortable" variant="outlined" hide-details="auto" />
              <v-text-field v-model="form.note" label="Note" density="comfortable" variant="outlined" hide-details="auto" />
            </template>

            <template v-else-if="moduleKey === 'classes'">
              <v-select v-model="form.classAction" :items="classActions" item-title="label" item-value="value" label="Create" density="comfortable" variant="outlined" hide-details="auto" />
              <template v-if="form.classAction === 'template'">
                <v-text-field v-model="form.name" label="Class/PT name" density="comfortable" variant="outlined" hide-details="auto" />
                <v-select v-model="form.type" :items="classTypes" label="Type" density="comfortable" variant="outlined" hide-details="auto" />
                <v-select v-model="form.trainerId" :items="trainerOptions" item-title="label" item-value="value" label="Trainer" density="comfortable" variant="outlined" hide-details="auto" />
                <v-text-field v-model="form.defaultCapacity" label="Capacity" type="number" density="comfortable" variant="outlined" hide-details="auto" />
                <v-text-field v-model="form.durationMinutes" label="Minutes" type="number" density="comfortable" variant="outlined" hide-details="auto" />
              </template>
              <template v-else>
                <v-select v-model="form.templateId" :items="templateOptions" item-title="label" item-value="value" label="Template" density="comfortable" variant="outlined" hide-details="auto" />
                <v-select v-model="form.trainerId" :items="trainerOptions" item-title="label" item-value="value" label="Trainer override" density="comfortable" variant="outlined" hide-details="auto" />
                <v-text-field v-model="form.startsAt" label="Starts" type="datetime-local" density="comfortable" variant="outlined" hide-details="auto" />
                <v-text-field v-model="form.capacity" label="Capacity" type="number" density="comfortable" variant="outlined" hide-details="auto" />
                <v-text-field v-model="form.location" label="Location" density="comfortable" variant="outlined" hide-details="auto" />
              </template>
            </template>

            <template v-else-if="moduleKey === 'staff'">
              <v-select v-model="form.userId" :items="staffOptions" item-title="label" item-value="value" label="Staff member" density="comfortable" variant="outlined" hide-details="auto" />
              <v-select v-model="form.preset" :items="presetOptions" item-title="label" item-value="value" label="Preset" density="comfortable" variant="outlined" hide-details="auto" />
              <div class="workspace-checks">
                <v-checkbox
                  v-for="permission in availablePermissions"
                  :key="permission"
                  v-model="selectedCapabilities"
                  :label="permission"
                  :value="permission"
                  density="compact"
                  hide-details
                />
              </div>
            </template>

            <template v-else>
              <StateBlock
                title="Read-only workspace"
                copy="Open a member row for more detail, or use existing membership actions from the Membership module."
                :icon="config.icon"
              />
            </template>

            <v-alert v-if="formError" type="error" variant="tonal">{{ formError }}</v-alert>
            <v-alert v-if="formMessage" type="success" variant="tonal">{{ formMessage }}</v-alert>

            <v-btn
              v-if="config.canSubmit"
              color="primary"
              type="submit"
              :loading="submitting"
            >
              <v-icon start :icon="config.submitIcon" />
              {{ config.submitLabel }}
            </v-btn>
          </v-form>
        </section>
      </div>

      <section v-if="selectedRow" class="workspace-panel workspace-detail">
        <div class="workspace-section-head">
          <div>
            <div class="table-overline">Selected Record</div>
            <h2 class="section-title">{{ selectedTitle }}</h2>
          </div>
          <v-btn icon="mdi-close" variant="text" @click="selectedRow = null" />
        </div>
        <pre class="workspace-json">{{ JSON.stringify(selectedRow, null, 2) }}</pre>
      </section>
    </template>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, reactive, ref, watch } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import { apiFetch, clearAdminSession } from "../lib/api";
import { formatDateTimeUs } from "../lib/date";
import { useAdminTheme } from "../composables/useAdminTheme";

const props = defineProps({
  moduleKey: {
    type: String,
    required: true,
  },
});

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const loading = ref(true);
const submitting = ref(false);
const error = ref("");
const formError = ref("");
const formMessage = ref("");
const selectedRow = ref(null);
const data = ref({});
const selectedCapabilities = ref([]);
const form = reactive({});

const leadSources = ["walk_in", "website", "whatsapp", "instagram", "facebook", "referral", "campaign", "manual", "other"];
const paymentModes = ["cash", "upi", "card", "online", "manual", "waived"];
const attendanceTypes = ["check_in", "check_out"];
const classTypes = ["group_class", "personal_training", "workshop", "assessment"];
const classActions = [
  { label: "Class/PT template", value: "template" },
  { label: "Dated session", value: "session" },
];
const availablePermissions = [
  "workspace.access",
  "members.view",
  "members.manage",
  "leads.manage",
  "billing.manage",
  "payments.manage",
  "attendance.manage",
  "classes.manage",
  "reports.view",
  "campaigns.manage",
  "announcements.manage",
  "staff.manage",
];

const configs = {
  crm: {
    title: "CRM",
    eyebrow: "Leads and Trials",
    description: "Capture enquiries, follow up, and convert prospects into members.",
    loadingCopy: "Loading leads and follow-up queue.",
    primaryOverline: "Pipeline",
    primaryTitle: "Lead queue",
    formOverline: "New lead",
    formTitle: "Capture enquiry",
    icon: "mdi-account-search-outline",
    endpoint: "/api/workspace/leads",
    rowsKey: "leads",
    canSubmit: true,
    submitLabel: "Create lead",
    submitIcon: "mdi-plus",
    emptyTitle: "No leads yet",
    emptyCopy: "New enquiries will appear here once captured.",
    columns: [
      { key: "name", label: "Name", action: true },
      { key: "status", label: "Status" },
      { key: "source", label: "Source" },
      { key: "phone", label: "Phone" },
      { key: "nextFollowUpAt", label: "Follow-up", type: "date" },
    ],
  },
  members: {
    title: "Members",
    eyebrow: "Member 360",
    description: "Scan membership, trainer, payment, and attendance status from one workspace.",
    loadingCopy: "Loading active member records.",
    primaryOverline: "Roster",
    primaryTitle: "Member operating view",
    formOverline: "Actions",
    formTitle: "Member detail",
    icon: "mdi-account-group-outline",
    endpoint: "/api/workspace/members",
    rowsKey: "members",
    canSubmit: false,
    emptyTitle: "No members found",
    emptyCopy: "Members will appear here after invite or registration.",
    columns: [
      { key: "name", label: "Member", action: true },
      { key: "membership.plan.name", label: "Plan" },
      { key: "membership.status", label: "Membership" },
      { key: "totalPaid", label: "Paid", type: "money" },
      { key: "lastCheckInAt", label: "Last check-in", type: "date" },
      { key: "trainer.name", label: "Trainer" },
    ],
  },
  payments: {
    title: "Payments",
    eyebrow: "Billing Desk",
    description: "Record collections, filter payment modes, and prepare invoice metadata.",
    loadingCopy: "Loading payment ledger.",
    primaryOverline: "Ledger",
    primaryTitle: "Recent payments",
    formOverline: "Record",
    formTitle: "Manual payment",
    icon: "mdi-cash-register",
    endpoint: "/api/workspace/payments",
    rowsKey: "payments",
    canSubmit: true,
    submitLabel: "Record payment",
    submitIcon: "mdi-cash-plus",
    emptyTitle: "No payments yet",
    emptyCopy: "Manual and membership payments will appear here.",
    columns: [
      { key: "member.name", label: "Member", action: true },
      { key: "amount", label: "Amount", type: "money" },
      { key: "mode", label: "Mode" },
      { key: "reference", label: "Reference" },
      { key: "recordedAt", label: "Recorded", type: "date" },
    ],
  },
  attendance: {
    title: "Attendance",
    eyebrow: "Check-ins",
    description: "Track manual and biometric attendance with duplicate check-in handling.",
    loadingCopy: "Loading attendance events.",
    primaryOverline: "Today",
    primaryTitle: "Attendance events",
    formOverline: "Record",
    formTitle: "Manual check-in/out",
    icon: "mdi-calendar-check-outline",
    endpoint: "/api/workspace/attendance",
    rowsKey: "events",
    canSubmit: true,
    submitLabel: "Record attendance",
    submitIcon: "mdi-calendar-plus",
    emptyTitle: "No attendance yet",
    emptyCopy: "Today’s check-ins and check-outs will appear here.",
    columns: [
      { key: "member.name", label: "Member", action: true },
      { key: "eventType", label: "Event" },
      { key: "source", label: "Source" },
      { key: "occurredAt", label: "Time", type: "date" },
    ],
  },
  classes: {
    title: "Classes/PT",
    eyebrow: "Schedule",
    description: "Manage group classes, PT offerings, capacity, and booking rosters.",
    loadingCopy: "Loading class catalog and upcoming sessions.",
    primaryOverline: "Upcoming",
    primaryTitle: "Sessions",
    formOverline: "Catalog",
    formTitle: "Create class/PT template",
    icon: "mdi-calendar-clock",
    endpoint: "/api/workspace/classes",
    rowsKey: "sessions",
    canSubmit: true,
    submitLabel: "Create template",
    submitIcon: "mdi-calendar-plus",
    emptyTitle: "No sessions yet",
    emptyCopy: "Create templates first, then add sessions from the API or next UI slice.",
    columns: [
      { key: "template.name", label: "Session", action: true },
      { key: "trainer.name", label: "Trainer" },
      { key: "startsAt", label: "Starts", type: "date" },
      { key: "bookedCount", label: "Booked" },
      { key: "capacity", label: "Capacity" },
      { key: "status", label: "Status" },
    ],
  },
  staff: {
    title: "Staff",
    eyebrow: "Roles and Permissions",
    description: "Review trainers and staff, then apply operational permission presets.",
    loadingCopy: "Loading staff, trainers, and recent activity.",
    primaryOverline: "Team",
    primaryTitle: "Workspace access",
    formOverline: "Permissions",
    formTitle: "Apply preset",
    icon: "mdi-badge-account-horizontal-outline",
    endpoint: "/api/workspace/staff",
    rowsKey: "staff",
    canSubmit: true,
    submitLabel: "Update permissions",
    submitIcon: "mdi-shield-check-outline",
    emptyTitle: "No staff found",
    emptyCopy: "Staff and trainers will appear here after invite registration.",
    columns: [
      { key: "name", label: "Name", action: true },
      { key: "role", label: "Role" },
      { key: "email", label: "Email" },
      { key: "clientCount", label: "Clients" },
      { key: "accountStatus", label: "Status" },
    ],
  },
};

const config = computed(() => configs[props.moduleKey] || configs.members);
const moduleKey = computed(() => props.moduleKey);
const tableRows = computed(() => data.value[config.value.rowsKey] || []);
const memberOptions = computed(() =>
  (data.value.members || []).map((member) => ({
    label: `${member.name} (${member.phone || member.email || "member"})`,
    value: member.id,
  })),
);
const trainerOptions = computed(() =>
  (data.value.staff || [])
    .filter((user) => String(user.role || "").includes("trainer"))
    .map((user) => ({ label: user.name, value: user.id })),
);
const templateOptions = computed(() =>
  (data.value.templates || []).map((template) => ({
    label: `${template.name} · ${template.type}`,
    value: template.id,
  })),
);
const staffOptions = computed(() =>
  (data.value.staff || []).map((user) => ({ label: `${user.name} · ${user.role}`, value: user.id })),
);
const presetOptions = computed(() =>
  Object.keys(data.value.presets || {}).map((key) => ({
    label: key.replace("_", " "),
    value: key,
  })),
);
const selectedTitle = computed(() => selectedRow.value?.name || selectedRow.value?.member?.name || selectedRow.value?.template?.name || "Record detail");

watch(
  () => props.moduleKey,
  () => {
    resetForm();
    selectedRow.value = null;
    fetchData();
  },
);

watch(
  () => form.preset,
  (preset) => {
    selectedCapabilities.value = [...(data.value.presets?.[preset] || [])];
  },
);

function getValue(row, key) {
  return key.split(".").reduce((acc, part) => (acc ? acc[part] : undefined), row);
}

function displayCell(row, column) {
  const value = getValue(row, column.key);
  if (column.type === "date") return formatDateTimeUs(value);
  if (column.type === "money") return money(value);
  if (value === null || value === undefined || value === "") return "N/A";
  return value;
}

function money(value) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(Number(value || 0));
}

async function fetchSupportingMembers() {
  if (["payments", "attendance"].includes(moduleKey.value)) {
    const res = await apiFetch("/api/workspace/members");
    const payload = await res.json();
    if (res.ok) {
      data.value = { ...data.value, members: payload.members || [] };
    }
  }
  if (moduleKey.value === "classes") {
    const res = await apiFetch("/api/workspace/staff");
    const payload = await res.json();
    if (res.ok) {
      data.value = { ...data.value, staff: payload.staff || [] };
    }
  }
}

async function fetchData() {
  loading.value = true;
  error.value = "";
  try {
    const res = await apiFetch(config.value.endpoint);
    const payload = await res.json();
    if (!res.ok) {
      throw new Error(payload.message || `Could not load ${config.value.title}.`);
    }
    data.value = payload;
    await fetchSupportingMembers();
  } catch (err) {
    error.value = err?.message || `Could not load ${config.value.title}.`;
  } finally {
    loading.value = false;
  }
}

function resetForm() {
  Object.keys(form).forEach((key) => delete form[key]);
  form.source = "manual";
  form.mode = "cash";
  form.eventType = "check_in";
  form.type = "group_class";
  form.classAction = "template";
  form.defaultCapacity = 10;
  form.durationMinutes = 60;
  form.capacity = 10;
  selectedCapabilities.value = [];
  formError.value = "";
  formMessage.value = "";
}

async function selectRow(row) {
  if (moduleKey.value === "members") {
    selectedRow.value = row;
    try {
      const res = await apiFetch(`/api/workspace/members/${row.id}`);
      const payload = await res.json();
      selectedRow.value = res.ok ? payload : row;
    } catch {
      selectedRow.value = row;
    }
    return;
  }
  selectedRow.value = row;
}

function payloadForSubmit() {
  if (moduleKey.value === "staff") {
    return {
      staffCapabilities: Object.fromEntries(availablePermissions.map((permission) => [permission, selectedCapabilities.value.includes(permission)])),
    };
  }
  return { ...form };
}

function submitUrl() {
  if (moduleKey.value === "staff") {
    return `/api/workspace/staff/${form.userId}/capabilities`;
  }
  return {
    crm: "/api/workspace/leads",
    payments: "/api/workspace/payments",
    attendance: "/api/workspace/attendance",
    classes: form.classAction === "session" ? "/api/workspace/classes/sessions" : "/api/workspace/classes/templates",
  }[moduleKey.value];
}

async function submitForm() {
  formError.value = "";
  formMessage.value = "";
  submitting.value = true;
  try {
    const url = submitUrl();
    if (!url) return;
    const res = await apiFetch(url, {
      method: moduleKey.value === "staff" ? "PATCH" : "POST",
      body: JSON.stringify(payloadForSubmit()),
    });
    const payload = await res.json();
    if (!res.ok) {
      throw new Error(payload.message || "Could not save workspace change.");
    }
    formMessage.value = "Saved.";
    resetForm();
    await fetchData();
  } catch (err) {
    formError.value = err?.message || "Could not save workspace change.";
  } finally {
    submitting.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

resetForm();
onMounted(fetchData);
</script>
