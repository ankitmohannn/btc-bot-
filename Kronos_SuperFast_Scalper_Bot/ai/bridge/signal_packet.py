"""
SmartScalper V2 - AI Signal Packet Data Model
Structured signal schema matching MQL5 MqlAISignalPacket
"""

from dataclasses import dataclass, asdict
from typing import Optional, List, Dict, Any
import json
import time

@dataclass
class AISignalPacket:
    symbol: str
    direction: str          # "BUY", "SELL", "HOLD"
    confidence: float       # 0.0 - 100.0%
    regime_id: int          # 0-10 Market Regime
    expected_move: float    # Expected price move in quote currency
    risk_score: float       # 0.0 - 100.0 (lower is safer)
    valid_for_seconds: int  # TTL in seconds (e.g. 30s)
    timestamp: int          # Generation timestamp
    reason_codes: str       # Comma-separated rationale tags

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "AISignalPacket":
        return cls(
            symbol=str(data.get("symbol", "BTCUSD")),
            direction=str(data.get("direction", "HOLD")),
            confidence=float(data.get("confidence", 0.0)),
            regime_id=int(data.get("regime_id", 0)),
            expected_move=float(data.get("expected_move", 0.0)),
            risk_score=float(data.get("risk_score", 50.0)),
            valid_for_seconds=int(data.get("valid_for_seconds", 30)),
            timestamp=int(data.get("timestamp", int(time.time()))),
            reason_codes=str(data.get("reason_codes", ""))
        )

    @classmethod
    def from_json(cls, json_str: str) -> "AISignalPacket":
        data = json.loads(json_str)
        return cls.from_dict(data)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)
