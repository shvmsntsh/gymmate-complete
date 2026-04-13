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
        @click:row="(event, { item }) => openRequestDetail(item.raw || item)"
      >
        <template #item.member="{ item }">
          {{ (item.raw || item)?.member?.name || "Member" }}
        </template>
        <template #item.targetPlan="{ item }">
          {{ (item.raw || item)?.targetPlan?.name || "-" }}
        </template>
        <template #item.status="{ item }">
          <v-chip :color="statusColor((item.raw || item).status)" size="small" variant="tonal">
            {{ (item.raw || item).status }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="assignment-actions" @click.stop>
            <v-btn size="small" color="primary" variant="tonal" @click="updateRequest(item.raw || item, 'approved')">
              Approve
            </v-btn>
            <v-btn size="small" variant="text" @click="updateRequest(item.raw || item, 'rejected')">
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
      <v-select
        v-model="paymentForm.membershipRequestId"
        :items="pendingRequestOptions"
        item-title="label"
        item-value="value"
        label="Link to request (optional)"
        variant="outlined"
        clearable
        class="mt-2"
      />

      <div class="cta-row">
        <v-btn color="primary" :loading="savingPayment" @click="recordPayment">
          Record payment
        </v-btn>
      </div>
    </section>

    <v-dialog v-model="requestDialog" max-width="600">
      <v-card rounded="xl">
        <v-card-title class="dialog-title">Request Details</v-card-title>
        <v-card-text>
          <StateBlock
            v-if="requestError"
            title="Could not load request details"
            :copy="requestError"
            icon="mdi-alert-circle-outline"
            tone="error"
          />
          <div v-else-if="requestDetail">
            <div class="request-detail-grid">
              <div class="detail-field">
                <div class="detail-label">Member</div>
                <div class="detail-value">{{ requestDetail.member?.name || 'N/A' }}</div>
              </div>
              <div class="detail-field">
                <div class="detail-label">Email</div>
                <div class="detail-value">{{ requestDetail.member?.email || 'N/A' }}</div>
              </div>
              <div class="detail-field">
                <div class="detail-label">Request Type</div>
                <div class="detail-value">{{ requestDetail.requestType }}</div>
              </div>
              <div class="detail-field">
                <div class="detail-label">Status</div>
                <v-chip :color="statusColor(requestDetail.status)" size="small" variant="tonal">
                  {{ requestDetail.status }}
                </v-chip>
              </div>
              <div class="detail-field">
                <div class="detail-label">Created</div>
                <div class="detail-value">{{ formatDate(requestDetail.createdAt) }}</div>
              </div>
              <div class="detail-field" v-if="requestDetail.handledAt">
                <div class="detail-label">Processed</div>
                <div class="detail-value">{{ formatDate(requestDetail.handledAt) }}</div>
              </div>
            </div>

            <div v-if="requestDetail.targetPlan" class="plan-summary">
              <div class="plan-summary-title">Requested Plan</div>
              <div class="plan-summary-name">{{ requestDetail.targetPlan.name }}</div>
              <div v-if="requestDetail.targetPlan.description" class="plan-summary-desc">
                {{ requestDetail.targetPlan.description }}
              </div>
              <div class="plan-summary-meta">
                <span>{{ requestDetail.targetPlan.durationDays }} days</span>
                <span v-if="requestDetail.targetPlan.addOns?.training">+ Training</span>
                <span v-if="requestDetail.targetPlan.addOns?.diet">+ Diet</span>
              </div>
            </div>

            <div v-if="requestDetail.member?.id && memberCurrentMembership" class="current-membership">
              <div class="current-membership-title">Current Membership</div>
              <div class="current-membership-plan">
                {{ memberCurrentMembership.planName || 'No active plan' }}
              </div>
              <div class="current-membership-meta">
                Status: {{ memberCurrentMembership.status }}
                <span v-if="memberCurrentMembership.endDate">
                  | Expires: {{ formatDate(memberCurrentMembership.endDate) }}
                </span>
              </div>
            </div>

            <div v-if="requestDetail.note" class="member-note">
              <div class="member-note-label">Member's Note</div>
              <div class="member-note-text">{{ requestDetail.note }}</div>
            </div>

            <div v-if="requestDetail.response" class="staff-response">
              <div class="staff-response-label">Staff Response</div>
              <div class="staff-response-text">{{ requestDetail.response }}</div>
            </div>

            <v-textarea
              v-model="requestReply"
              label="Add reply / comment"
              variant="outlined"
              auto-grow
              rows="2"
              class="mt-4"
            />
          </div>
        </v-card-text>
        <v-card-actions class="dialog-actions">
          <v-spacer />
          <v-btn variant="text" @click="requestDialog = false">Close</v-btn>
          <v-btn
            v-if="requestDetail && requestDetail.status === 'pending'"
            variant="outlined"
            color="error"
            @click="processRequest('rejected')"
          >
            Reject
          </v-btn>
          <v-btn
            v-if="requestDetail && requestDetail.status === 'pending'"
            color="primary"
            :loading="processingRequest"
            @click="processRequest('approved')"
          >
            Approve
          </v-btn>
          <v-btn
            v-if="requestDetail && ['approved', 'payment_pending'].includes(requestDetail.status)"
            color="primary"
            :loading="processingRequest"
            @click="proceedToPayment"
          >
            Record Payment
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
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

const requestDialog = ref(false);
const requestDetail = ref(null);
const requestError = ref("");
const memberCurrentMembership = ref(null);
const requestReply = ref("");
const processingRequest = ref(false);
const selectedRequestId = ref("");

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
  membershipRequestId: null,
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

const pendingRequestOptions = computed(() =>
  requests.value
    .filter((r) => ['pending', 'approved', 'payment_pending'].includes(r.status))
    .map((r) => ({
      label: `${r.member?.name || 'Member'} - ${r.requestType} - ${r.targetPlan?.name || 'Plan'}`,
      value: r.id,
    })),
);

const paymentModes = [
  { title: "Cash", value: "cash" },
  { title: "UPI", value: "upi" },
  { title: "Card", value: "card" },
  { title: "Online", value: "online" },
  { title: "Manual", value: "manual" },
  { title: "Waived", value: "waived" },
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

async function openRequestDetail(request) {
  requestDialog.value = true;
  requestError.value = "";
  requestDetail.value = null;
  memberCurrentMembership.value = null;
  requestReply.value = "";
  selectedRequestId.value = request.id;

  try {
    const res = await apiFetch(`/api/owner/membership-requests/${request.id}`);
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not load request details.");
    requestDetail.value = data.request;
    memberCurrentMembership.value = data.memberMembership;
  } catch (err) {
    requestError.value = err?.message || "Could not load request details.";
  }
}

async function processRequest(status) {
  processingRequest.value = true;
  requestError.value = "";
  try {
    const res = await apiFetch(`/api/owner/membership-requests/${selectedRequestId.value}`, {
      method: "PATCH",
      body: JSON.stringify({
        status,
        response: requestReply.value,
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not process request.");
    requestDialog.value = false;
    await fetchData();
  } catch (err) {
    requestError.value = err?.message || "Could not process request.";
  } finally {
    processingRequest.value = false;
  }
}

function proceedToPayment() {
  if (!requestDetail.value?.member?.id) return;
  paymentForm.value.memberId = requestDetail.value.member.id;
  if (requestDetail.value.targetPlan) {
    paymentForm.value.reference = `${requestDetail.value.requestType}: ${requestDetail.value.targetPlan.name}`;
  }
  requestDialog.value = false;
}

function statusColor(status) {
  if (status === 'pending') return 'warning';
  if (status === 'approved') return 'success';
  if (status === 'rejected') return 'error';
  if (status === 'payment_pending') return 'info';
  if (status === 'activated') return 'success';
  return 'default';
}

function formatDate(value) {
  if (!value) return 'N/A';
  return new Date(value).toLocaleDateString('en-GB');
}

async function recordPayment() {
  savingPayment.value = true;
  error.value = "";
  try {
    const selectedMember = members.value.find((member) => member.id === paymentForm.value.memberId);
    const linkedRequest = requests.value.find((r) => r.id === paymentForm.value.membershipRequestId);
    const res = await apiFetch("/api/owner/payments", {
      method: "POST",
      body: JSON.stringify({
        memberId: paymentForm.value.memberId,
        membershipId: selectedMember?.membership?.id || null,
        membershipRequestId: paymentForm.value.membershipRequestId || null,
        amount: Number(paymentForm.value.amount),
        mode: paymentForm.value.mode,
        reference: paymentForm.value.reference,
        activate: true,
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not record payment.");
    paymentForm.value = {
      memberId: "",
      amount: "",
      mode: "cash",
      reference: "",
      membershipRequestId: null,
    };
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

.dialog-title {
  font-weight: 700;
}

.dialog-actions {
  padding: 0 24px 20px;
}

.request-detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 20px;
}

.detail-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.detail-label {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  opacity: 0.7;
}

.detail-value {
  font-weight: 500;
}

.plan-summary,
.current-membership {
  background: rgba(255, 255, 255, 0.04);
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 16px;
}

.plan-summary-title,
.current-membership-title {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  opacity: 0.7;
  margin-bottom: 8px;
}

.plan-summary-name,
.current-membership-plan {
  font-weight: 600;
  font-size: 16px;
}

.plan-summary-desc {
  margin-top: 6px;
  font-size: 14px;
  opacity: 0.85;
}

.plan-summary-meta,
.current-membership-meta {
  margin-top: 8px;
  font-size: 13px;
  opacity: 0.7;
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}

.member-note,
.staff-response {
  background: rgba(255, 255, 255, 0.04);
  border-radius: 12px;
  padding: 16px;
  margin-bottom: 16px;
}

.member-note-label {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  opacity: 0.7;
  margin-bottom: 8px;
}

.staff-response-label {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  opacity: 0.7;
  margin-bottom: 8px;
  color: rgba(201, 177, 92, 0.9);
}

.member-note-text,
.staff-response-text {
  font-size: 14px;
  line-height: 1.5;
}

.mt-4 {
  margin-top: 16px;
}

.mt-2 {
  margin-top: 8px;
}
</style>
