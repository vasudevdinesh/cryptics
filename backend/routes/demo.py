from flask import Blueprint, jsonify, request
from models import db, Source, Juror, PriceRound, Dispute, JurorVote, EventLog
from datetime import datetime, timedelta

demo_bp = Blueprint("demo", __name__, url_prefix="/api/demo")

@demo_bp.route("/events", methods=["GET"])
def get_events():
    events = EventLog.query.order_by(EventLog.id.desc()).limit(30).all()
    return jsonify([e.to_dict() for e in events])

@demo_bp.route("/reset", methods=["POST"])
def reset_demo():
    db.drop_all()
    db.create_all()

    # Seed Initial Sources (Layer 1)
    sources = [
        Source(address="0x1111111111111111111111111111111111111111", name="Coinbase Prime", venue_id=1, reputation=0.92, last_reported_price=100.0, total_reports=142),
        Source(address="0x2222222222222222222222222222222222222222", name="Binance Institutional", venue_id=2, reputation=0.89, last_reported_price=100.1, total_reports=138),
        Source(address="0x3333333333333333333333333333333333333333", name="Kraken Pro", venue_id=3, reputation=0.88, last_reported_price=99.9, total_reports=135),
        Source(address="0x4444444444444444444444444444444444444444", name="OKX OTC", venue_id=4, reputation=0.75, last_reported_price=100.0, total_reports=98),
        Source(address="0x5555555555555555555555555555555555555555", name="Deribit Index", venue_id=5, reputation=0.81, last_reported_price=100.2, total_reports=110),
    ]
    db.session.add_all(sources)

    # Seed Jurors (Layer 3)
    jurors = [
        Juror(address="0xAAAA11111111111111111111111111111111AAAA", name="Juror Alpha (Honest)", bond=10.0, weight=1.85, vested_weight=1.85, total_disputes=12),
        Juror(address="0xBBBB22222222222222222222222222222222BBBB", name="Juror Beta (Honest)", bond=8.5, weight=1.60, vested_weight=1.55, total_disputes=9),
        Juror(address="0xCCCC33333333333333333333333333333333CCCC", name="Juror Gamma (Honest)", bond=5.0, weight=1.20, vested_weight=1.20, total_disputes=6),
        Juror(address="0xDDDD44444444444444444444444444444444DDDD", name="Juror Delta (Honest)", bond=5.0, weight=1.15, vested_weight=1.10, total_disputes=5),
        Juror(address="0xEEEE55555555555555555555555555555555EEEE", name="Juror Adversary (Scripted Liar)", bond=6.0, weight=1.45, vested_weight=1.40, total_disputes=8),
    ]
    db.session.add_all(jurors)

    # Initial Round 0
    r0 = PriceRound(
        id=0,
        candidate_price=100.0,
        current_price=100.0,
        tier=0,
        deviation=0.0,
        status="Initial",
        resolved_price=100.0
    )
    db.session.add(r0)

    log = EventLog(
        layer="System",
        event_name="SystemInitialized",
        message="RWJO v4 System Initialized with 5 data sources, 5 bonded jurors, and base price $100.00",
        severity="success"
    )
    db.session.add(log)
    db.session.commit()

    return jsonify({"status": "success", "message": "Demo state reset to initial"})

@demo_bp.route("/round1", methods=["POST"])
def run_round_1():
    """Round 1: Clean Tier 0 Flow (No intervention, normal aggregation)"""
    sources = Source.query.all()
    prices = [100.0, 100.2, 99.9, 100.1, 100.0]
    for i, s in enumerate(sources):
        s.last_reported_price = prices[i]
        s.last_update = datetime.utcnow()
        s.active = True
        s.total_reports += 1

    median_price = 100.05
    round_obj = PriceRound(
        candidate_price=median_price,
        current_price=100.0,
        tier=0,
        deviation=0.0005,
        status="Normal Flow",
        resolved_price=median_price
    )
    db.session.add(round_obj)

    db.session.add(EventLog(layer="Layer 1", event_name="QuorumVerified", message="Diversity check passed: 5 independent venues (min 3).", severity="info"))
    db.session.add(EventLog(layer="Layer 1", event_name="AggregateComputed", message=f"Weighted median computed: ${median_price:.2f}. Zero sources excluded.", severity="info"))
    db.session.add(EventLog(layer="Layer 2", event_name="TierClassified", message="Tier 0: Normal flow (deviation 0.05% < θ₁ 3.0%). OSM reads cleanly, no halt.", severity="success"))
    db.session.commit()

    return jsonify({"round": round_obj.to_dict(), "message": "Round 1 executed: Clean Tier 0 flow"})

