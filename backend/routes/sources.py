from flask import Blueprint, jsonify, request
from models import db, Source, EventLog
from datetime import datetime

sources_bp = Blueprint("sources", __name__, url_prefix="/api/sources")

@sources_bp.route("", methods=["GET"])
def get_sources():
    sources = Source.query.all()
    return jsonify([s.to_dict() for s in sources])

@sources_bp.route("/<address>", methods=["GET"])
def get_source(address):
    source = Source.query.filter_by(address=address.lower()).first()
    if not source:
        return jsonify({"error": "Source not found"}), 404
    return jsonify(source.to_dict())

@sources_bp.route("/report", methods=["POST"])
def report_source_price():
    data = request.json or {}
    addr = data.get("address", "").lower()
    price = float(data.get("price", 0))
    
    source = Source.query.filter_by(address=addr).first()
    if not source:
        return jsonify({"error": "Source not found"}), 404
    
    source.last_reported_price = price
    source.last_update = datetime.utcnow()
    source.total_reports += 1
    db.session.commit()

    log = EventLog(
        layer="Layer 1",
        event_name="PriceReported",
        message=f"{source.name} reported price ${price:.2f}",
        severity="info"
    )
    db.session.add(log)
    db.session.commit()

    return jsonify(source.to_dict())
