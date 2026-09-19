import os

class Config:
    BASE_DIR = os.path.abspath(os.path.dirname(__file__))
    SQLALCHEMY_DATABASE_URI = f"sqlite:///{os.path.join(BASE_DIR, 'rwjo.db')}"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    RPC_URL = os.getenv("RPC_URL", "http://127.0.0.1:8545")
    CHAIN_ID = int(os.getenv("CHAIN_ID", "31337"))
    
    # Contract addresses (populated upon deploy or set via env)
    SOURCE_REGISTRY_ADDR = os.getenv("SOURCE_REGISTRY_ADDR", "")
    SOURCE_FILTER_ADDR = os.getenv("SOURCE_FILTER_ADDR", "")
    DIVERSITY_CHECK_ADDR = os.getenv("DIVERSITY_CHECK_ADDR", "")
    TIER_CLASSIFIER_ADDR = os.getenv("TIER_CLASSIFIER_ADDR", "")
    SOFT_CAP_ADDR = os.getenv("SOFT_CAP_ADDR", "")
    SPOT_CHECK_ADDR = os.getenv("SPOT_CHECK_ADDR", "")
    JUROR_REGISTRY_ADDR = os.getenv("JUROR_REGISTRY_ADDR", "")
    DISPUTE_MODULE_ADDR = os.getenv("DISPUTE_MODULE_ADDR", "")
    HONEYPOT_INJECTOR_ADDR = os.getenv("HONEYPOT_INJECTOR_ADDR", "")
    DEVIATION_CAP_ADDR = os.getenv("DEVIATION_CAP_ADDR", "")
    ADAPTER_ADDR = os.getenv("ADAPTER_ADDR", "")
    OSM_ADDR = os.getenv("OSM_ADDR", "")
