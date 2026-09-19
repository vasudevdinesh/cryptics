from flask import Blueprint, jsonify
from models import PriceRound

tiers_bp = Blueprint("tiers", __name__, url_prefix="/api/tiers")

@tiers_bp.route("/rounds", methods=["GET"])
def get_rounds():
    rounds = PriceRound.query.order_by(PriceRound.id.desc()).limit(20).all()
    return jsonify([r.to_dict() for r in rounds])

@tiers_bp.route("/rounds/current", methods=["GET"])
def get_current_round():
    current = PriceRound.query.order_by(PriceRound.id.desc()).first()
    if not current:
        return jsonify({
            "id": 0,
            "candidate_price": 100.0,
            "current_price": 100.0,
            "tier": 0,
            "tier_label": "Tier 0: Normal",
            "deviation": 0.0,
            "status": "Healthy",
            "resolved_price": 100.0
        })
    return jsonify(current.to_dict())
