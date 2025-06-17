<template>
  <v-app>
    <v-main>
      <v-container>
        <v-card elevation="4" class="mx-auto my-10" max-width="700">
          <v-card-title class="text-h5 font-weight-bold">
            Gym Details
          </v-card-title>
          <v-card-text v-if="gym">
            <p><strong>Name:</strong> {{ gym.name }}</p>
            <p><strong>Email:</strong> {{ gym.email }}</p>
            <p><strong>Address:</strong> {{ gym.address }}</p>
            <p><strong>Contact:</strong> {{ gym.contactNumber }}</p>
            <p><strong>Services:</strong> {{ gym.services?.join(', ') }}</p>
          </v-card-text>
          <v-card-text v-else>
            <v-alert type="error">Gym not found or failed to load.</v-alert>
          </v-card-text>
        </v-card>
      </v-container>
    </v-main>
  </v-app>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const gym = ref(null)

onMounted(async () => {
  try {
    const id = route.params.id
    const res = await fetch(`http://localhost:5050/api/gym/${id}`)
    const data = await res.json()
    gym.value = data
  } catch (err) {
    console.error('Failed to fetch gym:', err)
  }
})
</script>
