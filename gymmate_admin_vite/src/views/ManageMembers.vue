<template>
  <v-app>
    <v-main>
      <v-container>
        <v-row align="center" justify="space-between" class="mb-4">
          <v-col cols="12" md="6">
            <h2 class="text-h5 font-weight-bold">Manage Members</h2>
          </v-col>
        </v-row>

        <div v-if="error" class="text-error text-center">{{ error }}</div>
        <div v-else-if="!loading && members.length === 0" class="text-center">No members found.</div>
        <VDataTable
          v-else
          :headers="headers"
          :items="members"
          :loading="loading"
          class="elevation-1"
          item-value="id"
        >
          <template v-slot:item.actions="{ item }">
            <v-btn icon @click="viewMember(item)">
              <v-icon>mdi-eye</v-icon>
            </v-btn>
          </template>
        </VDataTable>
      </v-container>
    </v-main>
  </v-app>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { VBtn, VIcon } from 'vuetify/components'

const members = ref([])
const loading = ref(false)
const error = ref('')

const headers = [
  { text: 'Gym Name', value: 'gymName' },
  { text: 'Email', value: 'email' },
  { text: 'Contact', value: 'contact' },
  { text: 'Actions', value: 'actions', sortable: false }
]

const fetchMembers = async () => {
  loading.value = true
  error.value = ''
  try {
    const res = await fetch('http://localhost:5050/api/members')
    const data = await res.json()
    members.value = data.members || []
  } catch (err) {
    console.error('Failed to fetch members:', err)
    error.value = 'Failed to load members. Please try again later.'
  } finally {
    loading.value = false
  }
}

const viewMember = (member) => {
  console.log('View member:', member)
}

onMounted(fetchMembers)
</script>

<style scoped>
</style>
