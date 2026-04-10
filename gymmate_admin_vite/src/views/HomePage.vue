<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">GymMate For Gym Owners</div>
          <h1 class="display-headline">Run your gym clearly.</h1>
          <p class="lead-copy">
            Members, plans, staff, and daily operations in one focused workspace.
          </p>
        </div>

        <div class="hero-metrics">
          <div class="hero-metric">
            <div class="hero-metric__value">Clear</div>
            <div class="hero-metric__label">Your gym, people, and setup in one view.</div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Simple</div>
            <div class="hero-metric__label">Fast login, invites, and member updates.</div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Ready</div>
            <div class="hero-metric__label">Built for real front-desk gym work.</div>
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
            Premium, familiar, and grounded in the kind of space owners run every day.
          </div>
        </div>
      </div>

      <div>
        <div class="eyebrow">Owner Dashboard</div>
        <h2 class="section-title">Everything you need to run your gym.</h2>
        <p class="section-copy">
          Set up the gym, manage members, and keep the front desk moving.
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
