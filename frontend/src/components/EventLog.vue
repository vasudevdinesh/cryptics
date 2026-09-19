<template>
  <div class="event-log card">
    <div class="header">
      <h3>Live Verification & Contract Event Stream</h3>
      <span class="subtext">Real-time emit notifications from Layer 1, 2, and 3 contracts</span>
    </div>

    <div class="log-container">
      <div v-if="events.length === 0" class="empty-state">
        No events emitted yet. Trigger a round above to view verification logs.
      </div>
      <div 
        v-for="e in events" 
        :key="e.id" 
        class="log-row"
        :class="'severity-' + e.severity"
      >
        <span class="timestamp">[{{ e.timestamp }}]</span>
        <span class="layer-pill">{{ e.layer }}</span>
        <span class="event-name">{{ e.event_name }}:</span>
        <span class="message">{{ e.message }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  events: {
    type: Array,
    default: () => []
  }
})
</script>

<style scoped>
.event-log {
  background: #1e222d;
  border-radius: 12px;
  padding: 20px;
  border: 1px solid #2a2e39;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 16px;
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
.log-container {
  background: #131722;
  border-radius: 8px;
  padding: 12px;
  max-height: 220px;
  overflow-y: auto;
  font-family: monospace;
  font-size: 0.8rem;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.empty-state {
  color: #787b86;
  text-align: center;
  padding: 20px;
}
.log-row {
  display: flex;
  align-items: center;
  gap: 10px;
  line-height: 1.4;
  padding: 4px 8px;
  border-radius: 4px;
}
.timestamp {
  color: #787b86;
  flex-shrink: 0;
}
.layer-pill {
  font-size: 0.7rem;
  font-weight: 700;
  padding: 2px 6px;
  border-radius: 3px;
  background: #2a2e39;
  color: #d1d4dc;
  flex-shrink: 0;
}
.event-name {
  font-weight: 700;
  color: #e0e3eb;
  flex-shrink: 0;
}
.message {
  color: #b2b5be;
}
.severity-success {
  background: rgba(38, 166, 154, 0.08);
  border-left: 3px solid #26a69a;
}
.severity-warning {
  background: rgba(255, 179, 0, 0.08);
  border-left: 3px solid #ffb300;
}
.severity-danger {
  background: rgba(239, 83, 80, 0.08);
  border-left: 3px solid #ef5350;
}
.severity-info {
  background: rgba(41, 98, 255, 0.08);
  border-left: 3px solid #2962ff;
}
</style>
