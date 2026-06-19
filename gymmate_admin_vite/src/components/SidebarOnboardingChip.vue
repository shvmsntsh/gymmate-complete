<template>
  <div v-if="visible" class="sidebar-onboarding">
    <v-menu location="top end" :close-on-content-click="false">
      <template #activator="{ props: menuProps }">
        <button
          v-bind="menuProps"
          type="button"
          class="sidebar-onboarding__chip"
          :aria-label="`Setup ${completedCount} of ${totalCount} done`"
        >
          <v-icon icon="mdi-rocket-launch-outline" size="18" />
          <span class="sidebar-onboarding__label">
            <strong>Setup {{ completedCount }}/{{ totalCount }}</strong>
            <small>{{ nextStepTitle }}</small>
          </span>
          <span class="sidebar-onboarding__bar" aria-hidden="true">
            <span
              class="sidebar-onboarding__bar-fill"
              :style="{ width: progress + '%' }"
            />
          </span>
        </button>
      </template>

      <v-card class="sidebar-onboarding__menu" min-width="320" max-width="380">
        <v-card-title class="text-subtitle-1 pa-3 pb-1">
          Pilot setup
        </v-card-title>
        <v-card-text class="pa-3 pt-0">
          <div
            v-for="step in steps"
            :key="step.id"
            class="sidebar-onboarding__row"
            :class="{ 'sidebar-onboarding__row--done': step.done }"
            role="button"
            tabindex="0"
            @click="open(step)"
            @keydown.enter="open(step)"
          >
            <v-icon
              :icon="step.done ? 'mdi-check-circle' : 'mdi-circle-outline'"
              :color="step.done ? 'success' : 'primary'"
              size="20"
            />
            <div class="sidebar-onboarding__row-copy">
              <strong>{{ step.title }}</strong>
              <small>{{ step.copy }}</small>
            </div>
            <v-icon v-if="!step.done" icon="mdi-chevron-right" size="18" />
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-2">
          <v-btn size="small" variant="text" @click="dismiss">
            Hide for now
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-menu>
  </div>
</template>

<script setup>
import { computed } from "vue";
import { useRouter } from "vue-router";
import { canAccessAdminRoute, getAdminSession } from "../lib/api";
import { useOnboarding } from "../composables/useOnboarding";

const router = useRouter();
const onboarding = useOnboarding();

const session = computed(() => getAdminSession());
const allSteps = computed(() =>
  onboarding.steps.value.filter((step) =>
    canAccessAdminRoute(step.route, session.value),
  ),
);
const steps = allSteps;
const completedCount = computed(
  () => steps.value.filter((step) => step.done).length,
);
const totalCount = computed(() => steps.value.length);
const progress = computed(() =>
  totalCount.value ? Math.round((completedCount.value / totalCount.value) * 100) : 0,
);
const nextStepTitle = computed(
  () => steps.value.find((step) => !step.done)?.title || "All set",
);
const visible = computed(
  () =>
    onboarding.visible.value &&
    steps.value.length > 0 &&
    completedCount.value < totalCount.value,
);

function open(step) {
  if (step.done) return;
  router.push(step.to);
}

function dismiss() {
  onboarding.dismiss();
}
</script>

<style scoped>
.sidebar-onboarding {
  padding: 0 12px 8px;
}

.sidebar-onboarding__chip {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
  width: 100%;
  padding: 10px 12px;
  background: var(--gm-surface-muted);
  border: 1px solid var(--gm-border);
  border-radius: 12px;
  color: var(--gm-text);
  cursor: pointer;
  text-align: left;
  transition: border-color 160ms ease, transform 160ms ease;
}

.sidebar-onboarding__chip:hover {
  border-color: var(--gm-primary);
  transform: translateY(-1px);
}

.sidebar-onboarding__label {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.sidebar-onboarding__label strong {
  font-size: 0.85rem;
  font-family: "Manrope", sans-serif;
}

.sidebar-onboarding__label small {
  font-size: 0.72rem;
  color: var(--gm-text-soft);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sidebar-onboarding__bar {
  grid-column: 1 / -1;
  height: 4px;
  background: var(--gm-border);
  border-radius: 999px;
  overflow: hidden;
}

.sidebar-onboarding__bar-fill {
  display: block;
  height: 100%;
  background: var(--gm-primary);
  transition: width 200ms ease;
}

.sidebar-onboarding__menu {
  border-radius: 14px;
}

.sidebar-onboarding__row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 10px;
  align-items: center;
  padding: 10px;
  border-radius: 10px;
  cursor: pointer;
  transition: background 140ms ease;
}

.sidebar-onboarding__row:hover {
  background: rgba(var(--v-theme-primary), 0.06);
}

.sidebar-onboarding__row--done {
  cursor: default;
  opacity: 0.7;
}

.sidebar-onboarding__row--done:hover {
  background: transparent;
}

.sidebar-onboarding__row-copy strong {
  display: block;
  font-size: 0.9rem;
}

.sidebar-onboarding__row-copy small {
  display: block;
  font-size: 0.78rem;
  color: var(--gm-text-soft);
  line-height: 1.3;
  margin-top: 2px;
}

@media (max-width: 720px) {
  .sidebar-onboarding__label small {
    display: none;
  }
}
</style>
