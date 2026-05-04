<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">GymMate for gym teams</div>
          <h1 class="display-headline">Simple admin for real gym work.</h1>
          <p class="lead-copy">
            A clean workspace for owners, staff, trainers, payments, attendance, and members.
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
      <div>
        <div class="eyebrow">Admin Portal</div>
        <h2 class="section-title">Choose where to start.</h2>
        <p class="section-copy">
          Sign in to manage an existing gym or register a new gym workspace.
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
</script>
