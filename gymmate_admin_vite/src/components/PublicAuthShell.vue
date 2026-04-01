<template>
  <v-app :theme="isDark ? 'dark' : 'light'">
    <div class="public-shell">
      <div class="public-shell__bg public-shell__bg--primary"></div>
      <div class="public-shell__bg public-shell__bg--secondary"></div>

      <v-container class="public-shell__container">
        <header class="public-shell__nav">
          <button class="public-shell__home" type="button" @click="router.push('/')">
            <AdminBrand tone="light" compact />
          </button>

          <div class="public-shell__nav-actions">
            <v-btn class="admin-nav-link" variant="text" @click="router.push('/login')">Login</v-btn>
            <v-btn class="admin-nav-link" variant="text" @click="router.push('/register-gym')">Register Gym</v-btn>
            <AdminThemeToggle :is-dark="isDark" @toggle="emit('toggle-theme')" />
          </div>
        </header>

        <div class="public-shell__grid">
          <section class="public-shell__hero admin-surface admin-surface--hero">
            <div class="eyebrow">GymMate Admin</div>
            <slot name="hero">
              <h1 class="display-headline">A calmer, clearer way to run the business side of your gym.</h1>
              <p class="lead-copy">
                Keep your gym details, member visibility, and daily operations together in one easy place.
              </p>
            </slot>
            <slot name="hero-meta"></slot>
          </section>

          <section class="public-shell__panel admin-surface admin-surface--panel">
            <slot></slot>
          </section>
        </div>
      </v-container>
    </div>
  </v-app>
</template>

<script setup>
import { useRouter } from 'vue-router'
import AdminBrand from './AdminBrand.vue'
import AdminThemeToggle from './AdminThemeToggle.vue'

defineProps({
  isDark: {
    type: Boolean,
    default: false,
  },
})

const emit = defineEmits(['toggle-theme'])
const router = useRouter()
</script>