@demo_bp.route("/round2", methods=["POST"])
def run_round_2():
    """Round 2: Tier 1 - Stale/Outlier Filtered Upstream, Soft-Cap Holds, No Halt"""
    sources = Source.query.all()
    # Source 4 stale, Source 5 outlier ($150)
    sources[0].last_reported_price = 106.0
    sources[1].last_reported_price = 106.2
    sources[2].last_reported_price = 105.9
    
    # Source 4 made stale (update 3 hours ago)
    sources[3].last_update = datetime.utcnow() - timedelta(hours=3)
    sources[3].active = False
    
    # Source 5 reported extreme outlier
    sources[4].last_reported_price = 150.0
    sources[4].reputation = max(0.1, sources[4].reputation - 0.05)

    median_unfiltered = 106.0
    soft_capped_price = 105.0 # Clamped from 106 to 105 (5% max rate-of-change)

    round_obj = PriceRound(
        candidate_price=median_unfiltered,
        current_price=100.0,
        tier=1,
        deviation=0.06,
        status="Tier 1 Soft-Capped",
        resolved_price=soft_capped_price
    )
    db.session.add(round_obj)

    db.session.add(EventLog(layer="Layer 1", event_name="SourceExcluded", message="OKX OTC excluded: Data stale (> 1 hour without update).", severity="warning"))
    db.session.add(EventLog(layer="Layer 1", event_name="SourceExcluded", message="Deribit Index excluded: Outlier detected ($150.00 vs $106.00 preliminary median).", severity="warning"))
    db.session.add(EventLog(layer="Layer 2", event_name="TierClassified", message="Tier 1: Moderate deviation (6.0% between θ₁ 3% and θ₂ 10%). Spot-check initiated in hop window.", severity="warning"))
    db.session.add(EventLog(layer="Layer 2", event_name="SpotCheckPassed", message="Lightweight 3-juror spot check approved (3/3 votes).", severity="info"))
    db.session.add(EventLog(layer="Layer 2", event_name="SoftCapApplied", message=f"SoftCapController bounded candidate price $106.00 to $105.00 (+5.0% max limit). NO HALT.", severity="success"))
    db.session.commit()

    return jsonify({"round": round_obj.to_dict(), "message": "Round 2 executed: Tier 1 soft-capped, no halt"})

