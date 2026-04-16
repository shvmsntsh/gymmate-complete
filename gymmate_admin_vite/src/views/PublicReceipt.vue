<template>
  <v-app>
    <main class="receipt-page">
      <section class="receipt-card">
        <div v-if="loading" class="receipt-center">
          <v-progress-circular indeterminate color="primary" />
        </div>

        <template v-else-if="receipt">
          <div class="receipt-header">
            <div>
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
  background: #f4efe6;
  color: #201a15;
  display: grid;
  place-items: start center;
}

.receipt-card {
  width: min(760px, 100%);
  background: #fffaf3;
  border: 1px solid rgba(113, 88, 56, 0.18);
  border-radius: 8px;
  padding: 28px;
  box-shadow: 0 24px 70px rgba(34, 22, 10, 0.12);
}

.receipt-center {
  display: grid;
  min-height: 240px;
  place-items: center;
}

.receipt-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 18px;
  margin-bottom: 28px;
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
  font-size: 2rem;
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
  border-top: 1px solid rgba(113, 88, 56, 0.18);
  font-size: 1.2rem;
}

.receipt-total strong {
  font-size: 1.55rem;
}

@media (max-width: 640px) {
  .receipt-card {
    padding: 22px;
  }

  .receipt-grid {
    grid-template-columns: 1fr;
  }
}
</style>
