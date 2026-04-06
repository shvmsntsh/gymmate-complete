<template>
  <AdminShell
    :is-dark="isDark"
    title="Membership"
    eyebrow="Plans, Requests, Payments"
    description="Manage plans, review member requests, and record offline payments."
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <section class="admin-surface admin-panel">
      <StateBlock
        v-if="error"
        title="Could not load membership operations"
        :copy="error"
        icon="mdi-alert-circle-outline"
        tone="error"
      />

      <div class="section-header">
        <div>
          <div class="table-overline">Plan Catalog</div>
          <h2 class="section-title">Membership plans</h2>
          <p class="section-copy">
            Owners can define the available plans. Staff can still process requests and payments.
          </p>
        </div>
      </div>

      <div v-if="isOwner" class="announcement-form-grid">
        <v-text-field v-model="planForm.name" label="Plan name" variant="outlined" />
        <v-text-field
          v-model="planForm.durationDays"
          type="number"
          label="Duration (days)"
          variant="outlined"
        />
        <v-text-field
          v-model="planForm.renewalLeadDays"
          type="number"
          label="Renewal lead days"
          variant="outlined"
        />
        <v-switch
          v-model="planForm.active"
          color="primary"
          label="Plan active"
          inset
        />
      </div>

      <v-textarea
        v-if="isOwner"
        v-model="planForm.description"
        label="Description"
        variant="outlined"
        auto-grow
        rows="2"
      />

      <v-combobox
        v-if="isOwner"
        v-model="planForm.includedServices"
        label="Included services"
        variant="outlined"
        chips
        multiple
      />

      <div v-if="isOwner" class="inline-switches">
        <v-switch v-model="planForm.addOns.training" color="primary" label="Paid training add-on" inset />
        <v-switch v-model="planForm.addOns.diet" color="primary" label="Paid diet add-on" inset />
      </div>

      <div v-if="isOwner" class="cta-row">
        <v-btn color="primary" :loading="savingPlan" @click="savePlan">Save plan</v-btn>
      </div>

      <v-data-table
        class="admin-table"
        :headers="planHeaders"
        :items="plans"
        density="comfortable"
      />

      <div class="section-header section-header--spaced">
        <div>
          <div class="table-overline">Request Queue</div>
          <h2 class="section-title">Member requests</h2>
        </div>
      </div>

      <v-data-table
        class="admin-table"
        :headers="requestHeaders"
        :items="requests"
        density="comfortable"
      >
        <template #item.member="{ item }">
          {{ item.raw?.member?.name || "Member" }}
        </template>
        <template #item.targetPlan="{ item }">
          {{ item.raw?.targetPlan?.name || "-" }}
        </template>
        <template #item.actions="{ item }">
          <div class="assignment-actions">
            <v-btn size="small" color="primary" variant="tonal" @click="updateRequest(item.raw, 'approved')">
              Approve
            </v-btn>
            <v-btn size="small" variant="text" @click="updateRequest(item.raw, 'rejected')">
              Reject
            </v-btn>
          </div>
        </template>
      </v-data-table>

      <div class="section-header section-header--spaced">
        <div>
          <div class="table-overline">Payment Entry</div>
          <h2 class="section-title">Record cash or UPI</h2>
        </div>
      </div>

      <div class="announcement-form-grid">
        <v-select
          v-model="paymentForm.memberId"
          :items="memberOptions"
          item-title="label"
          item-value="value"
          label="Member"
          variant="outlined"
        />
        <v-text-field v-model="paymentForm.amount" type="number" label="Amount" variant="outlined" />
        <v-select
          v-model="paymentForm.mode"
          :items="paymentModes"
          label="Mode"
          variant="outlined"
        />
        <v-text-field v-model="paymentForm.reference" label="Reference / note" variant="outlined" />
      </div>

      <div class="cta-row">
        <v-btn color="primary" :loading="savingPayment" @click="recordPayment">
          Record payment
        </v-btn>
      </div>
    </section>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch, clearAdminSession, getAdminRole } from "../lib/api";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();

