<template>
  <div>
    <div class="section-header mb-6">
      <div class="d-flex justify-space-between align-center">
        <div>
          <div class="table-overline">Setup</div>
          <h2 class="section-title">Plans members can buy</h2>
          <p class="section-copy">Start with simple gym plans like Monthly, Quarterly, or PT Pass.</p>
        </div>
        <v-btn color="primary" @click="openCreate()">
          <v-icon start>mdi-plus</v-icon>
          Create plan
        </v-btn>
      </div>
    </div>

    <v-card v-if="loading" class="pa-8" flat>
      <div class="d-flex justify-center">
        <v-progress-circular indeterminate color="primary" />
      </div>
    </v-card>

    <v-card v-else-if="templates.length === 0" class="pa-8" flat>
      <div class="text-center">
        <v-icon size="64" color="primary">mdi-card-account-details-outline</v-icon>
        <h3 class="text-h6 mt-4">Create your first plan</h3>
        <p class="text-body-2 text-medium-emphasis mt-2 mb-6">
          Pick a starter to prefill the form, or start from scratch. Edit the price before saving.
        </p>
        <div class="starter-plans">
          <button
            v-for="starter in STARTER_PLANS"
            :key="starter.id"
            type="button"
            class="starter-plan"
            @click="openCreateWithPreset(starter)"
          >
            <strong>{{ starter.name }}</strong>
            <small>{{ starter.durationDays }} days</small>
            <span class="starter-plan__price">₹{{ Number(starter.price).toLocaleString('en-IN') }}</span>
          </button>
        </div>
        <v-btn variant="text" class="mt-4" @click="openCreate()">
          Start from scratch
        </v-btn>
      </div>
    </v-card>

    <div v-else class="plans-grid">
      <v-card
        v-for="template in templates"
        :key="template.id"
        class="plan-card"
        variant="outlined"
        rounded="xl"
      >
        <v-card-text class="pa-4">
          <div class="d-flex justify-space-between align-start mb-3">
            <div>
              <div class="d-flex align-center gap-2">
                <h3 class="text-h6">{{ template.name }}</h3>
                <v-chip
                  :color="template.active ? 'success' : 'grey'"
                  size="small"
                  variant="tonal"
                >
                  {{ template.active ? 'Active' : 'Archived' }}
                </v-chip>
              </div>
              <div class="text-overline text-medium-emphasis mt-1">
                {{ template.category }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-h5 text-primary">₹{{ template.price }}</div>
              <div class="text-caption text-medium-emphasis">
                {{ template.durationDays }} days
              </div>
            </div>
          </div>

          <p v-if="template.shortDescription" class="text-body-2 mb-4">
            {{ template.shortDescription }}
          </p>

          <div class="features-list mb-4">
            <div
              v-for="(value, key) in template.includedFeatures"
              :key="key"
              class="feature-item"
            >
              <v-icon
                :color="value ? 'success' : 'grey-lighten-1'"
                size="18"
              >
                {{ value ? 'mdi-check-circle' : 'mdi-circle-outline' }}
              </v-icon>
              <span :class="value ? '' : 'text-disabled'">
                {{ formatFeatureName(key) }}
              </span>
            </div>
          </div>

          <div class="d-flex justify-space-between align-center mt-4 pt-4 border-t">
            <v-chip size="small" variant="tonal">
              {{ template.visibleToMembers ? 'Visible to members' : 'Hidden' }}
            </v-chip>
            <div>
              <v-btn
                icon="mdi-pencil"
                size="small"
                variant="text"
                @click="openEditor(template)"
              />
              <v-btn
                icon="mdi-delete"
                size="small"
                variant="text"
                color="error"
                @click="$emit('delete', template.id)"
              />
            </div>
          </div>
        </v-card-text>
      </v-card>
    </div>

    <v-dialog v-model="showEditor" max-width="700" scrollable>
      <v-card rounded="xl">
        <v-card-title class="text-h6 pa-4">
          {{ editingTemplate ? 'Edit Plan' : 'Create plan' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <PlanEditorForm
            :template="editingTemplate"
            :initial-preset="pendingPreset"
            @save="handleSave"
            @cancel="showEditor = false"
          />
        </v-card-text>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
import { computed, ref, watch } from "vue";
import PlanEditorForm from "./PlanEditorForm.vue";

const props = defineProps({
  templates: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(["create", "update", "delete"]);

const showEditor = ref(false);
const editingTemplate = ref(null);
const pendingPreset = ref(null);

const STARTER_PLANS = [
  {
    id: "monthly",
    name: "Monthly",
    durationDays: 30,
    price: 1500,
    category: "monthly",
    shortDescription: "Monthly gym access.",
    renewalLeadDays: 7,
    includedFeatures: { gymAccess: true },
  },
  {
    id: "quarterly",
    name: "Quarterly",
    durationDays: 90,
    price: 4000,
    category: "quarterly",
    shortDescription: "Three months of gym access.",
    renewalLeadDays: 7,
    includedFeatures: { gymAccess: true },
  },
  {
    id: "half_yearly",
    name: "Half-yearly",
    durationDays: 180,
    price: 7000,
    category: "yearly",
    shortDescription: "Six months of gym access.",
    renewalLeadDays: 10,
    includedFeatures: { gymAccess: true },
  },
  {
    id: "yearly",
    name: "Annual",
    durationDays: 365,
    price: 12000,
    category: "yearly",
    shortDescription: "A year of gym access.",
    renewalLeadDays: 14,
    includedFeatures: { gymAccess: true },
  },
  {
    id: "pt_pass",
    name: "PT Pass",
    durationDays: 30,
    price: 500,
    category: "add_on",
    shortDescription: "Personal training add-on.",
    renewalLeadDays: 5,
    includedFeatures: { trainerSupport: true },
    availableAddOns: { personalTraining: true },
  },
];

watch(showEditor, (val) => {
  if (!val) {
    editingTemplate.value = null;
    pendingPreset.value = null;
  }
});

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

function handleSave(data) {
  if (editingTemplate.value) {
    emit("update", editingTemplate.value.id, data);
  } else {
    emit("create", data);
  }
  showEditor.value = false;
}

function openEditor(template) {
  editingTemplate.value = template;
  showEditor.value = true;
}

function openCreate() {
  editingTemplate.value = null;
  pendingPreset.value = null;
  showEditor.value = true;
}

function openCreateWithPreset(preset) {
  editingTemplate.value = null;
  pendingPreset.value = preset;
  showEditor.value = true;
}

defineExpose({ openEditor, openCreate, openCreateWithPreset });
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

.plans-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 16px;
}

.plan-card {
  transition: transform 0.2s, box-shadow 0.2s;
}

.plan-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}

.features-list {
  display: flex;
  flex-wrap: wrap;
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

.border-t {
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.gap-2 {
  gap: 8px;
}

.starter-plans {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 12px;
  max-width: 720px;
  margin: 0 auto;
}

.starter-plan {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 4px;
  padding: 14px;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.04);
  color: inherit;
  cursor: pointer;
  text-align: left;
  transition: border-color 160ms ease, transform 160ms ease;
}

.starter-plan:hover {
  border-color: rgb(var(--v-theme-primary));
  transform: translateY(-1px);
}

.starter-plan strong {
  font-size: 0.95rem;
}

.starter-plan small {
  font-size: 0.75rem;
  opacity: 0.7;
}

.starter-plan__price {
  margin-top: 4px;
  color: rgb(var(--v-theme-primary));
  font-weight: 600;
  font-size: 1.05rem;
}
</style>
