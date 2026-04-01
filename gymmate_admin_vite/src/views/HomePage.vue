<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">GymMate For Gym Owners</div>
          <h1 class="display-headline">Run your gym with more clarity, consistency, and control.</h1>
          <p class="lead-copy">
            Keep your gym details organized, review member activity, and manage day-to-day operations from one clean dashboard built for modern fitness businesses.
          </p>
        </div>

        <div class="hero-metrics">
          <div class="hero-metric">
            <div class="hero-metric__value">Clear</div>
            <div class="hero-metric__label">See your gym, members, and setup details in one place.</div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Simple</div>
            <div class="hero-metric__label">Easy access to login, gym registration, and team visibility.</div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Ready</div>
            <div class="hero-metric__label">Built to support growth as your gym operations expand.</div>
          </div>
        </div>
      </div>
    </template>

    <div class="stack">
      <div class="landing-media">
        <video autoplay muted loop playsinline :poster="posterImage">
          <source :src="`${assetBase}videos/gym_pool_cafe.mp4`" type="video/mp4" />
        </video>
      </div>

      <div>
        <div class="eyebrow">Owner Dashboard</div>
        <h2 class="section-title">Everything you need to stay on top of your gym.</h2>
        <p class="section-copy">
          From setting up your gym profile to reviewing members and activity, GymMate helps you manage the business side of fitness with less friction.
        </p>
      </div>

      <div class="cta-row">
        <v-btn color="primary" size="large" to="/login">Login</v-btn>
        <v-btn size="large" variant="tonal" to="/register-gym">Register Gym</v-btn>
      </div>
    </div>
  </PublicAuthShell>
</template>

<script setup>
import { computed } from 'vue'
import PublicAuthShell from '../components/PublicAuthShell.vue'
import { useAdminTheme } from '../composables/useAdminTheme'

const assetBase = import.meta.env.BASE_URL
const { isDark, toggleTheme } = useAdminTheme()

const posterImage = computed(() =>
  `${assetBase}${isDark.value ? 'images/gymbghomepagedark.png' : 'images/gymbghomepagelight.png'}`
)
</script>
