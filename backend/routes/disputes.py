from flask import Blueprint, jsonify
from models import Juror, Dispute, JurorVote

disputes_bp = Blueprint("disputes", __name__, url_prefix="/api/disputes")

@disputes_bp.route("/jurors", methods=["GET"])
def get_jurors():
    jurors = Juror.query.all()
    return jsonify([j.to_dict() for j in jurors])

@disputes_bp.route("", methods=["GET"])
def get_disputes():
    disputes = Dispute.query.order_by(Dispute.id.desc()).all()
    return jsonify([d.to_dict() for d in disputes])

@disputes_bp.route("/<int:dispute_id>/votes", methods=["GET"])
def get_dispute_votes(dispute_id):
    votes = JurorVote.query.filter_by(dispute_id=dispute_id).all()
    return jsonify([v.to_dict() for v in votes])
