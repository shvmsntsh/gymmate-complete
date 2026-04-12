<template>
  <v-form @submit.prevent="handleSave">
    <v-alert v-if="formError" class="mb-4" type="error" variant="tonal">
      {{ formError }}
    </v-alert>

    <v-text-field v-model="form.name" label="Plan name" variant="outlined" class="mb-4" />

    <v-row class="mb-4">
      <v-col cols="12" md="4">
        <v-text-field
          v-model="form.durationDays"
          label="Duration days"
          inputmode="numeric"
          variant="outlined"
        />
      </v-col>
      <v-col cols="12" md="4">
        <v-text-field
          v-model="form.price"
          label="Price"
          prefix="₹"
          inputmode="decimal"
          variant="outlined"
        />
      </v-col>
      <v-col cols="12" md="4">
        <v-text-field
          v-model="form.renewalLeadDays"
          label="Renewal lead days"
          inputmode="numeric"
          variant="outlined"
        />
      </v-col>
    </v-row>

    <v-textarea
      v-model="form.shortDescription"
      label="Short description"
      variant="outlined"
      rows="2"
      class="mb-4"
    />

    <div class="text-subtitle-2 mb-2">Included features</div>
    <div class="feature-grid mb-4">
      <v-checkbox v-model="form.includedFeatures.gymAccess" label="Gym access" color="primary" hide-details />
      <v-checkbox v-model="form.includedFeatures.classAccess" label="Class access" color="primary" hide-details />
      <v-checkbox v-model="form.includedFeatures.trainerSupport" label="Trainer support" color="primary" hide-details />
      <v-checkbox v-model="form.includedFeatures.dietSupport" label="Diet support" color="primary" hide-details />
      <v-checkbox v-model="form.includedFeatures.biometricAccess" label="Biometric access" color="primary" hide-details />
      <v-checkbox v-model="form.includedFeatures.lockerAccess" label="Locker access" color="primary" hide-details />
    </div>

    <v-row class="mb-4">
      <v-col cols="12" sm="6">
        <v-switch v-model="form.active" label="Active" color="primary" inset />
      </v-col>
      <v-col cols="12" sm="6">
        <v-switch v-model="form.visibleToMembers" label="Visible to members" color="primary" inset />
      </v-col>
    </v-row>

    <v-expansion-panels class="mb-4" variant="accordion">
      <v-expansion-panel title="Advanced rules">
        <v-expansion-panel-text>
          <v-row>
            <v-col cols="12" md="6">
              <v-select v-model="form.category" label="Category" variant="outlined" :items="categoryOptions" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.joiningFee" label="Joining fee" prefix="₹" inputmode="decimal" variant="outlined" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.sortOrder" label="Sort order" inputmode="numeric" variant="outlined" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.upgradeRank" label="Upgrade rank" inputmode="numeric" variant="outlined" />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field v-model="form.includedFeatures.guestPasses" label="Guest passes" inputmode="numeric" variant="outlined" />
            </v-col>
          </v-row>

          <div class="text-subtitle-2 mb-2">Available add-ons</div>
          <v-row class="mb-2">
            <v-col cols="12" sm="6">
              <v-checkbox v-model="form.availableAddOns.personalTraining" label="Personal training" color="primary" hide-details />
            </v-col>
            <v-col cols="12" sm="6">
              <v-checkbox v-model="form.availableAddOns.dietPlan" label="Diet plan" color="primary" hide-details />
            </v-col>
          </v-row>

          <v-row>
            <v-col cols="12" md="4">
              <v-switch v-model="form.rules.canUpgrade" label="Can upgrade" color="primary" inset />
            </v-col>
            <v-col cols="12" md="4">
              <v-switch v-model="form.rules.canDowngrade" label="Can downgrade" color="primary" inset />
            </v-col>
            <v-col cols="12" md="4">
              <v-switch v-model="form.rules.canFreeze" label="Can freeze" color="primary" inset />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="form.rules.freezeLimitDays"
                label="Freeze limit days"
                inputmode="numeric"
                variant="outlined"
                :disabled="!form.rules.canFreeze"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.rules.prorationMode" label="Proration mode" variant="outlined" :items="prorationOptions" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.rules.prorationPolicy" label="Proration policy" variant="outlined" :items="prorationPolicyOptions" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.rules.overlapPolicy" label="Overlap policy" variant="outlined" :items="overlapPolicyOptions" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.rules.approvalTimingPolicy" label="Approval timing" variant="outlined" :items="approvalTimingOptions" />
            </v-col>
            <v-col cols="12" md="6">
              <v-select v-model="form.rules.freezePolicy" label="Freeze policy" variant="outlined" :items="freezePolicyOptions" />
            </v-col>
          </v-row>

          <v-switch v-model="form.rules.requiresOwnerApproval" label="Requires owner approval" color="primary" inset />
          <v-combobox
            v-model="form.rules.paymentModesAllowed"
            label="Allowed payment modes"
            variant="outlined"
            chips
            multiple
            :items="paymentModeOptions"
          />
        </v-expansion-panel-text>
      </v-expansion-panel>
    </v-expansion-panels>

    <div class="d-flex justify-end gap-2">
      <v-btn variant="text" @click="$emit('cancel')">Cancel</v-btn>
      <v-btn color="primary" type="submit" :loading="loading">
        {{ template ? "Update" : "Create" }} plan
      </v-btn>
    </div>
  </v-form>
</template>

<script setup>
import { ref, watch } from "vue";

