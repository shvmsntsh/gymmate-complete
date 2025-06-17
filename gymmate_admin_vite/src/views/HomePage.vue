<template>
  <v-app>
    <v-navigation-drawer
      v-model="drawer"
     app     
     temporary
   >
      <v-list nav>
        <v-list-item link to="/">
          <v-list-item-title>Home</v-list-item-title>
        </v-list-item>
        <v-list-item link to="/login">
          <v-list-item-title>Login</v-list-item-title>
        </v-list-item>
        <v-list-item link to="/register-gym">
          <v-list-item-title>Register</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-app-bar app flat color="transparent">
      <v-app-bar-nav-icon @click="drawer = !drawer" />
      <v-toolbar-title class="ml-4">GymMate</v-toolbar-title>
      <v-spacer />
      <v-btn icon @click="toggleTheme">
        <v-icon>{{ theme.global.current.value.dark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
      </v-btn>
    </v-app-bar>

    <div
      class="hero-image d-flex flex-column justify-center align-center text-center"
      :style="{
        backgroundImage: theme.global.current.value.dark
          ? `url('/images/gymbghomepagedark.png')`
          : `url('/images/gymbghomepagelight.png')`
      }"
    >
      <div class="hero-content">
        <h1 class="display-2 font-weight-bold mb-4 text-white">Welcome GymRats</h1>
        <p class="subtitle-1 mb-6 text-white">Your premium destination for Gym, Swimming, and Healthy Bites</p>
        <v-btn color="primary" class="mr-4" large to="/login">Login</v-btn>
        <v-btn color="secondary" outlined large to="/register-gym">Register Gym</v-btn>
      </div>
    </div>
  </v-app>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useTheme } from 'vuetify'

const drawer = ref(false)
const theme = useTheme()

onMounted(() => {
  const userPref = localStorage.getItem('theme')
  const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  theme.global.name.value = userPref ? userPref : (systemPrefersDark ? 'dark' : 'light')
})

function toggleTheme() {
  const newTheme = theme.global.current.value.dark ? 'light' : 'dark'
  theme.global.name.value = newTheme
  localStorage.setItem('theme', newTheme)
}
</script>

<style scoped>
.hero-image {
  position: relative;
  height: 100vh;
  background-position: center;
  background-repeat: no-repeat;
  background-size: cover;
  transition: background-image 0.3s ease-in-out;
}

.hero-content {
  z-index: 2;
  position: relative;
  padding: 2rem;
  text-align: center;
  backdrop-filter: brightness(0.9);
  background-color: rgba(0, 0, 0, 0.4);
  border-radius: 1rem;
}

@media (min-width: 768px) {
  .hero-content {
    max-width: 600px;
  }
}
</style>