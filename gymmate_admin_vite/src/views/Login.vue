<template>
  <v-app>
    <v-main>
      <v-container fluid class="fill-height pa-0">
        <v-row no-gutters class="fill-height align-stretch">
          <!-- Left Panel with Background Image -->
          <v-col cols="12" md="5" lg="4" class="d-none d-md-flex justify-center align-center pa-4">
            <v-img
              :src="isDark ? '/gymbghomepagedark.png' : '/gymbghomepagelight.png'"
              alt="Gym Background"
              class="rounded-lg"
              max-width="100%"
              height="100%"
              cover
            />
          </v-col>
          <!-- Right Panel for Login Form -->
          <v-col cols="12" md="7" lg="8" class="d-flex justify-center align-center pa-4 pa-md-10">
            <v-card elevation="8" class="pa-6" max-width="500" width="100%">
              <v-card-title class="text-h4 font-weight-bold text-center">Welcome Back</v-card-title>
              <v-card-subtitle class="text-subtitle-1 text-center mb-4">Sign in to manage your gym</v-card-subtitle>
              <v-form @submit.prevent="login" class="mt-4">
                <v-text-field v-model="form.email" label="Email" type="email" required></v-text-field>
                <v-text-field
                  v-model="form.password"
                  label="Password"
                  :type="showPassword ? 'text' : 'password'"
                  :append-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
                  @click:append="showPassword = !showPassword"
                  required
                />
                <v-btn type="submit" color="primary" class="mt-4" block>Login</v-btn>
              </v-form>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </v-main>

    <!-- Theme Toggle -->
    <v-btn icon class="ma-4 position-absolute" style="top: 0; right: 0;" @click="toggleTheme">
      <v-icon>{{ isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
    </v-btn>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">
      {{ snackbarText }}
    </v-snackbar>
  </v-app>
</template>

<script setup>
import { ref } from 'vue'
import { useTheme } from 'vuetify'

const form = ref({ email: '', password: '' })
const showPassword = ref(false)
const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref('')

function showMessage(message, color = 'success') {
  snackbarText.value = message
  snackbarColor.value = color
  snackbar.value = true
}

// Vuetify theme logic
const theme = useTheme()
const isDark = ref(window.matchMedia('(prefers-color-scheme: dark)').matches)

function toggleTheme () {
  isDark.value = !isDark.value
  theme.global.name.value = isDark.value ? 'dark' : 'light'
}

// System theme change detection
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
  isDark.value = e.matches
  theme.global.name.value = isDark.value ? 'dark' : 'light'
})
theme.global.name.value = isDark.value ? 'dark' : 'light'

async function login () {
  try {
    const res = await fetch('http://localhost:5050/api/gym/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form.value)
    })
    const data = await res.json()
    if (res.ok) {
      showMessage('Login successful!', 'success')
      window.localStorage.setItem('gymmate_token', data.token)
      window.localStorage.setItem('gymmate_email', form.value.email)
      window.location.href = '/admin-dashboard'
    } else {
      showMessage(data.message || 'Login failed', 'error')
    }
  } catch (err) {
    console.error(err)
    showMessage('Login failed', 'error')
  }
}
</script>