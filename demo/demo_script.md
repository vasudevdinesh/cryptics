# RWJO v4 — Rehearsed Live Demo Script

*Step-by-step walkthrough for judges and evaluators demonstrating the 3-Layer Reliability Architecture in under 2 minutes.*

---

## Pitch Narrative Structure

"Today, oracles face a fundamental trilemma: either you trust a multi-sig, or you suffer excessive latency, or an outage halts your entire protocol. 

**RWJO v4** introduces a three-layer reliability model around RWAUSD's existing pipeline without touching Maker Vat or Spot:
1. **Layer 1: Source Reliability** filters dirty data upstream.
2. **Layer 2: Tiered Response** replaces binary halts with graduated, soft-capped responses absorbed inside the existing `hop` window.
3. **Layer 3: RWJO Dispute Resolution** uses bonded peer-prediction jurors with honeypots and hard deviation caps only when a true crisis hits."

---

## Round-by-Round Demo Walkthrough

### Round 1: Clean Tier 0 Flow (Normal Pipeline)
- **What happens:** 5 independent off-chain venues (Coinbase, Binance, Kraken, OKX, Deribit) report consistent prices around \$100.00.
- **On Screen:**
  - Layer 1 Source Table shows all 5 sources Active with high reputation scores (>80%).
  - Layer 2 Tier Gauge points to **Tier 0: Normal Flow** (deviation < 3%).
  - **Adapter** serves \$100.05 directly from OSM without delay.
- **Judge Takeaway:** In 99% of normal trading conditions, RWJO adds **zero latency** and **zero gas overhead**.

### Round 2: Tier 1 Moderate Deviation (Soft-Cap & Pre-Filtering, NO HALT)
- **Action:** Click **Step 2: Round 2: Tier 1 Soft-Cap**.
- **What happens:**
  - OKX goes stale (no update for >1 hr) → **Layer 1 immediately excludes it**.
  - Deribit erroneously spikes to \$150.00 → **Layer 1 detects outlier and excludes it pre-median**.
  - Remaining 3 clean sources yield \$106.00 (+6% deviation).
  - Layer 2 classifies this as **Tier 1 (Moderate)**: between $\theta_1$ (3%) and $\theta_2$ (10%).
  - **SoftCapController** bounds price movement to +5.0% (\$105.00), absorbing the check inside the existing `hop` window.
- **On Screen:**
  - OKX shows `STALE EXCLUDED` (yellow).
  - Deribit shows `OUTLIER EXCLUDED` (red).
  - Tier Indicator transitions to **Tier 1 (Yellow)**.
  - Resolved price is soft-capped to \$105.00.
  - Event log verifies: **"NO PROTOCOL HALT"**.
- **Judge Takeaway:** Stale feeds and single-source outliers are neutralized upstream. Moderate volatility is soft-capped without halting protocol liquidations.

### Round 3: Tier 2 Severe Deviation (Halt, Honeypot Catch & Slashing)
- **Action:** Click **Step 3: Round 3: Tier 2 Dispute**.
- **What happens:**
  - An attacker injects a catastrophic price manipulation (+21.9% deviation, \$128.00).
  - Layer 2 triggers the deviation-margin halt $\theta_2$ (10%) and hands off to **Layer 3 RWJO**.
  - Chainlink VRF selects a bonded 5-juror panel with commit-reveal privacy.
  - System injects a hidden **Honeypot** round with ground truth \$106.00.
  - Honest jurors Alpha, Beta, Gamma, Delta reveal honest prices around \$106.10.
  - Scripted **Juror Adversary** votes \$127.50 to support the attack.
  - Dispute resolves: Honeypot triggers, liar fails tolerance.
- **On Screen:**
  - Tier Gauge jumps to **Tier 2: Critical (Red)**.
  - Juror Adversary card lights up with **"SLASHED"** badge.
  - 1.80 ETH (30% of bond) slashed.
  - Adversary reputation weight collapsed from 1.45x down to 0.15x.
  - Dispute lifts with clean resolved price: \$106.50.
- **Judge Takeaway:** Attackers cannot collude or vote average blindly. Peer-prediction plus active honeypots catch dishonest jurors and burn their capital.

### Round 4: Diminished Influence & Hard Deviation Cap Ceiling
- **Action:** Click **Step 4: Round 4: Deviation Cap**.
- **What happens:**
  - A subsequent round tests if the slashed adversary can still influence the market.
  - Their voting weight (0.15x vs ~2.0x for honest jurors) yields <2% influence.
  - Furthermore, even if an entire jury were somehow corrupted to approve a +26.8% swing (\$135.00), the contract-level **DeviationCap** clamps the movement to a hard maximum 15.0% (\$122.47).
- **On Screen:**
  - Adversary's weight remains suppressed.
  - Clamping message shows **DeviationCap Applied: Max 15% move enforced**.
  - Attacker profit is structurally bounded regardless of capital.
- **Judge Takeaway:** Sybil resistance, reputation decay, and hard structural caps ensure the oracle remains un-drainable even under extreme stress.
