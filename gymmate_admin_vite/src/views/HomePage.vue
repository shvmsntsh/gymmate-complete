<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">GymMate For Gym Owners</div>
          <h1 class="display-headline">Run your gym with clarity and control.</h1>
          <p class="lead-copy">
            Keep your gym details, member activity, and daily operations in one clean dashboard.
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
        <img
          :src="heroImage"
          alt="Modern gym interior with strength and cardio equipment"
        />
        <div class="landing-media__caption">
          <div class="landing-media__caption-title">A gym owners actually recognize</div>
          <div class="landing-media__caption-copy">
            Bright, premium, and familiar enough to feel like a real studio instead of stock software.
          </div>
        </div>
      </div>

      <div>
        <div class="eyebrow">Owner Dashboard</div>
        <h2 class="section-title">Everything you need to run your gym.</h2>
        <p class="section-copy">
          Set up your gym, review members, and keep daily operations moving.
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
import PublicAuthShell from '../components/PublicAuthShell.vue'
import { useAdminTheme } from '../composables/useAdminTheme'

const { isDark, toggleTheme } = useAdminTheme()
const heroImage = `${import.meta.env.BASE_URL}images/login-hero-gym.jpg`
</script>
