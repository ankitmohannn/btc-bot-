"""
SmartScalper V2 - Feature Packet Data Model
Structured feature schema matching MQL5 MqlFeaturePacket
"""

from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any
import json
import time

@dataclass
class FeaturePacket:
    symbol: str
    timestamp: int
    bid: float
    ask: float
    spread: float
    timeframe_sec: int
    open: float
    high: float
    low: float
    close: float
    volume: int
    atr: float
    rsi: float
    adx: float
    ema9: float
    ema20: float
    ema50: float
    ema200: float
    regime_id: int
    structure_id: int
    session_id: int
    win_rate: float
    losses: int

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "FeaturePacket":
        return cls(
            symbol=str(data.get("symbol", "BTCUSD")),
            timestamp=int(data.get("timestamp", int(time.time()))),
            bid=float(data.get("bid", 0.0)),
            ask=float(data.get("ask", 0.0)),
            spread=float(data.get("spread", 0.0)),
            timeframe_sec=int(data.get("timeframe_sec", 300)),
            open=float(data.get("open", 0.0)),
            high=float(data.get("high", 0.0)),
            low=float(data.get("low", 0.0)),
            close=float(data.get("close", 0.0)),
            volume=int(data.get("volume", 0)),
            atr=float(data.get("atr", 0.0)),
            rsi=float(data.get("rsi", 50.0)),
            adx=float(data.get("adx", 20.0)),
            ema9=float(data.get("ema9", 0.0)),
            ema20=float(data.get("ema20", 0.0)),
            ema50=float(data.get("ema50", 0.0)),
            ema200=float(data.get("ema200", 0.0)),
            regime_id=int(data.get("regime_id", 0)),
            structure_id=int(data.get("structure_id", 0)),
            session_id=int(data.get("session_id", 0)),
            win_rate=float(data.get("win_rate", 70.0)),
            losses=int(data.get("losses", 0))
        )

    @classmethod
    def from_json(cls, json_str: str) -> "FeaturePacket":
        data = json.loads(json_str)
        return cls.from_dict(data)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2)
