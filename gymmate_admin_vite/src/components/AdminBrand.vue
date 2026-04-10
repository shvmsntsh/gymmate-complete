<template>
  <div class="admin-brand" :class="[toneClass, { 'admin-brand--compact': compact }]">
    <div class="admin-brand__glyph" :class="{ 'admin-brand__glyph--logo': showLogo }">
      <img
        v-if="showLogo"
        :src="logoUrl"
        :alt="brandAlt"
        class="admin-brand__logo"
        @error="handleLogoError"
      />
      <span v-else>GM</span>
    </div>
    <div class="admin-brand__copy">
      <div class="admin-brand__name">{{ displayName }}</div>
      <div class="admin-brand__tagline">Your Fitness HQ</div>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'

const props = defineProps({
  brandName: {
    type: String,
    default: '',
  },
  compact: {
    type: Boolean,
    default: false,
  },
  logoUrl: {
    type: String,
    default: '',
  },
  tone: {
    type: String,
    default: 'default',
  },
})

const logoFailed = ref(false)
const toneClass = computed(() => `admin-brand--${props.tone}`)
const displayName = computed(() => props.brandName?.trim() || 'GymMate')
const showLogo = computed(() => Boolean(props.logoUrl?.trim()) && !logoFailed.value)
const brandAlt = computed(() => `${displayName.value} logo`)

watch(
  () => props.logoUrl,
  () => {
    logoFailed.value = false
  },
)

function handleLogoError() {
  logoFailed.value = true
}
</script>

<style scoped>
.admin-brand__glyph--logo {
  overflow: hidden;
  padding: 0;
}

.admin-brand__logo {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}
</style>
