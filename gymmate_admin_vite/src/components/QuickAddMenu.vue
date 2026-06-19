<template>
  <v-menu v-if="visibleItems.length" location="bottom end">
    <template #activator="{ props: menuProps }">
      <v-btn
        v-bind="menuProps"
        color="primary"
        variant="tonal"
        class="quick-add__btn"
      >
        <v-icon start icon="mdi-plus-circle-outline" />
        Quick add
        <v-icon end icon="mdi-chevron-down" />
      </v-btn>
    </template>
    <v-list density="comfortable" min-width="240">
      <v-list-item
        v-for="item in visibleItems"
        :key="item.label"
        :prepend-icon="item.icon"
        :title="item.label"
        :subtitle="item.copy"
        @click="go(item)"
      />
    </v-list>
  </v-menu>
</template>

<script setup>
import { computed } from "vue";
import { useRouter } from "vue-router";
import { canAccessAdminRoute, getAdminSession } from "../lib/api";

const router = useRouter();
const session = computed(() => getAdminSession());

const items = [
  {
    label: "Add member",
    copy: "Send a member invite code",
    icon: "mdi-account-multiple-plus-outline",
    to: "/invites?role=gym_member&focus=create",
    route: "Invites",
  },
  {
    label: "Add staff",
    copy: "Create a front desk login",
    icon: "mdi-badge-account-horizontal-outline",
    to: "/staff?action=add-staff",
    route: "StaffWorkspace",
  },
  {
    label: "Record payment",
    copy: "Log cash or UPI collection",
    icon: "mdi-cash-register",
    to: "/payments?action=record-payment",
    route: "PaymentWorkspace",
  },
  {
    label: "Mark attendance",
    copy: "Manual check-in or check-out",
    icon: "mdi-calendar-check-outline",
    to: "/attendance?action=record-attendance",
    route: "AttendanceWorkspace",
  },
  {
    label: "Create plan",
    copy: "Add a Monthly, Quarterly or PT plan",
    icon: "mdi-card-account-details-outline",
    to: "/membership?tab=plans&action=create-plan",
    route: "MembershipOps",
  },
  {
    label: "Capture lead",
    copy: "Save a walk-in or phone enquiry",
    icon: "mdi-account-search-outline",
    to: "/crm?action=capture-lead",
    route: "CrmWorkspace",
  },
];

const visibleItems = computed(() =>
  items.filter((item) => canAccessAdminRoute(item.route, session.value)),
);

function go(item) {
  router.push(item.to);
}
</script>

<style scoped>
.quick-add__btn {
  font-weight: 600;
}
</style>
