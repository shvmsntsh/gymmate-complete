<template>
  <div class="state-block admin-surface" :class="toneClass">
    <div class="state-block__icon"><v-icon :icon="icon" /></div>
    <div class="state-block__body">
      <div class="state-block__title">{{ title }}</div>
      <div class="state-block__copy">{{ copy }}</div>
      <div
        v-if="primaryCta || secondaryCta || $slots.actions"
        class="state-block__actions"
      >
        <slot name="actions">
          <v-btn
            v-if="primaryCta"
            color="primary"
            size="small"
            @click="$emit('primary')"
          >
            <v-icon v-if="primaryCtaIcon" start :icon="primaryCtaIcon" />
            {{ primaryCta }}
          </v-btn>
          <v-btn
            v-if="secondaryCta"
            size="small"
            variant="text"
            @click="$emit('secondary')"
          >
            {{ secondaryCta }}
          </v-btn>
        </slot>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  copy: {
    type: String,
    required: true,
  },
  icon: {
    type: String,
    default: 'mdi-information-outline',
  },
  title: {
    type: String,
    required: true,
  },
  tone: {
    type: String,
    default: 'neutral',
  },
  primaryCta: {
    type: String,
    default: '',
  },
  primaryCtaIcon: {
    type: String,
    default: '',
  },
  secondaryCta: {
    type: String,
    default: '',
  },
})

defineEmits(['primary', 'secondary'])

const toneClass = computed(() => `state-block--${props.tone}`)
</script>

<style scoped>
.state-block__body {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: 0;
}

.state-block__actions {
  display: flex;
  gap: 8px;
  margin-top: 10px;
  flex-wrap: wrap;
}
</style>
