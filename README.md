# RWJO v4 — Reputation-Weighted Jury Oracle

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Foundry-1.8.3-orange?logo=ethereum)](https://getfoundry.sh/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-v5.1.0-4E5EE4?logo=openzeppelin)](https://openzeppelin.com/)
[![Tests](https://img.shields.io/badge/Tests-20%2F20%20Passing-brightgreen)]()
[![Backend](https://img.shields.io/badge/Backend-Flask%20%7C%20web3.py%20%7C%20SQLAlchemy-black?logo=flask)](https://flask.palletsprojects.com/)
[![Frontend](https://img.shields.io/badge/Frontend-Vue.js%203%20%7C%20Vite%20%7C%20ethers.js-4FC08D?logo=vuedotjs)](https://vuejs.org/)
[![VRF](https://img.shields.io/badge/Chainlink-VRF%20v2.5-375BD2?logo=chainlink)](https://chain.link/vrf)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## What this is, in plain terms

RWJO v4 sits between raw price feeds (Coinbase, Binance, Kraken, OKX, Deribit) and a lending protocol that needs to know what an asset is worth right now. Getting that number wrong is costly in either direction:

- **Too trusting**, and someone can feed the protocol a fake price and drain collateral.
- **Too jumpy**, and the protocol freezes every time the market has a normal wobble — which locks users out and causes its own damage.

RWJO handles this by checking incoming price data through three checkpoints of increasing strictness, escalating to a slow, expensive process only when something actually looks wrong. On a normal day, prices flow through with almost no added delay. On a bad day, the system slows down, brings in independent reviewers, and caps how far any single price can move — no matter what those reviewers decide.

Critically, none of this requires touching the protocol's core settlement code (`Vat`, `Spot`). RWJO plugs in alongside it.

---

## The underlying problem

Anyone building a price feed for a financial protocol runs into the same three-way tension:

1. **Trust the data as-is** → fast, but an attacker only needs to corrupt one feed to move a price.
2. **Halt on any suspicious reading** → safe from bad data, but the protocol becomes unusable during ordinary volatility.
3. **React instantly to every change** → users can react in real time, but so can attackers, before anyone has a chance to notice something's wrong.

You can't fully eliminate all three risks at once. RWJO's approach is to make the *default path* cheap and fast, and reserve slow, careful scrutiny for the rare cases that actually warrant it.

---

## How it works — three checkpoints

Picture each incoming price like a passenger going through security. Most people walk straight through. A few get a closer look. A very small number get pulled aside for a full interview.

```
Exchanges (Coinbase, Binance, Kraken, OKX, Deribit)
                    │
                    ▼
┌──────────────────────────────────────────────┐
│ CHECKPOINT 1 — Are the messengers reliable?   │
│ Drop stale feeds, drop outliers, require      │
│ enough independent sources, track each        │
│ source's track record over time               │
└──────────────────────────────────────────────┘
                    │
                    ▼
        [One combined, trust-weighted price]
                    │
                    ▼
┌──────────────────────────────────────────────┐
│ CHECKPOINT 2 — How big is this move?          │
│ Small move  → let it through as normal        │
│ Medium move → dampen it, keep operating       │
│ Large move  → pause and escalate              │
└──────────────────────────────────────────────┘
                    │
             (only for large moves)
                    ▼
┌──────────────────────────────────────────────┐
│ CHECKPOINT 3 — Put it in front of reviewers   │
│ Randomly select a jury of bonded reviewers,   │
│ have them vote in secret, reward honesty,     │
│ punish collusion, and hard-cap the final      │
│ result regardless of the vote                 │
└──────────────────────────────────────────────┘
                    │
                    ▼
      Final price (bounded) → protocol reads it,
      completely unchanged from before
```

### Checkpoint 1 — Are the messengers reliable?

Before any price is used, RWJO looks at *who* reported it and *how trustworthy they've been*:

- **Stale data gets dropped.** If a source hasn't updated in over an hour, it's excluded from this round rather than treated as current.
- **Obvious outliers get dropped.** A price that's wildly out of line with everyone else is filtered out before it can skew the result.
- **Sources need to be genuinely independent.** A handful of feeds that are really just wrappers around the same underlying venue don't count as multiple confirmations — RWJO checks for real diversity of source, not just a headcount.
- **Reliability is tracked over time.** Each source earns or loses trust based on how accurate it's been historically, and the current price calculation weighs trustworthy sources more heavily than shaky ones.

The result of this stage is a single combined price, weighted so that consistently reliable sources count for more than flaky ones.

### Checkpoint 2 — How big a deal is this price move?

Once there's a combined price, RWJO asks a simple question: *compared to the last accepted price, how large is this move?*

| Size of move | What happens |
|---|---|
| Small (under 3%) | Passed straight through, no extra delay |
| Medium (3–10%) | Speed of the move is capped (max +5% per round) so the protocol keeps running, and a small independent panel double-checks it in the background |
| Large (10% or more) | The round is paused and escalated to full review (Checkpoint 3) |

The key idea: a medium-sized, plausible move doesn't need to freeze the whole protocol. It just gets throttled while a lightweight review happens, all inside the normal delay window the protocol already has before a price takes effect. Only genuinely extreme moves trigger a full stop.

### Checkpoint 3 — Full review by an independent jury

This only happens for the rare large moves. Here, RWJO brings in outside reviewers ("jurors") who have put up their own money as a bond — meaning they lose that money if they're caught lying.

- **Reviewers are chosen at random**, using a verifiable randomness source (Chainlink VRF) so no one can predict or rig who gets picked. Reviewers with a bigger bond and a better track record are more likely to be selected, which makes it expensive for an attacker to stack the jury.
- **Votes are sealed, then revealed.** Reviewers submit a hidden vote first, and only after everyone has committed do the votes get opened. This stops reviewers from simply copying whoever votes first.
- **Reviewers are scored on genuine research, not guessing the crowd.** Instead of being rewarded for matching the majority (which just encourages everyone to "vote the average" without doing any real work), reviewers are rewarded for predicting what their peers will independently report — which only works if they actually did the research.
- **Occasional test questions with a known answer.** Some rounds are secretly test cases where RWJO already knows the correct answer from an independent reference source. A reviewer who lies on one of these gets caught and penalized immediately.
- **Trust is earned slowly, lost instantly.** A reviewer's influence builds up gradually over time (so a sleeper account can't quietly farm reputation and then cash in on one big lie), but a caught lie costs them immediately.
- **A hard ceiling limits the damage either way.** Even in a worst case where the jury itself is compromised, the contract simply will not let the final price move more than 15% in one round. This caps how much an attacker could possibly gain, no matter how the vote goes.

---

## Component map

| Component | Checkpoint | What it does |
|---|---|---|
| [`SourceRegistry.sol`](contracts/src/layer1/SourceRegistry.sol) | 1 | Keeps a running trust score for each price source, updated a little after every report, and tracks how long it's been since each source last checked in. |
| [`SourceFilter.sol`](contracts/src/layer1/SourceFilter.sol) | 1 | Removes stale and outlier prices, then combines the rest into one trust-weighted price. |
| [`DiversityCheck.sol`](contracts/src/layer1/DiversityCheck.sol) | 1 | Confirms that enough of the remaining sources are genuinely independent, not just copies of the same underlying feed. |
| [`TierClassifier.sol`](contracts/src/layer2/TierClassifier.sol) | 2 | Decides whether a price move is small, medium, or large, and routes it accordingly. |
| [`SoftCapController.sol`](contracts/src/layer2/SoftCapController.sol) | 2 | Limits how fast a medium-sized move can take effect, without pausing the protocol. |
| [`SpotCheckPanel.sol`](contracts/src/layer2/SpotCheckPanel.sol) | 2 | A quick 3-reviewer sanity check that runs in the background during medium moves, inside the delay the protocol already has. |
| [`JurorRegistry.sol`](contracts/src/layer3/JurorRegistry.sol) | 3 | Manages the pool of bonded reviewers: who's registered, how much they've staked, and how their reputation changes over time. |
| [`RandomSelector.sol`](contracts/src/layer3/RandomSelector.sol) | 3 | Randomly picks reviewers for a large-move review, weighted by bond size and track record, using Chainlink VRF so the draw can't be predicted or gamed. |
| [`DisputeModule.sol`](contracts/src/layer3/DisputeModule.sol) | 3 | Runs the sealed-vote review process end to end, and makes sure a disputed price is never used as a fallback if the review is inconclusive. |
| [`HoneypotInjector.sol`](contracts/src/layer3/HoneypotInjector.sol) | 3 | Occasionally inserts a review round where the correct answer is already known, to catch reviewers who vote dishonestly. |
| [`DeviationCap.sol`](contracts/src/layer3/DeviationCap.sol) | 3 | A hard contract-level rule that no price can move more than 15% in one round, regardless of what the jury decides. |
| [`Adapter.sol`](contracts/src/Adapter.sol) | Bridge | Decides where to read the current price from: the full review process during a large-move dispute, the speed-limited price during a medium move, or the normal feed otherwise. |

---

## What each problem is solved by

| Risk | What happens without RWJO | How RWJO addresses it |
|---|---|---|
| **A source goes dark or stalls** | A stale price gets used as if it were current, or the protocol halts unnecessarily | Checkpoint 1 drops any source that hasn't reported recently, before it can affect the price |
| **One bad feed skews the price** | A single manipulated source pulls the average off course | Checkpoint 1 filters out statistical outliers and down-weights unreliable sources over time |
| **Every wobble causes a shutdown** | Binary halt/resume freezes the protocol on moderate, ordinary volatility | Checkpoint 2's speed limit smooths medium moves without stopping the protocol |
| **Reviewers just copy each other** | Whoever votes first sets the outcome for everyone else | Votes are sealed and only revealed after everyone has committed |
| **Reviewers vote the average instead of doing real work** | Nobody actually checks the true price; they just guess the consensus | Reviewers are scored on predicting independent peer reports, which requires real research |
| **An attacker floods the jury with cheap fake accounts** | Enough throwaway identities can outvote honest reviewers | Selection and voting power scale with bonded capital and earned reputation, making this expensive |
| **A reviewer quietly builds trust to cash in later** | A "sleeper" account behaves well for a while, then lies on a high-stakes round | Trust builds up gradually over time; a caught lie is penalized immediately |
| **A bribed majority tries to force a large price swing** | If the jury is compromised, the price can move as far as the jury wants | A hard contract-level ceiling caps any single move, no matter how the vote goes |

---

## Tech stack

- **Smart contracts:** Solidity `^0.8.24`, Foundry `v1.8.3`, OpenZeppelin Contracts `v5.1.0`, Chainlink VRF v2.5 (compiled with `via_ir = true`).
- **Backend API:** Python 3.12, Flask, Flask-CORS, SQLAlchemy (SQLite), `web3.py` v8.
- **Frontend dashboard:** Vue.js 3, Vite, `ethers.js` v6, Axios.

---

## Directory structure

```
rwjo-v4/
├── contracts/                     # Foundry smart contract suite
│   ├── src/
│   │   ├── interfaces/            # ISourceRegistry, ITierClassifier, IJurorRegistry, IResolvedPrice
│   │   ├── layer1/                # SourceRegistry, SourceFilter, DiversityCheck
│   │   ├── layer2/                # TierClassifier, SoftCapController, SpotCheckPanel
│   │   ├── layer3/                # JurorRegistry, RandomSelector, DisputeModule, HoneypotInjector, DeviationCap
│   │   ├── mocks/                 # MockOSM, MockVRFCoordinator
│   │   └── Adapter.sol            # Bridges RWJO into the protocol's price reads
│   ├── test/
│   │   ├── Layer1.t.sol           # Checkpoint 1 test suite (6 tests)
│   │   ├── Layer2.t.sol           # Checkpoint 2 test suite (6 tests)
│   │   ├── Layer3.t.sol           # Checkpoint 3 test suite (3 tests)
│   │   ├── Adapter.t.sol          # Adapter test suite (2 tests)
│   │   └── Integration.t.sol      # End-to-end 4-round integration test (3 tests)
│   ├── script/
│   │   └── Deploy.s.sol           # Automated deployment script
│   └── foundry.toml               # Solc 0.8.24 + via_ir configuration
├── backend/                       # Flask backend service
│   ├── app.py                     # Flask application factory
│   ├── config.py                  # Environment & blockchain config
│   ├── models.py                  # SQLAlchemy models (Sources, Jurors, Rounds, Disputes, Logs)
│   ├── routes/                    # API blueprints (sources, tiers, disputes, demo)
│   └── services/                  # web3.py integration and contract bindings
├── frontend/                      # Vue 3 dashboard
│   ├── src/
│   │   ├── components/            # StatusPanel, SourceTable, TierIndicator, JuryPanel, DemoControls, EventLog
│   │   ├── services/               # API client (Axios) & ethers.js bindings
│   │   └── App.vue                # Main dashboard layout
│   └── vite.config.js
├── demo/
│   └── demo_script.md             # Rehearsed 4-round presentation script
├── start.py                       # Single-command launcher for backend + frontend
└── README.md
```

---

## Getting started

### Prerequisites

- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/) (v18+) & `npm`
- [Python](https://python.org/) (v3.10+) & `pip`
- [Foundry](https://getfoundry.sh/) (`forge`, `anvil`)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/rwjo-v4.git
   cd rwjo-v4
   ```

2. **Set up the smart contracts (Foundry):**
   ```bash
   cd contracts
   npm install @openzeppelin/contracts@5.1.0
   git clone --depth 1 https://github.com/foundry-rs/forge-std.git lib/forge-std
   forge build
   ```

3. **Set up the backend:**
   ```bash
   cd ../backend
   pip install flask flask-cors flask-sqlalchemy sqlalchemy web3
   ```

4. **Set up the frontend:**
   ```bash
   cd ../frontend
   npm install
   ```

---

## Verification & testing

Run the full Foundry test suite:

```bash
cd contracts
forge test -vvv
```

### Test results summary

```text
Ran 5 test suites in 13.05ms: 20 tests passed, 0 failed, 0 skipped

[PASS] testNormalReadFromOSM() (gas: 30389)
[PASS] testReadWhenSoftCapActive() (gas: 125820)
[PASS] testDiversityCheck() (gas: 58842)
[PASS] testDiversityCheckFailsWithSameVenue() (gas: 191996)
[PASS] testOutlierExclusion() (gas: 128361)
[PASS] testReputationUpdate() (gas: 60465)
[PASS] testSourceRegistration() (gas: 19488)
[PASS] testStalenessExclusion() (gas: 254245)
[PASS] testSoftCapClamping() (gas: 100829)
[PASS] testSoftCapNoClampingUnderLimit() (gas: 79038)
[PASS] testSpotCheckPanelApproval() (gas: 495087)
[PASS] testTier0NormalClassification() (gas: 53595)
[PASS] testTier1ModerateClassification() (gas: 55995)
[PASS] testTier2CriticalClassification() (gas: 56019)
[PASS] testDeviationCapClamping() (gas: 55921)
[PASS] testHoneypotEvaluation() (gas: 166157)
[PASS] testJurorBondAndRegistration() (gas: 74135)
[PASS] testRound1_CleanTier0() (gas: 478720)
[PASS] testRound2_Tier1_FilteringAndSoftCap() (gas: 710812)
[PASS] testRound3_Tier2_HaltAndSlashing() (gas: 1818485)
```

---

## Running the interactive demo

Launch both the Flask API server and Vue 3 frontend with a single command:

```bash
python start.py
```

- **Dashboard:** [http://localhost:5173](http://localhost:5173)
- **Backend API:** [http://127.0.0.1:5000/api/health](http://127.0.0.1:5000/api/health)

---

## 4-round interactive walkthrough

The dashboard includes controls that walk through all three checkpoints live, in under two minutes.

| Step | What happens | What the contracts do | What you'll see |
|---|---|---|---|
| **Round 1 — Clean flow** | Five sources report consistent prices (~$100.00). | Checkpoint 2 classifies this as a small move. | Status badge turns **green**. The protocol reads the price directly, with no added delay. |
| **Round 2 — Medium move** | One source (Source 4) goes stale; another (Source 5) spikes to $150.00. | Checkpoint 1 drops both before combining prices; the remaining sources land at $106.00, a 6% move, so Checkpoint 2 classifies it as medium. | Status badge turns **yellow**. OKX is flagged `STALE EXCLUDED`, Deribit is flagged `OUTLIER EXCLUDED`. The price is speed-limited to $105.00 (+5% max). The protocol keeps running — **no halt**. |
| **Round 3 — Large move, full review** | An attacker injects a manipulated price of $128.00 (a +21.9% move). | This clears the large-move threshold (10%), so the round pauses and a 5-reviewer jury is randomly drawn; a hidden test round is included. | Status badge turns **red**. The scripted dishonest reviewer votes $127.50, but the test round reveals the true price ($106.00). **That reviewer loses 30% of their bond (1.8 ETH)** and their influence is reduced to a minimum. The price resolves cleanly to $106.50. |
| **Round 4 — Hard ceiling** | The same attacker tries again, but their vote now carries under 2% of the total weight. Even in the worst case where the *entire* jury were compromised and tried to push a +26.8% swing ($135.00)... | ...the contract-level cap still applies. | A clamping banner appears: **Clamped from $135.00 to $122.47 (+15% max move)**. However the vote goes, the attacker's possible gain is structurally bounded. |

---

## License

MIT © 2026 RWJO Contributors. Built for RWAUSD & DeFi Oracle Security.
