<template>
  <div class="admin-brand" :class="[toneClass, { 'admin-brand--compact': compact }]">
    <div class="admin-brand__glyph">
      <span>GM</span>
    </div>
    <div class="admin-brand__copy">
      <div class="admin-brand__name">GymMate</div>
      <div class="admin-brand__tagline">Your Fitness HQ</div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  compact: {
    type: Boolean,
    default: false,
  },
  tone: {
    type: String,
    default: 'default',
  },
})

const toneClass = computed(() => `admin-brand--${props.tone}`)
</script>