@demo_bp.route("/round3", methods=["POST"])
def run_round_3():
    """Round 3: Tier 2 - Critical Deviation, Halt, Commit-Reveal Jury, Honeypot Catch & Slashing"""
    manipulated_price = 128.0
    current_p = 105.0
    dev = (manipulated_price - current_p) / current_p # ~21.9% deviation >= 10% halt threshold

    round_obj = PriceRound(
        candidate_price=manipulated_price,
        current_price=current_p,
        tier=2,
        deviation=dev,
        status="Halted & Disputed",
        resolved_price=106.5
    )
    db.session.add(round_obj)
    db.session.flush()

    dispute = Dispute(
        round_id=round_obj.id,
        phase="Resolved",
        disputed_price=manipulated_price,
        resolved_price=106.5,
        is_honeypot=True,
        honeypot_true_price=106.0
    )
    db.session.add(dispute)
    db.session.flush()

    # Jurors Alpha, Beta, Gamma, Delta, Adversary
    jurors = Juror.query.all()
    votes = [
        JurorVote(dispute_id=dispute.id, juror_address=jurors[0].address, revealed_price=106.1, peer_prediction=106.2, score=0.96, was_slashed=False),
        JurorVote(dispute_id=dispute.id, juror_address=jurors[1].address, revealed_price=106.0, peer_prediction=106.0, score=0.98, was_slashed=False),
        JurorVote(dispute_id=dispute.id, juror_address=jurors[2].address, revealed_price=106.4, peer_prediction=106.3, score=0.93, was_slashed=False),
        JurorVote(dispute_id=dispute.id, juror_address=jurors[3].address, revealed_price=106.2, peer_prediction=106.1, score=0.95, was_slashed=False),
        # Lying adversary
        JurorVote(dispute_id=dispute.id, juror_address=jurors[4].address, revealed_price=127.5, peer_prediction=127.0, score=0.12, was_slashed=True),
    ]
    db.session.add_all(votes)

    # Slash the liar and drop weight
    jurors[4].bond = max(0.0, jurors[4].bond * 0.70) # 30% slashed
    jurors[4].slashed_amount += 1.8 # ETH slashed
    jurors[4].weight = 0.15 # Demoted toward WEIGHT_MIN
    jurors[4].vested_weight = 0.15

    # Reward honest jurors slightly
    for j in jurors[:4]:
        j.weight = min(5.0, j.weight + 0.12)
        j.total_disputes += 1

    db.session.add(EventLog(layer="Layer 2", event_name="HaltTriggered", message="Tier 2: CRITICAL deviation (21.9% >= θ₂ 10.0%). Deviation-margin halt engaged! Routed to Layer 3 RWJO.", severity="danger"))
    db.session.add(EventLog(layer="Layer 3", event_name="JurySelected", message="VRF drawn 5-juror bonded panel with commit-reveal privacy.", severity="info"))
    db.session.add(EventLog(layer="Layer 3", event_name="VotesRevealed", message="4 honest jurors revealed ~$106.10; Juror Adversary submitted manipulated $127.50.", severity="warning"))
    db.session.add(EventLog(layer="Layer 3", event_name="HoneypotTriggered", message="HONEYPOT REVEALED: Known ground truth was $106.00. Juror Adversary failed tolerance (20.3% error).", severity="danger"))
    db.session.add(EventLog(layer="Layer 3", event_name="JurorSlashed", message="Juror Adversary SLASHED 30% of bond (1.80 ETH) and reputation demoted from 1.45 to 0.15.", severity="danger"))
    db.session.add(EventLog(layer="Layer 3", event_name="DisputeResolved", message="Trimmed peer-prediction median resolved price: $106.50. Dispute lifted.", severity="success"))
    db.session.commit()

    return jsonify({"round": round_obj.to_dict(), "dispute": dispute.to_dict(), "message": "Round 3 executed: Tier 2 dispute resolved, liar caught & slashed"})

@demo_bp.route("/round4", methods=["POST"])
def run_round_4():
    """Round 4: Diminished Influence + Deviation Cap Clamping Large Swing"""
    current_p = 106.5
    large_swing_jury = 135.0 # Attempted 26.8% swing
    clamped_price = 122.47 # DeviationCap clamps to maxDeviation (15%) = 106.5 * 1.15

    round_obj = PriceRound(
        candidate_price=large_swing_jury,
        current_price=current_p,
        tier=2,
        deviation=0.268,
        status="Deviation Capped",
        resolved_price=clamped_price
    )
    db.session.add(round_obj)

    db.session.add(EventLog(layer="Layer 3", event_name="DiminishedInfluence", message="Juror Adversary attempted dishonest submission, but weight (0.15 vs 1.97) carried <2% voting power.", severity="info"))
    db.session.add(EventLog(layer="Layer 3", event_name="DeviationCapApplied", message=f"DeviationCap enforced hard structural ceiling: Clamped $135.00 to $122.47 (max 15.0% move). Attacker profit structurally bounded!", severity="success"))
    db.session.commit()

    return jsonify({"round": round_obj.to_dict(), "message": "Round 4 executed: Diminished influence + DeviationCap ceiling demonstrated"})
