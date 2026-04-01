<template>
  <v-btn class="admin-theme-toggle" icon variant="text" @click="$emit('toggle')">
    <v-icon>{{ isDark ? 'mdi-white-balance-sunny' : 'mdi-weather-night' }}</v-icon>
  </v-btn>
</template>

<script setup>
defineProps({
  isDark: {
    type: Boolean,
    default: false,
  },
})

defineEmits(['toggle'])
</script>
