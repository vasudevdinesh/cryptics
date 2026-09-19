import os
import json
from web3 import Web3
from config import Config

class BlockchainService:
    def __init__(self, rpc_url=None):
        self.rpc_url = rpc_url or Config.RPC_URL
        self.w3 = Web3(Web3.HTTPProvider(self.rpc_url))
        self.contracts = {}
        self._load_contracts()

    def is_connected(self):
        return self.w3.is_connected()

    def _load_contracts(self):
        # We will attempt to load ABIs from Foundry out/ directory if present
        foundry_out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "contracts", "out"))
        
        contract_names = [
            ("SourceRegistry", "SourceRegistry.sol"),
            ("SourceFilter", "SourceFilter.sol"),
            ("DiversityCheck", "DiversityCheck.sol"),
            ("TierClassifier", "TierClassifier.sol"),
            ("SoftCapController", "SoftCapController.sol"),
            ("SpotCheckPanel", "SpotCheckPanel.sol"),
            ("JurorRegistry", "JurorRegistry.sol"),
            ("RandomSelector", "RandomSelector.sol"),
            ("DisputeModule", "DisputeModule.sol"),
            ("HoneypotInjector", "HoneypotInjector.sol"),
            ("DeviationCap", "DeviationCap.sol"),
            ("MockOSM", "MockOSM.sol"),
            ("Adapter", "Adapter.sol"),
        ]

        for name, filename in contract_names:
            json_path = os.path.join(foundry_out, filename, f"{name}.json")
            if os.path.exists(json_path):
                try:
                    with open(json_path, "r") as f:
                        data = json.load(f)
                        self.contracts[name] = {
                            "abi": data.get("abi", []),
                            "bytecode": data.get("bytecode", {}).get("object", "")
                        }
                except Exception as e:
                    print(f"Warning: Could not load ABI for {name}: {e}")

    def get_contract(self, name, address):
        if name in self.contracts and address:
            return self.w3.eth.contract(address=Web3.to_checksum_address(address), abi=self.contracts[name]["abi"])
        return None

    def read_adapter_price(self, adapter_address):
        try:
            if not self.is_connected() or not adapter_address:
                return None, False
            c = self.get_contract("Adapter", adapter_address)
            if c:
                price, disputed = c.functions.read().call()
                return price / 1e18, disputed
        except Exception as e:
            print(f"Error reading adapter price: {e}")
        return None, False

blockchain_service = BlockchainService()
