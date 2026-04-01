<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">Gym Registration</div>
          <h1 class="display-headline">Open your gym account and get ready to lead your floor.</h1>
          <p class="lead-copy">
            Add your gym details, contact information, and services so members and staff know exactly where home base is.
          </p>
        </div>

        <div class="hero-metrics">
          <div class="hero-metric">
            <div class="hero-metric__value">Fast</div>
            <div class="hero-metric__label">Get your gym profile created without extra steps.</div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Organized</div>
            <div class="hero-metric__label">Keep your address, contact details, and services together.</div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Professional</div>
            <div class="hero-metric__label">Start with a polished setup experience for your business.</div>
          </div>
        </div>
      </div>
    </template>

    <div class="stack">
      <div>
        <div class="eyebrow">Create A Gym</div>
        <h2 class="section-title">Register a new location</h2>
        <p class="section-copy">Fill in the essentials below to open your gym account.</p>
      </div>

      <v-form class="stack" @submit.prevent="submit">
        <div class="form-grid">
          <div>
            <div class="field-label">Gym Name</div>
            <v-text-field v-model="form.name" density="comfortable" hide-details="auto" variant="outlined" required />
          </div>

          <div>
            <div class="field-label">Email</div>
            <v-text-field v-model="form.email" density="comfortable" hide-details="auto" type="email" variant="outlined" required />
          </div>

          <div class="form-grid__full">
            <div class="field-label">Password</div>
            <v-text-field
              v-model="form.password"
              :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
              :type="showPassword ? 'text' : 'password'"
              density="comfortable"
              hide-details="auto"
              variant="outlined"
              @click:append-inner="showPassword = !showPassword"
              required
            />
          </div>

          <div class="form-grid__full">
            <div class="field-label">Address</div>
            <v-text-field v-model="form.address" density="comfortable" hide-details="auto" variant="outlined" />
          </div>

          <div>
            <div class="field-label">Contact Number</div>
            <v-text-field v-model="form.contactNumber" density="comfortable" hide-details="auto" variant="outlined" />
          </div>

          <div>
            <div class="field-label">Services (comma-separated)</div>
            <v-text-field v-model="form.services" density="comfortable" hide-details="auto" variant="outlined" />
          </div>
        </div>

        <div class="cta-row">
          <v-btn color="primary" size="large" type="submit" :loading="submitting">Register Gym</v-btn>
          <v-btn size="large" variant="tonal" @click="router.push('/login')">Already have an account? Login</v-btn>
        </div>
      </v-form>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">
      {{ snackbarText }}
    </v-snackbar>
  </PublicAuthShell>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import PublicAuthShell from '../components/PublicAuthShell.vue'
import { useAdminTheme } from '../composables/useAdminTheme'
import { apiFetch } from '../lib/api'

const router = useRouter()
const form = ref({
  name: '',
  email: '',
  password: '',
  address: '',
  contactNumber: '',
  services: '',
})
const showPassword = ref(false)
const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref('')
const submitting = ref(false)
const { isDark, toggleTheme } = useAdminTheme()

function showMessage(message, color = 'success') {
  snackbarText.value = message
  snackbarColor.value = color
  snackbar.value = true
}

async function submit() {
  submitting.value = true

  const payload = {
    gymName: form.value.name,
    email: form.value.email,
    password: form.value.password,
    address: form.value.address,
    contactNumber: form.value.contactNumber,
    phone: form.value.contactNumber,
    services: form.value.services
      .split(',')
      .map((service) => service.trim())
      .filter(Boolean),
  }

  try {
    const res = await apiFetch('/api/gym/register', {
      method: 'POST',
      body: JSON.stringify(payload),
      skipAuth: true,
    })
    const data = await res.json()
    if (res.ok) {
      form.value = {
        name: '',
        email: '',
        password: '',
        address: '',
        contactNumber: '',
        services: '',
      }
      showMessage(data.message || 'Gym and owner account are ready.', 'success')
      return
    }

    showMessage(data.message || 'Registration failed', 'error')
  } catch (err) {
    showMessage('Registration failed', 'error')
  } finally {
    submitting.value = false
  }
}
</script>
