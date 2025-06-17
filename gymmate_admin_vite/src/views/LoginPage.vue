<template>
  <v-app>
    <!-- App bar with hamburger and theme toggle -->
<v-app-bar app flat color="transparent">
  <!-- Left side: hamburger and title -->
  <v-btn icon @click="drawer = !drawer">
    <v-icon>mdi-menu</v-icon>
  </v-btn>
 <v-toolbar-title class="ml-2" style="cursor: pointer" @click="router.push('/')">
   GymMate
 </v-toolbar-title>
  
  <!-- Fill spacer -->
  <v-spacer />

  <!-- Right side: theme toggle -->
  <v-btn icon @click="toggleTheme">
    <v-icon>{{ isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
  </v-btn>
</v-app-bar>

    <!-- Navigation drawer -->
    <v-navigation-drawer v-model="drawer" app temporary>
      <v-list>
        <v-list-item to="/" @click="drawer = false">Home</v-list-item>
        <v-list-item to="/login" @click="drawer = false">Login</v-list-item>
        <v-list-item to="/register-gym" @click="drawer = false">Register</v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-main>
      <v-container fluid class="fill-height pa-0">
        <v-row no-gutters class="fill-height align-stretch">
          <!-- Left image panel -->
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
          <!-- Right form panel -->
          <v-col cols="12" md="7" lg="8" class="d-flex justify-center align-center pa-4 pa-md-10">
            <v-card elevation="8" class="pa-6" max-width="500" width="100%">
              <v-card-title class="text-h4 font-weight-bold text-center">Welcome Back</v-card-title>
              <v-card-subtitle class="text-subtitle-1 text-center mb-4">
                Login to manage your gym account
              </v-card-subtitle>
              <v-form @submit.prevent="submit" class="mt-4">
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
                <v-btn color="secondary" class="mt-2" block @click="router.push('/register-gym')">
                  Don't have an account? Register
                </v-btn>
              </v-form>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </v-main>

    <!-- Snackbar for feedback -->
    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">
      {{ snackbarText }}
    </v-snackbar>
  </v-app>
</template>

<script setup>
import { ref, watchEffect, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useTheme } from 'vuetify'

const router = useRouter()
const theme = useTheme()

const drawer = ref(false)
const form = ref({ email: '', password: '' })
const showPassword = ref(false)
const snackbar = ref(false)
const snackbarText = ref('')
const snackbarColor = ref('')

// Theme handling
const isDark = ref(
  localStorage.getItem('gymmate_theme') === 'dark' ||
  (!localStorage.getItem('gymmate_theme') && window.matchMedia('(prefers-color-scheme: dark)').matches)
)
theme.global.name.value = isDark.value ? 'dark' : 'light'

onMounted(() => {
  const userPref = localStorage.getItem('gymmate_theme')
  const systemPrefers = window.matchMedia('(prefers-color-scheme: dark)').matches
  theme.global.name.value = userPref ? userPref : (systemPrefers ? 'dark' : 'light')
})

function toggleTheme() {
  isDark.value = !isDark.value
  theme.global.name.value = isDark.value ? 'dark' : 'light'
  localStorage.setItem('gymmate_theme', isDark.value ? 'dark' : 'light')
}

window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
  if (!localStorage.getItem('gymmate_theme')) {
    isDark.value = e.matches
    theme.global.name.value = e.matches ? 'dark' : 'light'
  }
})

watchEffect(() => {
  theme.global.name.value = isDark.value ? 'dark' : 'light'
})

// Form handling
function showMessage(message, color = 'success') {
  snackbarText.value = message
  snackbarColor.value = color
  snackbar.value = true
}

async function submit() {
  try {
    const res = await fetch('http://localhost:5050/api/gym/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form.value)
    })
    const data = await res.json()
    if (res.ok) {
      localStorage.setItem('gymmate_logged_in', 'true')
      router.push('/admin')
    } else {
      showMessage(data.message || 'Login failed', 'error')
    }
  } catch {
    showMessage('Something went wrong. Please try again.', 'error')
  }
}
</script>
EOF