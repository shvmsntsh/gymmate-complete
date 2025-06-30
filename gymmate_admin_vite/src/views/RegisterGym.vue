<template>
  <v-app>
    <v-app-bar app dense>
  <v-app-bar-nav-icon @click="drawer = !drawer" />
  <v-toolbar-title class="ml-2" style="cursor: pointer" @click="router.push('/')">
   The Training Theory
 </v-toolbar-title>
  <v-spacer />
  <v-btn icon @click="toggleTheme">
    <v-icon>{{ isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
  </v-btn>
</v-app-bar>

<v-navigation-drawer v-model="drawer" temporary>
  <v-list>
    <v-list-item link @click="router.push('/')">
      <v-list-item-title>Home</v-list-item-title>
    </v-list-item>
    <v-list-item link @click="router.push('/login')">
      <v-list-item-title>Login</v-list-item-title>
    </v-list-item>
  </v-list>
</v-navigation-drawer>
    <v-main>
      <v-container fluid class="fill-height pa-0">
        <v-row no-gutters class="fill-height align-stretch">
          <!-- Left Panel with Image (Loaded from public folder) -->
          <v-col cols="12" md="5" lg="4" class="d-flex justify-center align-center pa-4">
            <v-img
              src="/gym_illustration.png"
              alt="Gym Illustration"
              class="rounded-lg hidden-sm-and-down"
              max-width="500"
              max-height="500"
              width="100%"
              height="auto"
              aspect-ratio="1"
              cover
            />
          </v-col>
          <!-- Right Panel -->
          <v-col cols="12" md="7" lg="8" class="d-flex justify-center align-center pa-4 pa-md-10">
            <v-card elevation="8" class="pa-6" max-width="600" width="100%">
              <v-card-title class="text-center text-h4 font-weight-bold mb-4">
                TFT Gyms
              </v-card-title>
              <v-card-subtitle class="text-subtitle-1 text-center mb-4">
                Register your gym to become part of us.
              </v-card-subtitle>
              <v-form @submit.prevent="submit" class="mt-4">
                <v-text-field v-model="form.name" label="Gym Name" required></v-text-field>
                <v-text-field v-model="form.email" label="Email" type="email" required></v-text-field>
                <v-text-field
                  v-model="form.password"
                  label="Password"
                  :type="showPassword ? 'text' : 'password'"
                  :append-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
                  @click:append="showPassword = !showPassword"
                  required
                />
                <v-text-field v-model="form.address" label="Address"></v-text-field>
                <v-text-field v-model="form.contactNumber" label="Contact Number"></v-text-field>
                <v-text-field v-model="form.services" label="Services (comma-separated)"></v-text-field>
                <v-btn type="submit" color="primary" class="mt-4" block>Register</v-btn>
                <v-btn color="secondary" class="mt-2" block @click="router.push('/login')">
                  Already have an account? Login
                </v-btn>
              </v-form>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </v-main>
    <!-- Theme Switcher Button -->
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
import { VIcon } from 'vuetify/components'
import { useRouter } from 'vue-router'

const drawer = ref(false)

const router = useRouter()

const form = ref({
  name: '',
  email: '',
  password: '',
  address: '',
  contactNumber: '',
  services: ''
})

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
const isDark = ref(false)

function applyThemeFromStorageOrSystem() {
  const storedTheme = localStorage.getItem('theme')
  if (storedTheme === 'dark' || storedTheme === 'light') {
    theme.global.name.value = storedTheme
    isDark.value = storedTheme === 'dark'
  } else {
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    theme.global.name.value = systemPrefersDark ? 'dark' : 'light'
    isDark.value = systemPrefersDark
  }
}

function toggleTheme () {
  isDark.value = !isDark.value
  const newTheme = isDark.value ? 'dark' : 'light'
  theme.global.name.value = newTheme
  localStorage.setItem('theme', newTheme)
}

applyThemeFromStorageOrSystem()

async function submit () {
  const payload = {
    ...form.value,
    services: form.value.services.split(',').map(s => s.trim())
  }

  try {
    const res = await fetch('http://localhost:5050/api/gym/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    })
    const data = await res.json()
    showMessage(data.message || 'Registered!', 'success')
  } catch (err) {
    console.error(err)
    showMessage('Registration failed', 'error')
  }
}
</script>

<style scoped>
.gradient-blue {
  background: linear-gradient(135deg, #4a90e2, #145cff);
}
</style>