const props = defineProps({
  template: { type: Object, default: null },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(["save", "cancel"]);

const categoryOptions = [
  { title: "Trial", value: "trial" },
  { title: "Monthly", value: "monthly" },
  { title: "Quarterly", value: "quarterly" },
  { title: "Yearly", value: "yearly" },
  { title: "Add-on", value: "add_on" },
];
const prorationOptions = [
  { title: "None", value: "none" },
  { title: "Credit remaining days", value: "credit_remaining_days" },
  { title: "Restart full term", value: "restart_full_term" },
];
const prorationPolicyOptions = [
  { title: "None", value: "none" },
  { title: "Credit remaining days", value: "credit_remaining_days" },
  { title: "Charge full amount", value: "charge_full_amount" },
];
const overlapPolicyOptions = [
  { title: "Warn + owner override", value: "warn_and_require_override" },
  { title: "Queue after current", value: "queue_after_current" },
  { title: "Replace immediately", value: "replace_immediately" },
  { title: "Allow overlap", value: "allow_overlap" },
];
const approvalTimingOptions = [
  { title: "By request type", value: "by_request_type" },
  { title: "Activate immediately", value: "activate_immediately" },
  { title: "Queue after current", value: "queue_after_current" },
];
const freezePolicyOptions = [
  { title: "Extend end date", value: "extend_end_date" },
  { title: "Manual only", value: "manual_only" },
  { title: "None", value: "none" },
];
const paymentModeOptions = ["cash", "upi", "card", "online", "manual"];

const defaultForm = {
  name: "",
  shortDescription: "",
  fullDescription: "",
  durationDays: "30",
  price: "0",
  joiningFee: "0",
  renewalLeadDays: "7",
  category: "monthly",
  sortOrder: "0",
  upgradeRank: "0",
  active: true,
  visibleToMembers: true,
  includedFeatures: {
    gymAccess: false,
    classAccess: false,
    trainerSupport: false,
    dietSupport: false,
    biometricAccess: false,
    lockerAccess: false,
    guestPasses: "0",
  },
  availableAddOns: {
    personalTraining: false,
    dietPlan: false,
  },
  rules: {
    canUpgrade: true,
    canDowngrade: false,
    canFreeze: false,
    freezeLimitDays: "0",
    requiresOwnerApproval: true,
    overlapPolicy: "warn_and_require_override",
    approvalTimingPolicy: "by_request_type",
    prorationMode: "none",
    prorationPolicy: "none",
    freezePolicy: "extend_end_date",
    manualOverridePolicy: "owner_only",
    paymentModesAllowed: ["cash", "upi", "card", "online", "manual"],
  },
};

const form = ref(structuredClone(defaultForm));
const formError = ref("");

function toTextNumber(value) {
  return String(value ?? "").replace(/[^0-9.-]/g, "").trim();
}

function toNumber(value, label, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  const cleaned = toTextNumber(value);
  const parsed = cleaned === "" ? 0 : Number(cleaned);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    throw new Error(`${label} must be between ${min} and ${max}.`);
  }
  return parsed;
}

function normalizeForm(input) {
  const next = structuredClone(input);
  next.name = next.name.trim();
  if (!next.name) throw new Error("Plan name is required.");
  next.durationDays = toNumber(next.durationDays, "Duration days", { min: 1, max: 730 });
  next.price = toNumber(next.price, "Price", { min: 0, max: 1000000 });
  next.joiningFee = toNumber(next.joiningFee, "Joining fee", { min: 0, max: 1000000 });
  next.renewalLeadDays = toNumber(next.renewalLeadDays, "Renewal lead days", { min: 0, max: 90 });
  next.sortOrder = toNumber(next.sortOrder, "Sort order", { min: -10000, max: 10000 });
  next.upgradeRank = toNumber(next.upgradeRank, "Upgrade rank", { min: -10000, max: 10000 });
  next.includedFeatures.guestPasses = toNumber(next.includedFeatures.guestPasses, "Guest passes", { min: 0, max: 365 });
  next.rules.freezeLimitDays = toNumber(next.rules.freezeLimitDays, "Freeze limit days", { min: 0, max: 365 });
  return next;
}

watch(
  () => props.template,
  (template) => {
    const merged = template
      ? {
          ...structuredClone(defaultForm),
          ...template,
          durationDays: String(template.durationDays ?? defaultForm.durationDays),
          price: String(template.price ?? defaultForm.price),
          joiningFee: String(template.joiningFee ?? defaultForm.joiningFee),
          renewalLeadDays: String(template.renewalLeadDays ?? defaultForm.renewalLeadDays),
          sortOrder: String(template.sortOrder ?? defaultForm.sortOrder),
          upgradeRank: String(template.upgradeRank ?? defaultForm.upgradeRank),
          includedFeatures: {
            ...structuredClone(defaultForm.includedFeatures),
            ...template.includedFeatures,
            guestPasses: String(template.includedFeatures?.guestPasses ?? defaultForm.includedFeatures.guestPasses),
          },
          availableAddOns: { ...structuredClone(defaultForm.availableAddOns), ...template.availableAddOns },
          rules: {
            ...structuredClone(defaultForm.rules),
            ...template.rules,
            freezeLimitDays: String(template.rules?.freezeLimitDays ?? defaultForm.rules.freezeLimitDays),
          },
        }
      : structuredClone(defaultForm);
    form.value = merged;
    formError.value = "";
  },
  { immediate: true },
);

function handleSave() {
  try {
    formError.value = "";
    emit("save", normalizeForm(form.value));
  } catch (error) {
    formError.value = error.message || "Check the plan fields.";
  }
}
</script>

<style scoped>
.gap-2 {
  gap: 8px;
}

.feature-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

@media (max-width: 680px) {
  .feature-grid {
    grid-template-columns: 1fr;
  }
}
</style>
