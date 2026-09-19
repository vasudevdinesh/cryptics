<template>
  <div class="tier-indicator card">
    <div class="header">
      <h3>Layer 2: Tiered Response & In-Window Triage</h3>
      <span class="subtext">θ₁ = 3.0% · θ₂ = 10.0% (Halt Margin) · Soft-Cap = 5.0%</span>
    </div>
    
    <div class="tier-gauge">
      <div class="gauge-track">
        <div class="zone normal-zone" style="width: 30%;">
          <span>Tier 0 (&lt;3%)</span>
        </div>
        <div class="zone moderate-zone" style="width: 40%;">
          <span>Tier 1 Soft-Cap (3-10%)</span>
        </div>
        <div class="zone critical-zone" style="width: 30%;">
          <span>Tier 2 Halt (&gt;10%)</span>
        </div>
      </div>
      <div class="current-marker" :style="{ left: markerPosition + '%' }">
        <div class="pin"></div>
        <div class="marker-label">{{ (round.deviation * 100).toFixed(1) }}% Dev</div>
      </div>
    </div>

    <div class="explanation-box">
      <div v-if="round.tier === 0" class="explanation tier-0-exp">
        <strong>Tier 0 Active:</strong> Deviation is within normal market noise. Standard pipeline flows directly through OSM into Vat/Spot without delay or friction.
      </div>
      <div v-else-if="round.tier === 1" class="explanation tier-1-exp">
        <strong>Tier 1 Active:</strong> Moderate deviation detected. <strong>SoftCapController</strong> bounds price velocity to +5.0% max per hop. Lightweight 3-juror spot-check executes <em>inside</em> the existing hop window. <strong>NO PROTOCOL HALT.</strong>
      </div>
      <div v-else class="explanation tier-2-exp">
        <strong>Tier 2 Active:</strong> Critical deviation exceeds safety margin (&gt;10.0%). Deviation-margin halt fires. Price routed to <strong>Layer 3 RWJO Dispute Resolution</strong>.
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  round: {
    type: Object,
    default: () => ({ deviation: 0, tier: 0 })
  }
})

const markerPosition = computed(() => {
  const dev = props.round.deviation || 0
  // Map 0 -> 0%, 0.03 -> 30%, 0.10 -> 70%, 0.25 -> 95%
  if (dev < 0.03) {
    return Math.max(5, (dev / 0.03) * 30)
  } else if (dev < 0.10) {
    return 30 + ((dev - 0.03) / 0.07) * 40
  } else {
    return Math.min(95, 70 + ((dev - 0.10) / 0.15) * 25)
  }
})
</script>

<style scoped>
.tier-indicator {
  background: #1e222d;
  border-radius: 12px;
  padding: 20px;
  border: 1px solid #2a2e39;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 24px;
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
.tier-gauge {
  position: relative;
  margin: 20px 0 35px 0;
}
.gauge-track {
  height: 24px;
  border-radius: 12px;
  display: flex;
  overflow: hidden;
}
.zone {
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 700;
  color: #131722;
}
.normal-zone {
  background: #26a69a;
}
.moderate-zone {
  background: #ffb300;
}
.critical-zone {
  background: #ef5350;
}
.current-marker {
  position: absolute;
  top: -10px;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  transition: left 0.4s ease;
}
.pin {
  width: 14px;
  height: 14px;
  background: #ffffff;
  border-radius: 50%;
  border: 3px solid #2962ff;
  box-shadow: 0 0 8px rgba(0,0,0,0.6);
}
.marker-label {
  margin-top: 24px;
  font-size: 0.75rem;
  font-weight: 700;
  background: #131722;
  color: #f0f3fa;
  padding: 2px 8px;
  border-radius: 4px;
  border: 1px solid #2a2e39;
  white-space: nowrap;
}
.explanation-box {
  margin-top: 16px;
}
.explanation {
  padding: 12px 16px;
  border-radius: 8px;
  font-size: 0.9rem;
  line-height: 1.4;
}
.tier-0-exp {
  background: rgba(38, 166, 154, 0.1);
  color: #80cbc4;
  border-left: 4px solid #26a69a;
}
.tier-1-exp {
  background: rgba(255, 179, 0, 0.1);
  color: #ffe082;
  border-left: 4px solid #ffb300;
}
.tier-2-exp {
  background: rgba(239, 83, 80, 0.1);
  color: #ef9a9a;
  border-left: 4px solid #ef5350;
}
</style>
