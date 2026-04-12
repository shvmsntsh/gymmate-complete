<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">Account Recovery</div>
          <h1 class="display-headline">Reset your GymMate password.</h1>
          <p class="lead-copy">
            Use the email on your account and set a new password with the code we send.
          </p>
        </div>
      </div>
    </template>

    <div class="stack">
      <div>
        <div class="eyebrow">Forgot Password</div>
        <h2 class="section-title">Get back in safely</h2>
        <p class="section-copy">
          Enter your email first, then use the code from your inbox.
        </p>
      </div>

      <v-form class="stack" @submit.prevent="step === 'request' ? requestCode() : completeReset()">
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

        <template v-if="step === 'reset'">
          <div>
            <div class="field-label">Reset Code</div>
            <v-text-field
              v-model="form.code"
              density="comfortable"
              hide-details="auto"
              inputmode="numeric"
              maxlength="6"
              variant="outlined"
              required
            />
          </div>
          <div>
            <div class="field-label">New Password</div>
            <v-text-field
              v-model="form.newPassword"
              density="comfortable"
              hide-details="auto"
              type="password"
              variant="outlined"
              required
            />
          </div>
          <div>
            <div class="field-label">Confirm Password</div>
            <v-text-field
              v-model="form.confirmPassword"
              density="comfortable"
              hide-details="auto"
              type="password"
              variant="outlined"
              required
            />
          </div>
        </template>

        <div class="cta-row">
          <v-btn color="primary" size="large" type="submit" :loading="submitting">
            {{ step === "request" ? "Send Code" : "Reset Password" }}
          </v-btn>
          <v-btn size="large" variant="tonal" @click="router.push('/login')">
            Back to Login
          </v-btn>
        </div>
      </v-form>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4500">
      {{ snackbarText }}
    </v-snackbar>
  </PublicAuthShell>
</template>

<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import PublicAuthShell from "../components/PublicAuthShell.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch } from "../lib/api";

const route = useRoute();
const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const step = ref("request");
const submitting = ref(false);
const snackbar = ref(false);
const snackbarText = ref("");
const snackbarColor = ref("success");
const form = ref({
  email: String(route.query.email || ""),
  code: "",
  newPassword: "",
  confirmPassword: "",
});

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

async function requestCode() {
  submitting.value = true;
  try {
    const res = await apiFetch("/api/auth/password-reset/request", {
      method: "POST",
      body: JSON.stringify({ email: form.value.email }),
      skipAuth: true,
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not request a reset code.");
    step.value = "reset";
    showMessage(data.message || "If that email exists, a reset code was sent.");
  } catch (error) {
    showMessage(error?.message || "Could not request a reset code.", "error");
  } finally {
    submitting.value = false;
  }
}

async function completeReset() {
  if (form.value.newPassword.length < 6) {
    showMessage("Password must be at least 6 characters.", "error");
    return;
  }
  if (form.value.newPassword !== form.value.confirmPassword) {
    showMessage("Passwords do not match.", "error");
    return;
  }

  submitting.value = true;
  try {
    const res = await apiFetch("/api/auth/password-reset/complete", {
      method: "POST",
      body: JSON.stringify({
        email: form.value.email,
        code: form.value.code,
        newPassword: form.value.newPassword,
      }),
      skipAuth: true,
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Could not reset password.");
    showMessage(data.message || "Password updated.");
    router.push({ path: "/login", query: { email: form.value.email } });
  } catch (error) {
    showMessage(error?.message || "Could not reset password.", "error");
  } finally {
    submitting.value = false;
  }
}
</script>