const error = ref("");
const plans = ref([]);
const requests = ref([]);
const members = ref([]);
const savingPlan = ref(false);
const savingPayment = ref(false);
const role = computed(() => getAdminRole());
const isOwner = computed(() => role.value === "owner");

const planForm = ref({
  name: "",
  description: "",
  durationDays: 30,
  renewalLeadDays: 7,
  includedServices: [],
  active: true,
  addOns: { training: false, diet: false },
});

const paymentForm = ref({
  memberId: "",
  amount: "",
  mode: "cash",
  reference: "",
});

const planHeaders = [
  { title: "Plan", key: "name" },
  { title: "Duration", key: "durationDays" },
  { title: "Renewal Lead", key: "renewalLeadDays" },
  { title: "Active", key: "active" },
];

const requestHeaders = [
  { title: "Member", key: "member" },
  { title: "Type", key: "requestType" },
  { title: "Target Plan", key: "targetPlan" },
  { title: "Status", key: "status" },
  { title: "Actions", key: "actions", sortable: false },
];

const memberOptions = computed(() =>
  members.value.map((member) => ({
    label: `${member.name} (${member.email})`,
    value: member.id,
  })),
);

const paymentModes = [
  { title: "Cash", value: "cash" },
  { title: "UPI", value: "upi" },
];

function logout() {
  clearAdminSession();
  router.push("/login");
}

async function fetchData() {
  error.value = "";
  try {
    const [plansRes, requestsRes, membersRes] = await Promise.all([
      apiFetch("/api/owner/membership-plans"),
      apiFetch("/api/owner/membership-requests"),
      apiFetch("/api/owner/member-workspace?limit=50"),
    ]);
    const [plansData, requestsData, membersData] = await Promise.all([
      plansRes.json(),
      requestsRes.json(),
      membersRes.json(),
    ]);

    if (!plansRes.ok) throw new Error(plansData.message || "Could not load plans.");
    if (!requestsRes.ok) throw new Error(requestsData.message || "Could not load requests.");
    if (!membersRes.ok) throw new Error(membersData.message || "Could not load members.");

    plans.value = plansData.plans || [];
    requests.value = requestsData.requests || [];
    members.value = membersData.members || [];
  } catch (err) {
    error.value = err?.message || "Could not load membership operations.";
  }
}

async function savePlan() {
  savingPlan.value = true;
  error.value = "";
  try {
    const res = await apiFetch("/api/owner/membership-plans", {
      method: "POST",
      body: JSON.stringify(planForm.value),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not save plan.");
    planForm.value = {
      name: "",
      description: "",
      durationDays: 30,
      renewalLeadDays: 7,
      includedServices: [],
      active: true,
      addOns: { training: false, diet: false },
    };
    await fetchData();
  } catch (err) {
    error.value = err?.message || "Could not save plan.";
  } finally {
    savingPlan.value = false;
  }
}

async function updateRequest(request, status) {
  try {
    const res = await apiFetch(`/api/owner/membership-requests/${request.id}`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not update request.");
    await fetchData();
  } catch (err) {
    error.value = err?.message || "Could not update request.";
  }
}

async function recordPayment() {
  savingPayment.value = true;
  error.value = "";
  try {
    const selectedMember = members.value.find((member) => member.id === paymentForm.value.memberId);
    const res = await apiFetch("/api/owner/payments", {
      method: "POST",
      body: JSON.stringify({
        memberId: paymentForm.value.memberId,
        membershipId: selectedMember?.membership?.id || null,
        amount: Number(paymentForm.value.amount),
        mode: paymentForm.value.mode,
        reference: paymentForm.value.reference,
        activate: true,
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not record payment.");
    paymentForm.value = { memberId: "", amount: "", mode: "cash", reference: "" };
    await fetchData();
  } catch (err) {
    error.value = err?.message || "Could not record payment.";
  } finally {
    savingPayment.value = false;
  }
}

onMounted(fetchData);
</script>

<style scoped>
.announcement-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 12px;
}

.inline-switches {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.section-header--spaced {
  margin-top: 28px;
}

@media (max-width: 820px) {
  .announcement-form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
