<template>
  <div v-if="request" class="request-detail">
    <div class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Member</div>
      <div class="d-flex align-center gap-2 mt-1">
        <v-avatar size="40" color="primary">
          <span>{{ getInitials(request.member?.name) }}</span>
        </v-avatar>
        <div>
          <div class="text-body-1 font-weight-medium">{{ request.member?.name }}</div>
          <div class="text-caption text-medium-emphasis">{{ request.member?.email }}</div>
        </div>
      </div>
    </div>

    <div class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Request Info</div>
      <div class="info-grid mt-1">
        <div>
          <div class="text-caption text-medium-emphasis">Type</div>
          <div class="text-body-2">{{ formatRequestType(request.requestType) }}</div>
        </div>
        <div>
          <div class="text-caption text-medium-emphasis">Status</div>
          <v-chip :color="statusColor(request.status)" size="small" variant="tonal">
            {{ formatStatus(request.status) }}
          </v-chip>
        </div>
        <div>
          <div class="text-caption text-medium-emphasis">Requested</div>
          <div class="text-body-2">{{ formatDate(request.requestedAt) }}</div>
        </div>
        <div v-if="request.decidedAt">
          <div class="text-caption text-medium-emphasis">Processed</div>
          <div class="text-body-2">{{ formatDate(request.decidedAt) }}</div>
        </div>
        <div v-if="request.effectiveDate">
          <div class="text-caption text-medium-emphasis">Effective</div>
          <div class="text-body-2">{{ formatDate(request.effectiveDate) }}</div>
        </div>
      </div>
    </div>

    <div v-if="request.targetPlan" class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Target Plan</div>
      <v-card variant="tonal" class="mt-2 pa-3" rounded="lg">
        <div class="d-flex justify-space-between align-start">
          <div>
            <div class="text-body-1 font-weight-medium">{{ request.targetPlan.name }}</div>
            <div class="text-caption text-medium-emphasis">{{ request.targetPlan.shortDescription }}</div>
          </div>
          <div class="text-right">
            <div class="text-h6 text-primary">₹{{ request.targetPlan.price }}</div>
            <div class="text-caption">{{ request.targetPlan.durationDays }} days</div>
          </div>
        </div>
        <v-divider class="my-2" />
        <div class="features-grid">
          <div
            v-for="(value, key) in request.targetPlan.includedFeatures"
            :key="key"
            class="feature-item"
          >
            <v-icon :color="value ? 'success' : 'grey'" size="16">
              {{ value ? 'mdi-check' : 'mdi-close' }}
            </v-icon>
            <span :class="value ? '' : 'text-disabled'">{{ formatFeatureName(key) }}</span>
          </div>
        </div>
      </v-card>
    </div>

    <div v-if="currentMembership" class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Current Membership</div>
      <v-card variant="tonal" class="mt-2 pa-3" rounded="lg">
        <div class="d-flex justify-space-between align-start">
          <div>
            <div class="text-body-1 font-weight-medium">{{ currentMembership.templateName || 'No plan' }}</div>
            <v-chip :color="statusColor(currentMembership.status)" size="x-small" class="mt-1">
              {{ formatStatus(currentMembership.renewalState || currentMembership.status) }}
            </v-chip>
          </div>
          <div v-if="currentMembership.endDate" class="text-right">
            <div class="text-caption text-medium-emphasis">Expires</div>
            <div class="text-body-2">{{ formatDate(currentMembership.endDate) }}</div>
          </div>
        </div>
        <div v-if="currentMembership.nextRenewalDate || currentMembership.paymentReference" class="info-grid mt-3">
          <div v-if="currentMembership.nextRenewalDate">
            <div class="text-caption text-medium-emphasis">Next Renewal</div>
            <div class="text-body-2">{{ formatDate(currentMembership.nextRenewalDate) }}</div>
          </div>
          <div v-if="currentMembership.paymentReference">
            <div class="text-caption text-medium-emphasis">Payment Ref</div>
            <div class="text-body-2">{{ currentMembership.paymentReference }}</div>
          </div>
        </div>
      </v-card>
    </div>

    <div v-if="request.requestedAddOns && (request.requestedAddOns.personalTraining || request.requestedAddOns.dietPlan)" class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Requested Add-ons</div>
      <div class="d-flex gap-2 mt-1">
        <v-chip v-if="request.requestedAddOns.personalTraining" color="primary" variant="tonal" size="small">
          Personal Training
        </v-chip>
        <v-chip v-if="request.requestedAddOns.dietPlan" color="secondary" variant="tonal" size="small">
          Diet Plan
        </v-chip>
      </div>
    </div>

    <div v-if="request.paymentMode" class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Payment Info</div>
      <div class="info-grid mt-1">
        <div>
          <div class="text-caption text-medium-emphasis">Mode</div>
          <div class="text-body-2">{{ formatPaymentMode(request.paymentMode) }}</div>
        </div>
        <div v-if="request.paymentReference">
          <div class="text-caption text-medium-emphasis">Reference</div>
          <div class="text-body-2">{{ request.paymentReference }}</div>
        </div>
        <div v-if="request.paymentProofUrl">
          <div class="text-caption text-medium-emphasis">Proof</div>
          <v-btn
            :href="request.paymentProofUrl"
            target="_blank"
            rel="noopener noreferrer"
            size="small"
            variant="text"
            color="primary"
          >
            View Proof
          </v-btn>
        </div>
      </div>
    </div>

    <div v-if="decisionPreview" class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Decision Preview</div>
      <div class="info-grid mt-2">
        <div>
          <div class="text-caption text-medium-emphasis">Action</div>
          <div class="text-body-2">{{ formatAction(decisionPreview.action) }}</div>
        </div>
        <div>
          <div class="text-caption text-medium-emphasis">Payment Decision</div>
          <div class="text-body-2">{{ formatStatus(decisionPreview.paymentSummary?.paymentStatusDecision) }}</div>
        </div>
        <div v-if="decisionPreview.computedDates?.startDate">
          <div class="text-caption text-medium-emphasis">Computed Start</div>
          <div class="text-body-2">{{ formatDate(decisionPreview.computedDates.startDate) }}</div>
        </div>
        <div v-if="decisionPreview.computedDates?.endDate">
          <div class="text-caption text-medium-emphasis">Computed End</div>
          <div class="text-body-2">{{ formatDate(decisionPreview.computedDates.endDate) }}</div>
        </div>
        <div>
          <div class="text-caption text-medium-emphasis">Expected</div>
          <div class="text-body-2">₹{{ decisionPreview.paymentSummary?.expectedAmount || 0 }}</div>
        </div>
        <div>
          <div class="text-caption text-medium-emphasis">Credit / Paid / Remaining</div>
          <div class="text-body-2">
            ₹{{ decisionPreview.paymentSummary?.creditedAmount || 0 }}
            / ₹{{ decisionPreview.paymentSummary?.amountPaid || 0 }}
            / ₹{{ decisionPreview.paymentSummary?.remainingAmount || 0 }}
          </div>
        </div>
      </div>

      <div v-if="decisionPreview.warnings?.length" class="mt-3">
        <div class="text-caption text-medium-emphasis mb-2">Warnings</div>
        <v-alert
          v-for="warning in decisionPreview.warnings"
          :key="warning.code"
          type="warning"
          variant="tonal"
          density="comfortable"
          class="mb-2"
        >
          {{ warning.message }}
        </v-alert>
      </div>

      <div v-if="decisionPreview.blockers?.length" class="mt-3">
        <div class="text-caption text-medium-emphasis mb-2">Blocking Checks</div>
        <v-alert
          v-for="blocker in decisionPreview.blockers"
          :key="blocker.code"
          type="error"
          variant="tonal"
          density="comfortable"
          class="mb-2"
        >
          {{ blocker.message }}
        </v-alert>
      </div>
    </div>

    <div class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Request Payment History</div>
      <v-list
        v-if="requestPayments.length"
        lines="two"
        density="comfortable"
        class="bg-transparent px-0 mt-2"
      >
        <v-list-item v-for="payment in requestPayments" :key="payment.id" class="px-0">
          <template #prepend>
            <v-avatar color="primary" variant="tonal" size="34">
              <span class="text-caption">₹</span>
            </v-avatar>
          </template>
          <v-list-item-title>
            ₹{{ payment.amount }} via {{ formatPaymentMode(payment.mode) }}
          </v-list-item-title>
          <v-list-item-subtitle>
            {{ formatDateTime(payment.recordedAt) }}
            <span v-if="payment.reference"> • Ref {{ payment.reference }}</span>
            <span v-if="payment.recordedBy?.name"> • By {{ payment.recordedBy.name }}</span>
          </v-list-item-subtitle>
        </v-list-item>
      </v-list>
      <v-alert v-else type="info" variant="tonal" density="comfortable" class="mt-2">
        No recorded payments on this request yet.
      </v-alert>
    </div>

    <div v-if="currentMembership" class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Current Membership Payment History</div>
      <v-list
        v-if="membershipPayments.length"
        lines="two"
        density="comfortable"
        class="bg-transparent px-0 mt-2"
      >
        <v-list-item v-for="payment in membershipPayments" :key="payment.id" class="px-0">
          <template #prepend>
            <v-avatar color="secondary" variant="tonal" size="34">
              <span class="text-caption">₹</span>
            </v-avatar>
          </template>
          <v-list-item-title>
            ₹{{ payment.amount }} via {{ formatPaymentMode(payment.mode) }}
          </v-list-item-title>
          <v-list-item-subtitle>
            {{ formatDateTime(payment.recordedAt) }}
            <span v-if="payment.reference"> • Ref {{ payment.reference }}</span>
            <span v-if="payment.recordedBy?.name"> • By {{ payment.recordedBy.name }}</span>
          </v-list-item-subtitle>
        </v-list-item>
      </v-list>
      <v-alert v-else type="info" variant="tonal" density="comfortable" class="mt-2">
        No recorded payments on current membership yet.
      </v-alert>
    </div>

    <div v-if="request.memberNote" class="detail-section mb-4">
      <div class="text-overline text-medium-emphasis">Member Note</div>
      <v-card variant="outlined" class="mt-2 pa-3" rounded="lg">
        <div class="text-body-2 font-italic">"{{ request.memberNote }}"</div>
      </v-card>
    </div>

    <div v-if="request.adminNote" class="detail-section">
      <div class="text-overline text-medium-emphasis">Admin Response</div>
      <v-card variant="tonal" color="warning" class="mt-2 pa-3" rounded="lg">
        <div class="text-body-2">{{ request.adminNote }}</div>
      </v-card>
    </div>
  </div>
