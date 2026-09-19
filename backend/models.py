from datetime import datetime
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class Source(db.Model):
    __tablename__ = "sources"
    id = db.Column(db.Integer, primary_key=True)
    address = db.Column(db.String(42), unique=True, nullable=False)
    name = db.Column(db.String(64), nullable=True)
    venue_id = db.Column(db.Integer, default=1)
    reputation = db.Column(db.Float, default=0.5) # Scaled to float [0.1, 1.0]
    last_reported_price = db.Column(db.Float, nullable=True)
    last_update = db.Column(db.DateTime, default=datetime.utcnow)
    active = db.Column(db.Boolean, default=True)
    total_reports = db.Column(db.Integer, default=0)

    def to_dict(self):
        return {
            "id": self.id,
            "address": self.address,
            "name": self.name or f"Source {self.id}",
            "venue_id": self.venue_id,
            "reputation": round(self.reputation, 4),
            "last_reported_price": self.last_reported_price,
            "last_update": self.last_update.isoformat() if self.last_update else None,
            "active": self.active,
            "total_reports": self.total_reports
        }

class Juror(db.Model):
    __tablename__ = "jurors"
    id = db.Column(db.Integer, primary_key=True)
    address = db.Column(db.String(42), unique=True, nullable=False)
    name = db.Column(db.String(64), nullable=True)
    bond = db.Column(db.Float, default=0.1) # ETH
    weight = db.Column(db.Float, default=0.1)
    vested_weight = db.Column(db.Float, default=0.1)
    total_disputes = db.Column(db.Integer, default=0)
    slashed_amount = db.Column(db.Float, default=0.0)

    def to_dict(self):
        return {
            "id": self.id,
            "address": self.address,
            "name": self.name or f"Juror {self.id}",
            "bond": round(self.bond, 4),
            "weight": round(self.weight, 4),
            "vested_weight": round(self.vested_weight, 4),
            "total_disputes": self.total_disputes,
            "slashed_amount": round(self.slashed_amount, 4)
        }

class PriceRound(db.Model):
    __tablename__ = "rounds"
    id = db.Column(db.Integer, primary_key=True) # round_id
    candidate_price = db.Column(db.Float, nullable=False)
    current_price = db.Column(db.Float, nullable=False)
    tier = db.Column(db.Integer, default=0) # 0=Normal, 1=Moderate, 2=Critical
    deviation = db.Column(db.Float, default=0.0)
    status = db.Column(db.String(32), default="Completed") # Normal, SoftCapped, Disputed, Resolved
    resolved_price = db.Column(db.Float, nullable=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "candidate_price": round(self.candidate_price, 4),
            "current_price": round(self.current_price, 4),
            "tier": self.tier,
            "tier_label": ["Tier 0: Normal", "Tier 1: Moderate (Soft-Cap)", "Tier 2: Critical (Halt & Dispute)"][self.tier],
            "deviation": round(self.deviation, 4),
            "status": self.status,
            "resolved_price": round(self.resolved_price, 4) if self.resolved_price else None,
            "timestamp": self.timestamp.isoformat()
        }

class Dispute(db.Model):
    __tablename__ = "disputes"
    id = db.Column(db.Integer, primary_key=True) # dispute_id
    round_id = db.Column(db.Integer, nullable=False)
    phase = db.Column(db.String(32), default="CommitPhase") # CommitPhase, RevealPhase, Scoring, Resolved
    disputed_price = db.Column(db.Float, nullable=False)
    resolved_price = db.Column(db.Float, nullable=True)
    is_honeypot = db.Column(db.Boolean, default=False)
    honeypot_true_price = db.Column(db.Float, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "round_id": self.round_id,
            "phase": self.phase,
            "disputed_price": round(self.disputed_price, 4),
            "resolved_price": round(self.resolved_price, 4) if self.resolved_price else None,
            "is_honeypot": self.is_honeypot,
            "honeypot_true_price": round(self.honeypot_true_price, 4) if self.honeypot_true_price else None,
            "created_at": self.created_at.isoformat()
        }

class JurorVote(db.Model):
    __tablename__ = "juror_votes"
    id = db.Column(db.Integer, primary_key=True)
    dispute_id = db.Column(db.Integer, nullable=False)
    juror_address = db.Column(db.String(42), nullable=False)
    revealed_price = db.Column(db.Float, nullable=True)
    peer_prediction = db.Column(db.Float, nullable=True)
    score = db.Column(db.Float, nullable=True)
    was_slashed = db.Column(db.Boolean, default=False)

    def to_dict(self):
        return {
            "id": self.id,
            "dispute_id": self.dispute_id,
            "juror_address": self.juror_address,
            "revealed_price": round(self.revealed_price, 4) if self.revealed_price else None,
            "peer_prediction": round(self.peer_prediction, 4) if self.peer_prediction else None,
            "score": round(self.score, 4) if self.score else None,
            "was_slashed": self.was_slashed
        }

class EventLog(db.Model):
    __tablename__ = "event_logs"
    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    layer = db.Column(db.String(16), default="Layer 1") # Layer 1, Layer 2, Layer 3, System
    event_name = db.Column(db.String(64), nullable=False)
    message = db.Column(db.Text, nullable=False)
    severity = db.Column(db.String(16), default="info") # info, success, warning, danger

    def to_dict(self):
        return {
            "id": self.id,
            "timestamp": self.timestamp.strftime("%H:%M:%S"),
            "layer": self.layer,
            "event_name": self.event_name,
            "message": self.message,
            "severity": self.severity
        }
