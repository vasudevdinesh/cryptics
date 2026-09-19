import axios from 'axios'

const API_BASE = 'http://127.0.0.1:5000/api'

export const api = {
  getHealth: () => axios.get(`${API_BASE}/health`),
  getSources: () => axios.get(`${API_BASE}/sources`),
  getRounds: () => axios.get(`${API_BASE}/tiers/rounds`),
  getCurrentRound: () => axios.get(`${API_BASE}/tiers/rounds/current`),
  getJurors: () => axios.get(`${API_BASE}/disputes/jurors`),
  getDisputes: () => axios.get(`${API_BASE}/disputes`),
  getEvents: () => axios.get(`${API_BASE}/demo/events`),
  resetDemo: () => axios.post(`${API_BASE}/demo/reset`),
  runRound1: () => axios.post(`${API_BASE}/demo/round1`),
  runRound2: () => axios.post(`${API_BASE}/demo/round2`),
  runRound3: () => axios.post(`${API_BASE}/demo/round3`),
  runRound4: () => axios.post(`${API_BASE}/demo/round4`),
}
