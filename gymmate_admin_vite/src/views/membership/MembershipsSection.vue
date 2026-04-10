<template>
  <div>
    <div class="section-header mb-6">
      <div class="d-flex justify-space-between align-center">
        <div>
          <div class="table-overline">Member Memberships</div>
          <h2 class="section-title">Manual Membership Desk</h2>
          <p class="section-copy">Take cash or UPI, renew plans, extend dates, freeze, unfreeze, and cancel from one place.</p>
        </div>
        <v-btn
          color="primary"
          variant="tonal"
          :disabled="assignableMemberCount === 0"
          @click="$emit('assign')"
        >
          <v-icon start>mdi-plus</v-icon>
          Assign New Plan
        </v-btn>
      </div>
    </div>

    <v-text-field
      v-model="search"
      prepend-inner-icon="mdi-magnify"
      label="Search members"
      variant="outlined"
      density="compact"
      class="mb-4"
      hide-details
      style="max-width: 300px"
    />

    <v-card v-if="loading" class="pa-8" flat>
      <div class="d-flex justify-center">
        <v-progress-circular indeterminate color="primary" />
      </div>
    </v-card>

    <v-card v-else-if="filteredMemberships.length === 0" class="pa-8" flat>
      <div class="text-center">
        <v-icon size="64" color="grey">mdi-account-group</v-icon>
        <h3 class="text-h6 mt-4">No memberships found</h3>
      </div>
    </v-card>

    <v-data-table
      v-else
      :headers="headers"
      :items="filteredMemberships"
      :search="search"
      class="membership-table"
      density="comfortable"
      hover
    >
      <template #item.member="{ item }">
        <div class="d-flex align-center gap-2">
          <v-avatar size="32" color="primary">
            <span class="text-body-2">{{ getInitials(item.member?.name) }}</span>
          </v-avatar>
          <div>
            <div class="text-body-2 font-weight-medium">{{ item.member?.name || 'Unknown' }}</div>
            <div class="text-caption text-medium-emphasis">{{ item.member?.email }}</div>
          </div>
        </div>
      </template>

      <template #item.template="{ item }">
        <div>
          <div class="text-body-2">{{ item.templateName || 'No plan' }}</div>
          <div class="text-caption text-medium-emphasis">{{ item.template?.category }}</div>
        </div>
      </template>

      <template #item.status="{ item }">
        <div class="d-flex flex-column ga-1">
          <v-chip :color="statusColor(item.renewalState || item.status)" size="small" variant="tonal">
            {{ formatStatus(item.renewalState || item.status) }}
          </v-chip>
          <div v-if="item.nextRenewalDate" class="text-caption text-medium-emphasis">
            Next: {{ formatDate(item.nextRenewalDate) }}
          </div>
        </div>
      </template>

      <template #item.paymentStatus="{ item }">
        <v-chip :color="paymentStatusColor(item.paymentStatus)" size="small" variant="outlined">
          {{ item.paymentStatus || 'none' }}
        </v-chip>
      </template>

      <template #item.dates="{ item }">
        <div class="text-body-2">
          <div v-if="item.startDate">Start: {{ formatDate(item.startDate) }}</div>
          <div v-if="item.endDate">End: {{ formatDate(item.endDate) }}</div>
          <div v-if="item.paymentReference" class="text-caption text-medium-emphasis">
            Ref: {{ item.paymentReference }}
          </div>
        </div>
      </template>

      <template #item.actions="{ item }">
        <div class="d-flex gap-1">
          <v-btn
            size="small"
            variant="text"
            color="primary"
            @click="$emit('view', item)"
          >
            Manage
          </v-btn>
          <v-btn
            v-if="item.isFrozen"
            size="small"
            variant="text"
            color="info"
            @click="$emit('unfreeze', item.id)"
          >
            Unfreeze
          </v-btn>
          <v-btn
            size="small"
            variant="text"
            :color="item.status === 'canceled' ? 'grey' : 'error'"
            :disabled="item.status === 'canceled'"
            @click="$emit('cancel', item.id, 'Canceled by admin')"
          >
            Cancel
          </v-btn>
        </div>
      </template>
    </v-data-table>
  </div>
</template>

<script setup>
import { computed, ref } from "vue";

const props = defineProps({
  memberships: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  members: { type: Array, default: () => [] },
  assignableMemberCount: { type: Number, default: 0 },
});

const emit = defineEmits(["unfreeze", "cancel", "assign", "view"]);

const search = ref("");

const headers = [
  { title: "Member", key: "member" },
  { title: "Plan", key: "template" },
  { title: "Status", key: "status" },
  { title: "Payment", key: "paymentStatus" },
  { title: "Dates", key: "dates" },
  { title: "Actions", key: "actions", sortable: false },
];

const filteredMemberships = computed(() => {
  return props.memberships.filter(m => m.member);
});

function getInitials(name) {
  if (!name) return "?";
  return name.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2);
}

function formatStatus(status) {
  const map = {
    pending_payment: "Pending Payment",
    pending_approval: "Pending Approval",
    active: "Active",
    renewal_due: "Renewal Due",
    scheduled: "Scheduled Next",
    frozen: "Frozen",
    expired: "Expired",
    canceled: "Canceled",
    rejected: "Rejected",
  };
  return map[status] || status;
}

function statusColor(status) {
  const colors = {
    pending_payment: "warning",
    pending_approval: "warning",
    active: "success",
    renewal_due: "info",
    scheduled: "info",
    expired: "error",
    frozen: "blue",
    canceled: "grey",
    rejected: "error",
  };
  return colors[status] || "grey";
}

function paymentStatusColor(status) {
  const colors = {
    unpaid: "error",
    payment_under_review: "warning",
    paid: "success",
    waived: "info",
  };
  return colors[status] || "grey";
}

function formatDate(date) {
  if (!date) return "N/A";
  return new Date(date).toLocaleDateString("en-GB");
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

.gap-1 {
  gap: 4px;
}

.gap-2 {
  gap: 8px;
}
</style>
