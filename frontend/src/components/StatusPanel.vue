<template>
  <div class="status-panel card">
    <div class="header">
      <h2>System Status & Live Oracle Pipeline</h2>
      <div class="badge" :class="tierClass">
        {{ round.tier_label || 'Tier 0: Normal' }}
      </div>
    </div>
    <div class="metrics-grid">
      <div class="metric">
        <span class="label">Candidate Price</span>
        <span class="value">${{ (round.candidate_price || 100).toFixed(2) }}</span>
      </div>
      <div class="metric">
        <span class="label">Resolved Output Price</span>
        <span class="value highlight">${{ (round.resolved_price || 100).toFixed(2) }}</span>
      </div>
      <div class="metric">
        <span class="label">Round Status</span>
        <span class="value status-val">{{ round.status || 'Active' }}</span>
      </div>
      <div class="metric">
        <span class="label">Dispute Active</span>
        <span class="value" :class="{ 'text-danger': isDisputed, 'text-success': !isDisputed }">
          {{ isDisputed ? 'YES (Halted)' : 'NO (Continuous)' }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  round: {
    type: Object,
    default: () => ({
      candidate_price: 100,
      resolved_price: 100,
      tier: 0,
      tier_label: 'Tier 0: Normal',
      status: 'Normal Flow'
    })
  }
})

const tierClass = computed(() => {
  if (props.round.tier === 0) return 'tier-0'
  if (props.round.tier === 1) return 'tier-1'
  return 'tier-2'
})

const isDisputed = computed(() => props.round.tier === 2)
</script>

<style scoped>
.status-panel {
  background: #1e222d;
  border-radius: 12px;
  padding: 20px;
  border: 1px solid #2a2e39;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}
h2 {
  font-size: 1.25rem;
  font-weight: 600;
  color: #f0f3fa;
  margin: 0;
}
.badge {
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 0.85rem;
  font-weight: 700;
  text-transform: uppercase;
}
.tier-0 {
  background: rgba(38, 166, 154, 0.2);
  color: #26a69a;
  border: 1px solid #26a69a;
}
.tier-1 {
  background: rgba(255, 179, 0, 0.2);
  color: #ffb300;
  border: 1px solid #ffb300;
}
.tier-2 {
  background: rgba(239, 83, 80, 0.2);
  color: #ef5350;
  border: 1px solid #ef5350;
}
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
.metric {
  background: #131722;
  padding: 16px;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
}
.label {
  font-size: 0.75rem;
  color: #787b86;
  margin-bottom: 6px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.value {
  font-size: 1.4rem;
  font-weight: 700;
  color: #d1d4dc;
}
.value.highlight {
  color: #2962ff;
}
.status-val {
  color: #e0e3eb;
  font-size: 1.1rem;
}
.text-danger {
  color: #ef5350 !important;
}
.text-success {
  color: #26a69a !important;
}
</style>
