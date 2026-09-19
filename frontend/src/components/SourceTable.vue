<template>
  <div class="source-table card">
    <div class="header">
      <h3>Layer 1: Source Reliability & Pre-Filtering</h3>
      <span class="subtext">EMA Reputation · Staleness Filter · Diversity Quorum (min 3)</span>
    </div>
    <div class="table-container">
      <table>
        <thead>
          <tr>
            <th>Source Venue</th>
            <th>Address</th>
            <th>Venue ID</th>
            <th>Last Reported</th>
            <th>Reputation Score</th>
            <th>Filter Status</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="source in sources" :key="source.id" :class="{ 'excluded-row': !source.active || source.last_reported_price > 140 }">
            <td class="name-cell">
              <strong>{{ source.name }}</strong>
            </td>
            <td class="mono-cell">{{ source.address.slice(0, 8) }}...{{ source.address.slice(-6) }}</td>
            <td><span class="tag">Venue {{ source.venue_id }}</span></td>
            <td class="price-cell">
              ${{ (source.last_reported_price || 100).toFixed(2) }}
            </td>
            <td>
              <div class="rep-bar-container">
                <div class="rep-bar" :style="{ width: (source.reputation * 100) + '%', background: getRepColor(source.reputation) }"></div>
                <span class="rep-val">{{ (source.reputation * 100).toFixed(1) }}%</span>
              </div>
            </td>
            <td>
              <span v-if="!source.active" class="status-tag tag-stale">STALE EXCLUDED</span>
              <span v-else-if="source.last_reported_price > 140" class="status-tag tag-outlier">OUTLIER EXCLUDED</span>
              <span v-else class="status-tag tag-active">ACTIVE / WEIGHTED</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
defineProps({
  sources: {
    type: Array,
    default: () => []
  }
})

function getRepColor(rep) {
  if (rep >= 0.8) return '#26a69a'
  if (rep >= 0.5) return '#ffb300'
  return '#ef5350'
}
</script>

<style scoped>
.source-table {
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
.table-container {
  overflow-x: auto;
}
table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
}
th {
  color: #787b86;
  font-size: 0.75rem;
  padding: 10px 14px;
  border-bottom: 1px solid #2a2e39;
  text-transform: uppercase;
}
td {
  padding: 12px 14px;
  border-bottom: 1px solid #242832;
  color: #d1d4dc;
  font-size: 0.9rem;
}
.mono-cell {
  font-family: monospace;
  color: #848e9c;
}
.price-cell {
  font-weight: 600;
  color: #e0e3eb;
}
.tag {
  background: #131722;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 0.75rem;
  color: #2962ff;
  border: 1px solid #2962ff44;
}
.rep-bar-container {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 140px;
}
.rep-bar {
  height: 6px;
  border-radius: 3px;
}
.rep-val {
  font-size: 0.8rem;
  color: #b2b5be;
}
.status-tag {
  font-size: 0.7rem;
  font-weight: 700;
  padding: 4px 8px;
  border-radius: 4px;
}
.tag-active {
  background: rgba(38, 166, 154, 0.15);
  color: #26a69a;
}
.tag-stale {
  background: rgba(255, 179, 0, 0.15);
  color: #ffb300;
}
.tag-outlier {
  background: rgba(239, 83, 80, 0.15);
  color: #ef5350;
}
.excluded-row {
  background: rgba(239, 83, 80, 0.05);
}
</style>
