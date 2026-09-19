<template>
  <div class="app-container">
    <header class="navbar">
      <div class="brand">
        <div class="logo">RWJO v4</div>
        <div class="brand-text">
          <h1>Reputation-Weighted Jury Oracle</h1>
          <span class="subtitle">Source Reliability + Tiered Response + Dispute Resolution (3-Layer Reliability Architecture)</span>
        </div>
      </div>
      <div class="system-status">
        <span class="pulse-dot"></span>
        <span>Local Foundry Engine Active (Port 5000 / 8545)</span>
      </div>
    </header>

    <main class="dashboard-body">
      <!-- 1. Interactive Demo Controls at the Top -->
      <DemoControls 
        :loading="loading" 
        :current-round-id="currentRound.id"
        @run-round="handleRunRound" 
        @reset="handleReset" 
      />

      <!-- 2. System Status & Price Panel -->
      <StatusPanel :round="currentRound" />

      <!-- 3. Layer 2 Tiered Response Gauge -->
      <TierIndicator :round="currentRound" />

      <!-- 4. Two Column Layout: Layer 1 Sources & Layer 3 Jurors -->
      <div class="split-grid">
        <SourceTable :sources="sources" />
        <JuryPanel :jurors="jurors" :dispute-active="currentRound.tier === 2" />
      </div>

      <!-- 5. Real-Time Event Log Stream -->
      <EventLog :events="events" />
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from './services/api'
import StatusPanel from './components/StatusPanel.vue'
import SourceTable from './components/SourceTable.vue'
import TierIndicator from './components/TierIndicator.vue'
import JuryPanel from './components/JuryPanel.vue'
import DemoControls from './components/DemoControls.vue'
import EventLog from './components/EventLog.vue'

const loading = ref(false)
const sources = ref([])
const jurors = ref([])
const currentRound = ref({
  id: 0,
  candidate_price: 100,
  current_price: 100,
  tier: 0,
  tier_label: 'Tier 0: Normal',
  deviation: 0,
  status: 'Normal Flow',
  resolved_price: 100
})
const events = ref([])

async function fetchData() {
  try {
    const [srcRes, jurRes, rndRes, evtRes] = await Promise.all([
      api.getSources(),
      api.getJurors(),
      api.getCurrentRound(),
      api.getEvents()
    ])
    sources.value = srcRes.data
    jurors.value = jurRes.data
    currentRound.value = rndRes.data
    events.value = evtRes.data
  } catch (err) {
    console.error('Failed to refresh data:', err)
  }
}

async function handleRunRound(roundNum) {
  loading.value = true
  try {
    if (roundNum === 1) await api.runRound1()
    else if (roundNum === 2) await api.runRound2()
    else if (roundNum === 3) await api.runRound3()
    else if (roundNum === 4) await api.runRound4()
    await fetchData()
  } catch (err) {
    console.error(`Error running round ${roundNum}:`, err)
  } finally {
    loading.value = false
  }
}

async function handleReset() {
  loading.value = true
  try {
    await api.resetDemo()
    await fetchData()
  } catch (err) {
    console.error('Error resetting demo:', err)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchData()
  // Refresh events every 3 seconds
  setInterval(fetchData, 3000)
})
</script>

<style>
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
body {
  background-color: #131722;
  color: #d1d4dc;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  line-height: 1.5;
}
.app-container {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.navbar {
  background: #1e222d;
  border-bottom: 1px solid #2a2e39;
  padding: 16px 28px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.brand {
  display: flex;
  align-items: center;
  gap: 16px;
}
.logo {
  background: #2962ff;
  color: white;
  font-weight: 900;
  font-size: 1.1rem;
  padding: 8px 14px;
  border-radius: 8px;
  letter-spacing: 1px;
}
.brand-text h1 {
  font-size: 1.25rem;
  color: #f0f3fa;
  font-weight: 700;
}
.subtitle {
  font-size: 0.8rem;
  color: #787b86;
}
.system-status {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #131722;
  padding: 8px 14px;
  border-radius: 20px;
  border: 1px solid #2a2e39;
  font-size: 0.8rem;
  color: #848e9c;
}
.pulse-dot {
  width: 8px;
  height: 8px;
  background: #26a69a;
  border-radius: 50%;
  box-shadow: 0 0 8px #26a69a;
}
.dashboard-body {
  padding: 24px 28px;
  display: flex;
  flex-direction: column;
  gap: 20px;
  max-width: 1600px;
  margin: 0 auto;
  width: 100%;
}
.split-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}
@media (max-width: 1100px) {
  .split-grid {
    grid-template-columns: 1fr;
  }
}
</style>
