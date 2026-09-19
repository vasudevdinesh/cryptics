import os
from flask import Flask, jsonify
from flask_cors import CORS
from config import Config
from models import db
from routes.sources import sources_bp
from routes.tiers import tiers_bp
from routes.disputes import disputes_bp
from routes.demo import demo_bp

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Enable CORS for Vue.js frontend
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    # Init database
    db.init_app(app)

    # Register Blueprints
    app.register_blueprint(sources_bp)
    app.register_blueprint(tiers_bp)
    app.register_blueprint(disputes_bp)
    app.register_blueprint(demo_bp)

    @app.route("/api/health", methods=["GET"])
    def health():
        return jsonify({"status": "ok", "service": "RWJO v4 Backend"})

    with app.app_context():
        db.create_all()
        # Trigger initial reset to seed data if empty
        from models import Source
        if Source.query.count() == 0:
            from routes.demo import reset_demo
            reset_demo()

    return app

if __name__ == "__main__":
    app = create_app()
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=True)
