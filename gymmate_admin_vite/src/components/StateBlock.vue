<template>
  <div class="state-block admin-surface" :class="toneClass">
    <div class="state-block__icon"><v-icon :icon="icon" /></div>
    <div>
      <div class="state-block__title">{{ title }}</div>
      <div class="state-block__copy">{{ copy }}</div>
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
})

const toneClass = computed(() => `state-block--${props.tone}`)
</script>
