"""
SmartScalper V2 - HKUDS Vibe-Trading Integration Adapter
Connects feature packet stream to Vibe-Trading research intelligence models
"""

import time
import logging
try:
    from .feature_packet import FeaturePacket
    from .signal_packet import AISignalPacket
except (ImportError, ValueError):
    from feature_packet import FeaturePacket
    from signal_packet import AISignalPacket

log = logging.getLogger("VibeTradingAdapter")

class VibeTradingAdapter:
    """
    Vibe-Trading Research & AI Intelligence Adapter
    Generates high-confidence structured signals, regime predictions, and risk attribution.
    """
    def __init__(self, min_confidence: float = 65.0, ttl_seconds: int = 30):
        self.min_confidence = min_confidence
        self.ttl_seconds = ttl_seconds
        log.info(f"⚡ VibeTradingAdapter Initialized | Min Conf: {self.min_confidence}% | TTL: {self.ttl_seconds}s")

    def evaluate_features(self, feat: FeaturePacket) -> AISignalPacket:
        """
        Evaluate incoming deterministic feature packet through Vibe-Trading AI heuristics & models.
        """
        reasons: List[str] = []
        score_bull = 0.0
        score_bear = 0.0

        # 1. Trend & EMA Fan Alignment
        if feat.ema9 > feat.ema20 and feat.ema20 > feat.ema50:
            score_bull += 25.0
            reasons.append("EMA_FAN_BULLISH")
        elif feat.ema9 < feat.ema20 and feat.ema20 < feat.ema50:
            score_bear += 25.0
            reasons.append("EMA_FAN_BEARISH")

        if feat.close > feat.ema200 and feat.ema200 > 0:
            score_bull += 15.0
            reasons.append("MACRO_ABOVE_EMA200")
        elif feat.close < feat.ema200 and feat.ema200 > 0:
            score_bear += 15.0
            reasons.append("MACRO_BELOW_EMA200")

        # 2. Momentum (RSI & ADX)
        if 45.0 <= feat.rsi <= 68.0 and feat.adx >= 20.0:
            score_bull += 20.0
            reasons.append("BULLISH_MOMENTUM_EXPANSION")
        elif 32.0 <= feat.rsi <= 55.0 and feat.adx >= 20.0:
            score_bear += 20.0
            reasons.append("BEARISH_MOMENTUM_EXPANSION")

        # 3. Market Structure & SMC Events
        # Structure ID mapping: 1=BOS_BULL, 2=BOS_BEAR, 3=CHOCH_BULL, 4=CHOCH_BEAR, 5=SWEEP_BSL, 6=SWEEP_SSL
        if feat.structure_id in (1, 3, 6):
            score_bull += 25.0
            if feat.structure_id == 1: reasons.append("BOS_BULL_CONFIRMED")
            elif feat.structure_id == 3: reasons.append("CHOCH_BULL_CONFIRMED")
            elif feat.structure_id == 6: reasons.append("LIQUIDITY_SSL_SWEPT")
        elif feat.structure_id in (2, 4, 5):
            score_bear += 25.0
            if feat.structure_id == 2: reasons.append("BOS_BEAR_CONFIRMED")
            elif feat.structure_id == 4: reasons.append("CHOCH_BEAR_CONFIRMED")
            elif feat.structure_id == 5: reasons.append("LIQUIDITY_BSL_SWEPT")

        # 4. Volatility & Spread Quality
        if feat.spread <= 30.0:
            score_bull += 15.0
            score_bear += 15.0
            reasons.append("TIGHT_SPREAD_QUALITY")

        # Determine Signal Direction & Confidence
        if score_bull >= score_bear and score_bull >= self.min_confidence:
            direction = "BUY"
            confidence = min(99.0, score_bull)
            regime = feat.regime_id if feat.regime_id != 0 else 1
            expected_move = round(feat.atr * 1.8, 2)
            risk_score = round(max(10.0, 100.0 - confidence + (feat.losses * 10)), 1)
        elif score_bear > score_bull and score_bear >= self.min_confidence:
            direction = "SELL"
            confidence = min(99.0, score_bear)
            regime = feat.regime_id if feat.regime_id != 0 else 2
            expected_move = round(feat.atr * 1.8, 2)
            risk_score = round(max(10.0, 100.0 - confidence + (feat.losses * 10)), 1)
        else:
            direction = "HOLD"
            confidence = max(50.0, max(score_bull, score_bear))
            regime = 3 # Range / Scanning
            expected_move = 0.0
            risk_score = 50.0
            reasons = ["WAITING_FOR_SMC_PULLBACK_CONFIRMATION"]

        return AISignalPacket(
            symbol=feat.symbol,
            direction=direction,
            confidence=round(confidence, 1),
            regime_id=regime,
            expected_move=expected_move,
            risk_score=risk_score,
            valid_for_seconds=self.ttl_seconds,
            timestamp=int(time.time()),
            reason_codes=",".join(reasons)
        )
