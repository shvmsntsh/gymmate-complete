<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">Gym Registration</div>
          <h1 class="display-headline">
            Open your gym account.
          </h1>
          <p class="lead-copy">
            Add the essentials once and move straight into your owner workspace.
          </p>
        </div>

        <div class="hero-metrics">
          <div class="hero-metric">
            <div class="hero-metric__value">Fast</div>
            <div class="hero-metric__label">
              Create the gym profile in one short pass.
            </div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Clean</div>
            <div class="hero-metric__label">
              Keep address, contact, and services together.
            </div>
          </div>
          <div class="hero-metric">
            <div class="hero-metric__value">Ready</div>
            <div class="hero-metric__label">
              Start using the owner workspace right after setup.
            </div>
          </div>
        </div>
      </div>
    </template>

    <div class="stack">
        <div>
          <div class="eyebrow">Create A Gym</div>
          <h2 class="section-title">Register a new location</h2>
          <p class="section-copy">
            Fill in the essentials to open the gym account.
          </p>
        </div>

      <div v-if="createdGym" class="registration-success admin-surface admin-surface--muted">
        <div>
          <div class="registration-success__eyebrow">Gym Created</div>
          <div class="registration-success__title">
            {{ createdGym.gymName || createdGym.name }} is ready.
          </div>
          <div class="registration-success__copy">
            {{ createdOwner?.email || createdGym.email }} can now sign in to the
            owner workspace and continue setup.
          </div>
        </div>

        <div class="registration-success__facts">
          <div class="registration-pill">
            <span class="registration-pill__label">Address</span>
            <span class="registration-pill__value">
              {{ createdGym.address || "Saved" }}
            </span>
          </div>
          <div class="registration-pill">
            <span class="registration-pill__label">Contact</span>
            <span class="registration-pill__value">
              {{ createdGym.contactNumber || "Saved" }}
            </span>
          </div>
          <div class="registration-pill">
            <span class="registration-pill__label">Services</span>
            <span class="registration-pill__value">
              {{ createdServicesLabel }}
            </span>
          </div>
        </div>

        <div class="cta-row">
          <v-btn color="primary" size="large" @click="goToLogin">
            Continue to login
          </v-btn>
          <v-btn size="large" variant="tonal" @click="resetForm">
            Register another gym
          </v-btn>
        </div>
      </div>

      <v-form class="stack" @submit.prevent="submit">
        <div class="form-grid">
          <div>
            <div class="field-label">Gym Name</div>
            <v-text-field
              v-model="form.name"
              density="comfortable"
              hide-details="auto"
              variant="outlined"
              required
            />
          </div>

          <div>
            <div class="field-label">Email</div>
            <v-text-field
              v-model="form.email"
              density="comfortable"
              hide-details="auto"
              type="email"
              variant="outlined"
              required
            />
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
            <v-text-field
              v-model="form.address"
              density="comfortable"
              hide-details="auto"
              variant="outlined"
            />
          </div>

          <div>
            <div class="field-label">Contact Number</div>
            <v-text-field
              v-model="form.contactNumber"
              density="comfortable"
              hide-details="auto"
              variant="outlined"
            />
          </div>

          <div>
            <div class="field-label">Services (comma-separated)</div>
            <v-text-field
              v-model="form.services"
              density="comfortable"
              hide-details="auto"
              variant="outlined"
            />
          </div>
        </div>

        <div class="cta-row">
          <v-btn color="primary" size="large" type="submit" :loading="submitting">
            Register Gym
          </v-btn>
          <v-btn size="large" variant="tonal" @click="router.push('/login')">
            Back to Login
          </v-btn>
        </div>
      </v-form>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">
      {{ snackbarText }}
    </v-snackbar>
  </PublicAuthShell>
</template>

<script setup>
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import PublicAuthShell from "../components/PublicAuthShell.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch } from "../lib/api";

const router = useRouter();
const form = ref({
  name: "",
  email: "",
  password: "",
  address: "",
  contactNumber: "",
  services: "",
});
const showPassword = ref(false);
const snackbar = ref(false);
const snackbarText = ref("");
const snackbarColor = ref("");
const submitting = ref(false);
const createdGym = ref(null);
const createdOwner = ref(null);
const { isDark, toggleTheme } = useAdminTheme();

const createdServicesLabel = computed(() => {
  const services = createdGym.value?.services || [];
  if (!Array.isArray(services) || services.length === 0) {
    return "No services listed";
  }
  if (services.length === 1) {
    return services[0];
  }
  return `${services[0]} +${services.length - 1}`;
});

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

function emptyForm() {
  return {
    name: "",
    email: "",
    password: "",
    address: "",
    contactNumber: "",
    services: "",
  };
}

function resetForm() {
  form.value = emptyForm();
  createdGym.value = null;
  createdOwner.value = null;
}

function goToLogin() {
  router.push({
    path: "/login",
    query: createdOwner.value?.email ? { email: createdOwner.value.email } : {},
  });
}

async function submit() {
  submitting.value = true;

  const payload = {
    gymName: form.value.name,
    email: form.value.email,
    password: form.value.password,
    address: form.value.address,
    contactNumber: form.value.contactNumber,
    phone: form.value.contactNumber,
    services: form.value.services
      .split(",")
      .map((service) => service.trim())
      .filter(Boolean),
  };

  try {
    const res = await apiFetch("/api/gym/register", {
      method: "POST",
      body: JSON.stringify(payload),
      skipAuth: true,
    });
    const data = await res.json();
    if (res.ok) {
      createdGym.value = data.gym || null;
      createdOwner.value = data.owner || null;
      form.value = emptyForm();
      showMessage(data.message || "Gym and owner account are ready.", "success");
      return;
    }

    showMessage(data.message || "Registration failed", "error");
  } catch (err) {
    showMessage(err?.message || "Registration failed", "error");
  } finally {
    submitting.value = false;
  }
}
</script>

<style scoped>
.registration-success {
  padding: 22px;
  border-radius: 28px;
  border: 1px solid rgba(181, 159, 91, 0.18);
}

.registration-success__eyebrow {
  color: var(--gm-accent);
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.registration-success__title {
  margin-top: 8px;
  font-size: 1.5rem;
  font-weight: 700;
}

.registration-success__copy {
  margin-top: 8px;
  color: var(--gm-text-muted);
}

.registration-success__facts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
  margin-top: 18px;
}

.registration-pill {
  padding: 16px;
  border-radius: 22px;
  background: rgba(255, 255, 255, 0.02);
  border: 1px solid rgba(181, 159, 91, 0.14);
}

.registration-pill__label {
  display: block;
  color: var(--gm-text-muted);
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.registration-pill__value {
  display: block;
  margin-top: 8px;
  font-weight: 700;
}

@media (max-width: 960px) {
  .registration-success__facts {
    grid-template-columns: 1fr;
  }
}
</style>
