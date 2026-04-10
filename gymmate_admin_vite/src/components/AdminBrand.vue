<template>
  <div class="admin-brand" :class="[toneClass, { 'admin-brand--compact': compact }]">
    <div
      v-if="!hideGlyph"
      class="admin-brand__glyph"
      :class="{
        'admin-brand__glyph--logo': showLogo,
        'admin-brand__glyph--mark': showMarkImage,
      }"
    >
      <img
        v-if="showLogo"
        :src="logoUrl"
        :alt="brandAlt"
        class="admin-brand__logo"
        @error="handleLogoError"
      />
      <img
        v-else-if="showMarkImage"
        :src="markImageUrl"
        :alt="`${displayName} mark`"
        class="admin-brand__logo"
        @error="handleMarkError"
      />
      <span v-else>GM</span>
    </div>
    <div class="admin-brand__copy">
      <img
        v-if="showWordmark"
        :src="wordmarkUrl"
        :alt="displayName"
        class="admin-brand__wordmark"
        @error="handleWordmarkError"
      />
      <template v-else>
        <div class="admin-brand__name">{{ displayName }}</div>
        <div class="admin-brand__tagline">Your Fitness HQ</div>
      </template>
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
  markImageUrl: {
    type: String,
    default: '',
  },
  hideGlyph: {
    type: Boolean,
    default: false,
  },
  tone: {
    type: String,
    default: 'default',
  },
  wordmarkUrl: {
    type: String,
    default: '',
  },
})

const logoFailed = ref(false)
const markFailed = ref(false)
const toneClass = computed(() => `admin-brand--${props.tone}`)
const displayName = computed(() => props.brandName?.trim() || 'GymMate')
const showLogo = computed(() => Boolean(props.logoUrl?.trim()) && !logoFailed.value)
const showMarkImage = computed(
  () => Boolean(props.markImageUrl?.trim()) && !markFailed.value,
)
const wordmarkFailed = ref(false)
const showWordmark = computed(
  () => Boolean(props.wordmarkUrl?.trim()) && !wordmarkFailed.value,
)
const brandAlt = computed(() => `${displayName.value} logo`)

watch(
  () => props.logoUrl,
  () => {
    logoFailed.value = false
  },
)

watch(
  () => props.markImageUrl,
  () => {
    markFailed.value = false
  },
)

watch(
  () => props.wordmarkUrl,
  () => {
    wordmarkFailed.value = false
  },
)

function handleLogoError() {
  logoFailed.value = true
}

function handleMarkError() {
  markFailed.value = true
}

function handleWordmarkError() {
  wordmarkFailed.value = true
}
</script>

<style scoped>
.admin-brand__glyph--logo {
  overflow: hidden;
  padding: 0;
}

.admin-brand__glyph--mark {
  background: rgba(255, 255, 255, 0.08);
}

.admin-brand__logo {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.admin-brand__wordmark {
  width: auto;
  height: 42px;
  max-width: 170px;
  object-fit: contain;
  display: block;
}

.admin-brand--compact .admin-brand__wordmark {
  height: 34px;
  max-width: 148px;
}
</style>
