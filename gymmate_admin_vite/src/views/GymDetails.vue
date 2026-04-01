<template>
  <AdminShell
    :is-dark="isDark"
    title="Gym Details"
    eyebrow="Gym Profile"
    description="See the main details for this gym in one place."
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <section class="admin-surface admin-panel">
      <div class="section-header">
        <div>
          <div class="table-overline">Gym Record</div>
          <h2 class="section-title">Registered gym information</h2>
        </div>
      </div>

      <StateBlock
        v-if="error"
        title="Gym not found"
        :copy="error"
        icon="mdi-domain-off"
        tone="error"
      />
      <StateBlock
        v-else-if="loading"
        title="Loading gym details"
        copy="Loading the selected gym profile."
        icon="mdi-timer-sand"
      />
      <div v-else-if="gym" class="detail-grid">
        <div class="detail-card">
          <div class="detail-card__label">Name</div>
          <div class="detail-card__value">{{ gym.name || 'Not provided' }}</div>
        </div>
        <div class="detail-card">
          <div class="detail-card__label">Email</div>
          <div class="detail-card__value">{{ gym.email || 'Not provided' }}</div>
        </div>
        <div class="detail-card">
          <div class="detail-card__label">Address</div>
          <div class="detail-card__value">{{ gym.address || 'Not provided' }}</div>
        </div>
        <div class="detail-card">
          <div class="detail-card__label">Contact</div>
          <div class="detail-card__value">{{ gym.contactNumber || gym.phone || 'Not provided' }}</div>
        </div>
        <div class="detail-card" style="grid-column: 1 / -1;">
          <div class="detail-card__label">Services</div>
          <div class="detail-card__value">{{ formattedServices }}</div>
        </div>
      </div>
    </section>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AdminShell from '../components/AdminShell.vue'
import StateBlock from '../components/StateBlock.vue'
import { useAdminTheme } from '../composables/useAdminTheme'
import { apiFetch, clearAdminSession } from '../lib/api'

const route = useRoute()
const router = useRouter()
const gym = ref(null)
const loading = ref(false)
const error = ref('')
const { isDark, toggleTheme } = useAdminTheme()

const formattedServices = computed(() => {
  if (!gym.value?.services?.length) {
    return 'Not provided'
  }

  return Array.isArray(gym.value.services) ? gym.value.services.join(', ') : gym.value.services
})

async function fetchGym() {
  loading.value = true
  error.value = ''
  gym.value = null

  try {
    const id = route.params.id
    const res = await apiFetch(`/api/gym/${id}`)
    const data = await res.json()
    if (!res.ok) {
      throw new Error(data.message || 'Gym not found')
    }
    gym.value = data
  } catch (err) {
    error.value = err?.message || 'We could not load this gym right now.'
  } finally {
    loading.value = false
  }
}

function logout() {
  clearAdminSession()
  router.push('/login')
}

onMounted(fetchGym)
</script>