</template>

<script setup>
import { formatDateTimeUs, formatDateUs } from "../../lib/date";

const props = defineProps({
  request: { type: Object, default: null },
  currentMembership: { type: Object, default: null },
  requestPayments: { type: Array, default: () => [] },
  membershipPayments: { type: Array, default: () => [] },
  decisionPreview: { type: Object, default: null },
});

function getInitials(name) {
  if (!name) return "?";
  return name.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2);
}

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

function formatStatus(status) {
  const map = {
    submitted: "Submitted",
    awaiting_payment: "Awaiting Payment",
    payment_under_review: "Payment Review",
    pending_approval: "Pending Approval",
    pending_payment: "Pending Payment",
    unpaid: "Unpaid",
    paid: "Paid",
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
  return formatDateUs(date);
}

function formatDateTime(date) {
  return formatDateTimeUs(date);
}

function formatPaymentMode(mode) {
  const map = {
    cash: "Cash",
    upi: "UPI",
    waived: "Waived",
  };
  return map[mode] || mode;
}

function formatAction(action) {
  const map = {
    activate_now: "Activate Now",
    queue_after_current: "Queue After Current",
    freeze_extend: "Freeze + Extend",
    cancel_membership: "Cancel Membership",
    reject: "Reject",
    needs_override: "Needs Override",
  };
  return map[action] || action || "N/A";
}

function formatFeatureName(key) {
  const names = {
    gymAccess: "Gym Access",
    classAccess: "Class Access",
    trainerSupport: "Trainer Support",
    dietSupport: "Diet Support",
    biometricAccess: "Biometric Access",
    lockerAccess: "Locker Access",
    guestPasses: "Guest Passes",
  };
  return names[key] || key;
}
</script>

<style scoped>
.detail-section {
  padding: 12px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.detail-section:last-child {
  border-bottom: none;
}

.info-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
}

.feature-item {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 0.85rem;
}

.text-disabled {
  opacity: 0.5;
}

.gap-2 {
  gap: 8px;
}
</style>
