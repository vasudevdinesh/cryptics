<template>
  <div class="jury-panel card">
    <div class="header">
      <div>
        <h3>Layer 3: RWJO Bonded Jury & Peer-Prediction</h3>
        <span class="subtext">Shared Cross-Protocol Jurors · Commit-Reveal · Honeypots · Slashing</span>
      </div>
      <div v-if="disputeActive" class="honeypot-badge">
        Honeypot Evaluation Active
      </div>
    </div>

    <div class="juror-grid">
      <div 
        v-for="juror in jurors" 
        :key="juror.id" 
        class="juror-card"
        :class="{ 'slashed-card': juror.slashed_amount > 0 }"
      >
        <div class="card-header">
          <span class="juror-name">{{ juror.name }}</span>
          <span v-if="juror.slashed_amount > 0" class="slash-badge">SLASHED</span>
          <span v-else class="active-badge">ACTIVE</span>
        </div>
        
        <div class="detail-row">
          <span class="lbl">Address:</span>
          <span class="val mono">{{ juror.address.slice(0, 6) }}...{{ juror.address.slice(-4) }}</span>
        </div>

        <div class="detail-row">
          <span class="lbl">Bonded Capital:</span>
          <span class="val bold" :class="{ 'text-danger': juror.slashed_amount > 0 }">
            {{ juror.bond.toFixed(2) }} ETH
          </span>
        </div>

        <div class="detail-row">
          <span class="lbl">Reputation Weight:</span>
          <div class="weight-track">
            <span class="val bold">{{ juror.weight.toFixed(2) }}x</span>
            <span class="subval">({{ (juror.weight / 5.0 * 100).toFixed(0) }}%)</span>
          </div>
        </div>

        <div class="detail-row">
          <span class="lbl">Vested Influence:</span>
          <span class="val">{{ juror.vested_weight.toFixed(2) }}x</span>
        </div>

        <div v-if="juror.slashed_amount > 0" class="slashed-info">
          <span>Penalty: -{{ juror.slashed_amount.toFixed(2) }} ETH (-30%)</span>
          <span class="demoted-txt">Weight demoted to minimum (0.15x)</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  jurors: {
    type: Array,
    default: () => []
  },
  disputeActive: {
    type: Boolean,
    default: false
  }
})
</script>

<style scoped>
.jury-panel {
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
.honeypot-badge {
  background: rgba(239, 83, 80, 0.15);
  color: #ef5350;
  border: 1px solid #ef5350;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}
.juror-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
  gap: 14px;
}
.juror-card {
  background: #131722;
  border: 1px solid #2a2e39;
  border-radius: 8px;
  padding: 14px;
  transition: all 0.3s ease;
}
.slashed-card {
  border: 1px solid #ef5350;
  background: rgba(239, 83, 80, 0.04);
}
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  border-bottom: 1px solid #242832;
  padding-bottom: 8px;
}
.juror-name {
  font-weight: 700;
  color: #f0f3fa;
  font-size: 0.85rem;
}
.slash-badge {
  background: #ef5350;
  color: white;
  font-size: 0.65rem;
  font-weight: 800;
  padding: 2px 6px;
  border-radius: 4px;
}
.active-badge {
  background: rgba(38, 166, 154, 0.2);
  color: #26a69a;
  font-size: 0.65rem;
  font-weight: 700;
  padding: 2px 6px;
  border-radius: 4px;
}
.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  font-size: 0.8rem;
}
.lbl {
  color: #787b86;
}
.val {
  color: #d1d4dc;
}
.mono {
  font-family: monospace;
}
.bold {
  font-weight: 700;
}
.weight-track {
  display: flex;
  align-items: center;
  gap: 4px;
}
.subval {
  font-size: 0.7rem;
  color: #787b86;
}
.slashed-info {
  margin-top: 10px;
  padding-top: 8px;
  border-top: 1px dashed #ef535044;
  display: flex;
  flex-direction: column;
  gap: 2px;
  font-size: 0.75rem;
  color: #ef5350;
  font-weight: 600;
}
.demoted-txt {
  font-size: 0.7rem;
  color: #b2b5be;
  font-weight: normal;
}
</style>
