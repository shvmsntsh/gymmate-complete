<template>
  <div class="stat-card admin-surface">
    <div class="stat-card__meta">
      <span class="stat-card__label">{{ label }}</span>
      <span class="stat-card__icon"><v-icon :icon="icon" /></span>
    </div>
    <div class="stat-card__value">{{ value }}</div>
    <div class="stat-card__hint">{{ hint }}</div>
  </div>
</template>

<script setup>
defineProps({
  hint: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: 'mdi-chart-box-outline',
  },
  label: {
    type: String,
    required: true,
  },
  value: {
    type: [String, Number],
    required: true,
  },
})
</script>
