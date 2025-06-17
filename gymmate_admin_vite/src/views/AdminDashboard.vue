<template>
  <v-app :theme="isDark ? 'dark' : 'light'">
    <!-- Theme Toggle Button -->
    <v-btn icon class="ma-2 position-absolute" style="top: 0; right: 0; z-index: 1000;" @click="toggleTheme">
      <v-icon>{{ isDark ? 'mdi-weather-sunny' : 'mdi-weather-night' }}</v-icon>
    </v-btn>

    <v-navigation-drawer app permanent>
      <v-list>
        <v-list-item-title class="text-h6 text-center my-4">Admin Panel</v-list-item-title>
        <v-divider></v-divider>
        <v-list-item link to="/admin">
          <v-list-item-icon><v-icon>mdi-view-dashboard</v-icon></v-list-item-icon>
          <v-list-item-content><v-list-item-title>Dashboard</v-list-item-title></v-list-item-content>
        </v-list-item>
        <v-list-item link to="/members">
          <v-list-item-icon><v-icon>mdi-account-group</v-icon></v-list-item-icon>
          <v-list-item-content><v-list-item-title>Manage Members</v-list-item-title></v-list-item-content>
        </v-list-item>
        <v-list-item link to="/add-service">
          <v-list-item-icon><v-icon>mdi-dumbbell</v-icon></v-list-item-icon>
          <v-list-item-content><v-list-item-title>Add Service</v-list-item-title></v-list-item-content>
        </v-list-item>
        <v-list-item @click="$router.push('/login')">
          <v-list-item-icon><v-icon>mdi-logout</v-icon></v-list-item-icon>
          <v-list-item-content><v-list-item-title>Logout</v-list-item-title></v-list-item-content>
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <v-main>
      <v-container fluid>
        <v-row dense class="mb-4">
          <v-col cols="12" md="4">
            <v-card elevation="3" class="pa-4">
              <v-card-title>Total Gyms</v-card-title>
              <v-card-subtitle class="text-h5 font-weight-bold">{{ gymCount }}</v-card-subtitle>
            </v-card>
          </v-col>
          <v-col cols="12" md="4">
            <v-card elevation="3" class="pa-4">
              <v-card-title>Active Members</v-card-title>
              <v-card-subtitle class="text-h5 font-weight-bold">{{ memberCount }}</v-card-subtitle>
            </v-card>
          </v-col>
          <v-col cols="12" md="4">
            <v-card elevation="3" class="pa-4">
              <v-card-title>Services Offered</v-card-title>
              <v-card-subtitle class="text-h5 font-weight-bold">{{ serviceCount }}</v-card-subtitle>
            </v-card>
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="12">
            <v-card elevation="3" class="pa-4">
              <v-card-title>Recent Gym Registrations</v-card-title>
              <v-data-table
                :headers="[
                  { text: 'Gym Name', value: 'name' },
                  { text: 'Email', value: 'email' },
                  { text: 'Address', value: 'address' },
                  { text: 'Services', value: 'services' }
                ]"
                :items="recentGyms"
                class="elevation-1"
              ></v-data-table>
            </v-card>
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="12">
            <v-card elevation="3" class="pa-4">
              <v-card-title>Usage Overview</v-card-title>
              <v-card-text>
                <canvas id="usageChart" style="max-height: 300px;"></canvas>
              </v-card-text>
            </v-card>
          </v-col>
        </v-row>

        <v-row>
          <v-col cols="12">
            <v-card elevation="3" class="pa-4">
              <v-card-title>Services Distribution</v-card-title>
              <v-card-text>
                <canvas id="serviceChart" style="max-height: 300px;"></canvas>
              </v-card-text>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </v-main>
  </v-app>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useTheme } from 'vuetify'
import Chart from 'chart.js/auto'

const theme = useTheme()
const isDark = ref(window.matchMedia('(prefers-color-scheme: dark)').matches)

const gymCount = ref(0)
const memberCount = ref(0)
const serviceCount = ref(0)

const recentGyms = ref([])

const serviceDistribution = ref([])

const fetchDashboardStats = async () => {
  try {
    const res = await fetch('http://localhost:5050/api/dashboard/stats')
    const data = await res.json()
    gymCount.value = data.totalGyms
    memberCount.value = data.totalMembers
    serviceCount.value = data.totalServices
  } catch (err) {
    console.error('Failed to fetch dashboard stats:', err)
  }
}

const fetchRecentGyms = async () => {
  try {
    const res = await fetch('http://localhost:5050/api/gym/list')
    const data = await res.json()
    recentGyms.value = data.map(gym => ({
      name: gym.name,
      email: gym.email,
      address: gym.address,
      services: Array.isArray(gym.services) ? gym.services.join(', ') : gym.services
    }))
  } catch (err) {
    console.error('Failed to fetch gym list:', err)
  }
}

const fetchServiceDistribution = async () => {
  try {
    const res = await fetch('http://localhost:5050/api/services/distribution')
    const data = await res.json()
    serviceDistribution.value = data
  } catch (err) {
    console.error('Failed to fetch service distribution:', err)
  }
}

const toggleTheme = () => {
  isDark.value = !isDark.value
  theme.global.name.value = isDark.value ? 'dark' : 'light'
}

onMounted(async () => {
  await fetchDashboardStats()
  theme.global.name.value = isDark.value ? 'dark' : 'light'
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
    isDark.value = e.matches
    theme.global.name.value = isDark.value ? 'dark' : 'light'
  })

  const ctx = document.getElementById('usageChart')
  if (ctx) {
    new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Gyms', 'Members', 'Services'],
        datasets: [{
          label: 'Overview',
          data: [gymCount.value, memberCount.value, serviceCount.value],
          backgroundColor: [
            'rgba(66, 133, 244, 0.6)',
            'rgba(52, 168, 83, 0.6)',
            'rgba(251, 188, 5, 0.6)'
          ],
          borderColor: [
            'rgba(66, 133, 244, 1)',
            'rgba(52, 168, 83, 1)',
            'rgba(251, 188, 5, 1)'
          ],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            labels: {
              color: isDark.value ? '#fff' : '#000'
            }
          }
        },
        scales: {
          y: {
            ticks: {
              color: isDark.value ? '#fff' : '#000'
            }
          },
          x: {
            ticks: {
              color: isDark.value ? '#fff' : '#000'
            }
          }
        }
      }
    })
  }
  await fetchRecentGyms()

  const serviceCtx = document.getElementById('serviceChart');
  if (serviceCtx) {
    await fetchServiceDistribution()
    new Chart(serviceCtx, {
      type: 'pie',
      data: {
        labels: serviceDistribution.value.map(item => item.name),
        datasets: [{
          label: 'Service Distribution',
          data: serviceDistribution.value.map(item => item.count),
          backgroundColor: [
            'rgba(255, 99, 132, 0.6)',
            'rgba(54, 162, 235, 0.6)',
            'rgba(255, 206, 86, 0.6)',
            'rgba(75, 192, 192, 0.6)',
            'rgba(153, 102, 255, 0.6)'
          ],
          borderColor: '#fff',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            labels: {
              color: isDark.value ? '#fff' : '#000'
            }
          }
        }
      }
    });
  }
})
</script>