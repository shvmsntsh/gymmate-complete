<template>
  <div>
    <div class="section-header mb-6">
      <div>
        <div class="table-overline">Membership Requests</div>
        <h2 class="section-title">Request Queue</h2>
        <p class="section-copy">Review and process member requests.</p>
      </div>
    </div>

    <v-tabs v-model="statusTab" color="primary" class="mb-4">
      <v-tab value="all">All</v-tab>
      <v-tab value="submitted">Submitted</v-tab>
      <v-tab value="awaiting_payment">Awaiting Payment</v-tab>
      <v-tab value="payment_under_review">Payment Review</v-tab>
      <v-tab value="approved">Approved</v-tab>
      <v-tab value="rejected">Rejected</v-tab>
    </v-tabs>

    <v-card v-if="loading" class="pa-8" flat>
      <div class="d-flex justify-center">
        <v-progress-circular indeterminate color="primary" />
      </div>
    </v-card>

    <v-card v-else-if="filteredRequests.length === 0" class="pa-8" flat>
      <div class="text-center">
        <v-icon size="64" color="grey">mdi-clipboard-check</v-icon>
        <h3 class="text-h6 mt-4">No requests</h3>
        <p class="text-body-2 text-medium-emphasis mt-2">
          {{ statusTab === 'all' ? 'No membership requests yet.' : `No ${statusTab.replace('_', ' ')} requests.` }}
        </p>
      </div>
    </v-card>

    <div v-else class="requests-list">
      <v-card
        v-for="request in filteredRequests"
        :key="request.id"
        class="request-card mb-3"
        variant="outlined"
        rounded="xl"
        @click="$emit('view', request)"
      >
        <v-card-text class="pa-4">
          <div class="d-flex justify-space-between align-start">
            <div class="d-flex align-center gap-3">
              <v-avatar :color="requestTypeColor(request.requestType)" size="40">
                <v-icon>{{ requestTypeIcon(request.requestType) }}</v-icon>
              </v-avatar>
              <div>
                <div class="text-body-1 font-weight-medium">
                  {{ request.member?.name || 'Unknown Member' }}
                </div>
                <div class="text-caption text-medium-emphasis">
                  {{ request.member?.email }}
                </div>
              </div>
            </div>
            <v-chip :color="statusColor(request.status)" size="small" variant="tonal">
              {{ formatStatus(request.status) }}
            </v-chip>
          </div>

          <v-divider class="my-3" />

          <div class="d-flex justify-space-between align-center">
            <div>
              <div class="text-caption text-medium-emphasis">Request Type</div>
              <div class="text-body-2">{{ formatRequestType(request.requestType) }}</div>
            </div>
            <div v-if="request.targetPlan" class="text-right">
              <div class="text-caption text-medium-emphasis">Target Plan</div>
              <div class="text-body-2">{{ request.targetPlan.name }}</div>
            </div>
            <div v-if="request.paymentMode" class="text-right">
              <div class="text-caption text-medium-emphasis">Payment</div>
              <div class="text-body-2">{{ formatPaymentMode(request.paymentMode) }}</div>
              <div v-if="request.paymentReference" class="text-caption text-medium-emphasis">
                Ref: {{ request.paymentReference }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-caption text-medium-emphasis">Requested</div>
              <div class="text-body-2">{{ formatDate(request.requestedAt) }}</div>
            </div>
          </div>

          <div v-if="request.memberNote" class="mt-3 pa-2 bg-surface-variant rounded">
            <div class="text-caption text-medium-emphasis">Member Note</div>
            <div class="text-body-2">"{{ request.memberNote }}"</div>
          </div>
        </v-card-text>

        <v-card-actions v-if="canProcess(request.status)" class="pa-4 pt-0">
          <v-spacer />
          <v-btn
            v-if="['submitted', 'awaiting_payment'].includes(request.status)"
            size="small"
            variant="tonal"
            color="info"
            @click.stop="$emit('verify-payment', request.id)"
          >
            Verify Payment
          </v-btn>
          <v-btn
            v-if="canApprove(request)"
            size="small"
            color="primary"
            @click.stop="$emit('approve', request.id)"
          >
            Approve
          </v-btn>
          <v-btn
            v-if="canReject(request.status)"
            size="small"
            variant="outlined"
            color="error"
            @click.stop="$emit('reject', request.id)"
          >
            Reject
          </v-btn>
        </v-card-actions>
      </v-card>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from "vue";

const props = defineProps({
  requests: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(["verify-payment", "approve", "reject", "view"]);

const statusTab = ref("all");

const filteredRequests = computed(() => {
  if (statusTab.value === "all") return props.requests;
  return props.requests.filter((r) => r.status === statusTab.value);
});

function formatRequestType(type) {
  const map = {
    new_membership: "New Membership",
    renewal: "Renewal",
    upgrade: "Upgrade",
    downgrade: "Downgrade",
    freeze: "Freeze",
    cancel: "Cancel",
    add_on: "Add-on",
  };
  return map[type] || type;
}

function requestTypeIcon(type) {
  const icons = {
    new_membership: "mdi-account-plus",
    renewal: "mdi-refresh",
    upgrade: "mdi-arrow-up",
    downgrade: "mdi-arrow-down",
    freeze: "mdi-snowflake",
    cancel: "mdi-cancel",
    add_on: "mdi-plus-circle",
  };
  return icons[type] || "mdi-clipboard";
}

function requestTypeColor(type) {
  const colors = {
    new_membership: "primary",
    renewal: "info",
    upgrade: "success",
    downgrade: "warning",
    freeze: "blue",
    cancel: "error",
    add_on: "secondary",
  };
  return colors[type] || "grey";
}

function formatStatus(status) {
  const map = {
    submitted: "Submitted",
    awaiting_payment: "Awaiting Payment",
    payment_under_review: "Payment Review",
    approved: "Approved",
    rejected: "Rejected",
    canceled: "Canceled",
    expired: "Expired",
  };
  return map[status] || status;
}

function statusColor(status) {
  const colors = {
    submitted: "warning",
    awaiting_payment: "warning",
    payment_under_review: "info",
    approved: "success",
    rejected: "error",
    canceled: "grey",
    expired: "grey",
  };
  return colors[status] || "grey";
}

function formatDate(date) {
  if (!date) return "N/A";
  return new Date(date).toLocaleDateString("en-GB");
}

function formatPaymentMode(mode) {
  const map = {
    cash: "Cash",
    upi: "UPI",
    card: "Card",
    online: "Online",
    manual: "Manual",
    waived: "Waived",
  };
  return map[mode] || mode;
}

function canProcess(status) {
  return ["submitted", "awaiting_payment", "payment_under_review"].includes(status);
}

function canApprove(request) {
  if (!request) return false;
  if (request.status === "payment_under_review") return true;
  return ["submitted", "awaiting_payment"].includes(request.status) && request.paymentMode === "waived";
}

function canReject(status) {
  return canProcess(status);
}
</script>

<style scoped>
.section-header {
  margin-bottom: 24px;
}

.section-title {
  font-size: 1.5rem;
  font-weight: 600;
  margin-top: 4px;
}

.section-copy {
  color: rgba(255, 255, 255, 0.7);
  margin-top: 8px;
}

.table-overline {
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: rgb(var(--v-theme-primary));
}

.request-card {
  cursor: pointer;
  transition: transform 0.2s, box-shadow 0.2s;
}

.request-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
}

.gap-3 {
  gap: 12px;
}

.bg-surface-variant {
  background: rgba(255, 255, 255, 0.05);
}
</style>
