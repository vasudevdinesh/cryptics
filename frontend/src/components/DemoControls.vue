<template>
  <div class="demo-controls card">
    <div class="header">
      <div>
        <h3>Interactive Demo Controller (Live Jury & Oracle Simulation)</h3>
        <span class="subtext">Step through the 4 core narrative rounds to test all 3 reliability layers</span>
      </div>
      <button class="btn btn-reset" @click="$emit('reset')" :disabled="loading">
        Reset Demo
      </button>
    </div>

    <div class="buttons-grid">
      <button class="btn btn-round" :class="{ active: currentRoundId === 1 }" @click="$emit('run-round', 1)" :disabled="loading">
        <span class="step-num">Step 1</span>
        <span class="step-title">Round 1: Clean Flow</span>
        <span class="step-desc">Tier 0 normal flow. 5 sources consistent, OSM serves price directly.</span>
      </button>

      <button class="btn btn-round" :class="{ active: currentRoundId === 2 }" @click="$emit('run-round', 2)" :disabled="loading">
        <span class="step-num">Step 2</span>
        <span class="step-title">Round 2: Tier 1 Soft-Cap</span>
        <span class="step-desc">Stale + outlier filtered in L1. SoftCap bounds +5% velocity in hop. NO HALT.</span>
      </button>

      <button class="btn btn-round" :class="{ active: currentRoundId === 3 }" @click="$emit('run-round', 3)" :disabled="loading">
        <span class="step-num">Step 3</span>
        <span class="step-title">Round 3: Tier 2 Dispute</span>
        <span class="step-desc">21% manipulation halt. VRF jury + honeypot catches scripted liar and slashes bond!</span>
      </button>

      <button class="btn btn-round" :class="{ active: currentRoundId === 4 }" @click="$emit('run-round', 4)" :disabled="loading">
        <span class="step-num">Step 4</span>
        <span class="step-title">Round 4: Deviation Cap</span>
        <span class="step-desc">Liar's influence diminished (<2%). DeviationCap clamps +26% swing to 15% max.</span>
      </button>
    </div>
  </div>
</template>

<script setup>
defineProps({
  loading: {
    type: Boolean,
    default: false
  },
  currentRoundId: {
    type: Number,
    default: 0
  }
})

defineEmits(['run-round', 'reset'])
</script>

<style scoped>
.demo-controls {
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
h3 {
  color: #f0f3fa;
  margin: 0;
  font-size: 1.1rem;
}
.subtext {
  font-size: 0.8rem;
  color: #787b86;
}
.buttons-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
}
.btn {
  cursor: pointer;
  border: none;
  border-radius: 8px;
  transition: all 0.2s ease;
  text-align: left;
}
.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.btn-reset {
  background: #2a2e39;
  color: #d1d4dc;
  padding: 8px 16px;
  font-weight: 600;
  font-size: 0.85rem;
}
.btn-reset:hover:not(:disabled) {
  background: #363c4e;
  color: #fff;
}
.btn-round {
  background: #131722;
  border: 1px solid #2a2e39;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.btn-round:hover:not(:disabled) {
  border-color: #2962ff;
  background: #181d2c;
  transform: translateY(-2px);
}
.btn-round.active {
  border-color: #2962ff;
  box-shadow: 0 0 12px rgba(41, 98, 255, 0.3);
  background: rgba(41, 98, 255, 0.08);
}
.step-num {
  font-size: 0.7rem;
  color: #2962ff;
  font-weight: 700;
  text-transform: uppercase;
}
.step-title {
  color: #f0f3fa;
  font-weight: 700;
  font-size: 0.95rem;
}
.step-desc {
  font-size: 0.75rem;
  color: #787b86;
  line-height: 1.3;
}
</style>
