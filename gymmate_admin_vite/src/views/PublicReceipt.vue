<template>
  <v-app>
    <main class="receipt-page">
      <section class="receipt-card">
        <div v-if="loading" class="receipt-center">
          <v-progress-circular indeterminate color="primary" />
        </div>

        <template v-else-if="receipt">
          <div class="receipt-header">
            <div class="receipt-brand-line">
              <div class="receipt-logo-frame">
                <img
                  v-if="receipt.gym?.branding?.logoUrl"
                  :src="receipt.gym.branding.logoUrl"
                  :alt="`${receipt.gym?.name || 'Gym'} logo`"
                />
                <span v-else>{{ initials(receipt.gym?.name || "GM") }}</span>
              </div>
              <div>
                <div class="receipt-value">{{ receipt.gym?.name || "GymMate Gym" }}</div>
                <div class="receipt-muted">{{ receipt.gym?.address || "Official payment receipt" }}</div>
              </div>
            </div>
            <div class="receipt-title-block">
              <div class="receipt-kicker">GymMate Receipt</div>
              <h1>{{ receipt.receiptNumber }}</h1>
            </div>
            <v-btn color="primary" variant="tonal" @click="printReceipt">Print</v-btn>
          </div>

          <div class="receipt-grid">
            <div>
              <div class="receipt-label">Gym</div>
              <div class="receipt-value">{{ receipt.gym?.name || "GymMate Gym" }}</div>
              <div class="receipt-muted">{{ receipt.gym?.address }}</div>
            </div>
            <div>
              <div class="receipt-label">Member</div>
              <div class="receipt-value">{{ receipt.member?.name || "Member" }}</div>
              <div class="receipt-muted">{{ receipt.member?.email }}</div>
            </div>
            <div>
              <div class="receipt-label">Plan</div>
              <div class="receipt-value">{{ receipt.planName }}</div>
              <div class="receipt-muted">Issued {{ formatDate(receipt.issuedAt) }}</div>
            </div>
            <div>
              <div class="receipt-label">Payment</div>
              <div class="receipt-value">₹{{ Number(receipt.amount || 0).toFixed(2) }}</div>
              <div class="receipt-muted">
                {{ receipt.paymentMethod || "Payment" }}
                <span v-if="receipt.paymentReference"> · {{ receipt.paymentReference }}</span>
              </div>
            </div>
            <div>
              <div class="receipt-label">Status</div>
              <div class="receipt-value">{{ receipt.status || "Paid" }}</div>
              <div class="receipt-muted">Thank you for your payment.</div>
            </div>
          </div>

          <div class="receipt-total">
            <span>Total Paid</span>
            <strong>₹{{ Number(receipt.amount || 0).toFixed(2) }}</strong>
          </div>
        </template>

        <v-alert v-else type="error" variant="tonal">
          {{ error || "Receipt not found." }}
        </v-alert>
      </section>
    </main>
  </v-app>
</template>

<script setup>
import { onMounted, ref } from "vue";
import { useRoute } from "vue-router";
import { apiFetch } from "../lib/api";

const route = useRoute();
const receipt = ref(null);
const loading = ref(true);
const error = ref("");

function formatDate(value) {
  if (!value) return "";
  return new Date(value).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function initials(value) {
  return String(value || "GM")
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("") || "GM";
}

function printReceipt() {
  window.print();
}

onMounted(async () => {
  try {
    const res = await apiFetch(`/api/receipts/${route.params.token}`, {
      skipAuth: true,
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Receipt not found.");
    receipt.value = data.receipt;
  } catch (err) {
    error.value = err.message || "Receipt not found.";
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.receipt-page {
  min-height: 100vh;
  padding: 32px 18px;
  background: #fdf8f6;
  color: #2c2c2e;
  display: grid;
  place-items: start center;
}

.receipt-card {
  width: min(860px, 100%);
  background: #ffffff;
  border: 1px solid #e7d9d4;
  border-radius: 16px;
  padding: 32px;
  box-shadow: 0 24px 70px rgba(43, 26, 17, 0.1);
}

.receipt-center {
  display: grid;
  min-height: 240px;
  place-items: center;
}

.receipt-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 18px;
  margin-bottom: 28px;
}

.receipt-brand-line {
  display: flex;
  align-items: center;
  gap: 14px;
}

.receipt-logo-frame {
  display: grid;
  place-items: center;
  width: 64px;
  height: 64px;
  border: 1px solid #e7d9d4;
  border-radius: 14px;
  background: #f4f0ef;
  color: #ff5200;
  font-weight: 900;
  overflow: hidden;
}

.receipt-logo-frame img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  display: block;
}

.receipt-title-block {
  text-align: right;
}

.receipt-kicker,
.receipt-label {
  color: #8f6931;
  font-size: 0.76rem;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

h1 {
  margin: 8px 0 0;
  font-size: clamp(1.4rem, 4vw, 2rem);
}

.receipt-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 22px;
}

.receipt-value {
  margin-top: 6px;
  font-size: 1.05rem;
  font-weight: 800;
}

.receipt-muted {
  margin-top: 3px;
  color: #6b5c4e;
}

.receipt-total {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 30px;
  padding-top: 20px;
  border-top: 1px solid #e7d9d4;
  font-size: 1.2rem;
}

.receipt-total strong {
  font-size: 1.55rem;
}

@media (max-width: 640px) {
  .receipt-header {
    align-items: flex-start;
    flex-direction: column;
  }

  .receipt-title-block {
    text-align: left;
  }

  .receipt-card {
    padding: 22px;
  }

  .receipt-grid {
    grid-template-columns: 1fr;
  }
}
</style>
