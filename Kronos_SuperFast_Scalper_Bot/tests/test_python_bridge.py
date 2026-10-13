"""
SmartScalper V2 - Python AI Bridge Unit Tests
Tests FeaturePacket, AISignalPacket, VibeTradingAdapter, and ResearchEvaluator
"""

import sys
import os
import unittest
import json
import time

_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
_AI_DIR = os.path.join(_ROOT, "ai", "bridge")

for p in [_ROOT, _AI_DIR]:
    if p not in sys.path:
        sys.path.insert(0, p)

from feature_packet import FeaturePacket
from signal_packet import AISignalPacket
from vibe_trading_adapter import VibeTradingAdapter
from research_evaluator import ResearchEvaluator

class TestSmartScalperBridge(unittest.TestCase):
    def setUp(self):
        self.adapter = VibeTradingAdapter(min_confidence=65.0, ttl_seconds=30)

    def test_feature_packet_serialization(self):
        fp = FeaturePacket(
            symbol="BTCUSD",
            timestamp=1724345000,
            bid=60000.0,
            ask=60005.0,
            spread=5.0,
            timeframe_sec=300,
            open=59900.0,
            high=60100.0,
            low=59850.0,
            close=60000.0,
            volume=1200,
            atr=45.0,
            rsi=58.0,
            adx=26.0,
            ema9=59980.0,
            ema20=59950.0,
            ema50=59800.0,
            ema200=59200.0,
            regime_id=1,
            structure_id=1,
            session_id=4,
            win_rate=78.0,
            losses=0
        )
        json_str = fp.to_json()
        self.assertIn("BTCUSD", json_str)
        self.assertIn("60000.0", json_str)

        reconstructed = FeaturePacket.from_json(json_str)
        self.assertEqual(reconstructed.symbol, "BTCUSD")
        self.assertEqual(reconstructed.atr, 45.0)
        self.assertEqual(reconstructed.ema9, 59980.0)

    def test_vibe_adapter_bullish_signal(self):
        # Bullish feature packet: EMA stacked bullish, RSI 58, ADX 26, BOS Bull (structure_id=1)
        fp = FeaturePacket(
            symbol="BTCUSD",
            timestamp=int(time.time()),
            bid=60000.0,
            ask=60005.0,
            spread=5.0,
            timeframe_sec=300,
            open=59900.0,
            high=60100.0,
            low=59850.0,
            close=60000.0,
            volume=1200,
            atr=50.0,
            rsi=58.0,
            adx=26.0,
            ema9=60000.0,
            ema20=59950.0,
            ema50=59800.0,
            ema200=59200.0,
            regime_id=1,
            structure_id=1, # BOS_BULL
            session_id=4,
            win_rate=75.0,
            losses=0
        )
        sig = self.adapter.evaluate_features(fp)
        self.assertEqual(sig.direction, "BUY")
        self.assertGreaterEqual(sig.confidence, 65.0)
        self.assertIn("BOS_BULL_CONFIRMED", sig.reason_codes)
        self.assertIn("EMA_FAN_BULLISH", sig.reason_codes)

    def test_vibe_adapter_bearish_signal(self):
        # Bearish feature packet: EMA stacked bearish, RSI 40, ADX 26, BOS Bear (structure_id=2)
        fp = FeaturePacket(
            symbol="BTCUSD",
            timestamp=int(time.time()),
            bid=60000.0,
            ask=60005.0,
            spread=5.0,
            timeframe_sec=300,
            open=60100.0,
            high=60150.0,
            low=59900.0,
            close=59950.0,
            volume=1200,
            atr=50.0,
            rsi=40.0,
            adx=26.0,
            ema9=59900.0,
            ema20=59950.0,
            ema50=60050.0,
            ema200=60500.0,
            regime_id=2,
            structure_id=2, # BOS_BEAR
            session_id=4,
            win_rate=75.0,
            losses=0
        )
        sig = self.adapter.evaluate_features(fp)
        self.assertEqual(sig.direction, "SELL")
        self.assertGreaterEqual(sig.confidence, 65.0)
        self.assertIn("BOS_BEAR_CONFIRMED", sig.reason_codes)
        self.assertIn("EMA_FAN_BEARISH", sig.reason_codes)

    def test_research_evaluator_metrics(self):
        evaluator = ResearchEvaluator()
        sample_records = [
            {"ticket": 1, "profit_usd": 30.0},
            {"ticket": 2, "profit_usd": 35.0},
            {"ticket": 3, "profit_usd": -15.0},
            {"ticket": 4, "profit_usd": 40.0},
            {"ticket": 5, "profit_usd": -15.0},
        ]
        metrics = evaluator.calculate_performance_metrics(sample_records)
        self.assertEqual(metrics["total_trades"], 5)
        self.assertEqual(metrics["win_count"], 3)
        self.assertEqual(metrics["loss_count"], 2)
        self.assertEqual(metrics["win_rate_pct"], 60.0)
        self.assertEqual(metrics["net_profit"], 75.0)
        self.assertEqual(metrics["profit_factor"], 3.5)

    def test_monte_carlo_resampling(self):
        evaluator = ResearchEvaluator()
        sample_profits = [25.0, 30.0, -15.0, 45.0, 20.0, -10.0, 35.0, -15.0, 50.0, 30.0, -20.0, 40.0]
        mc_results = evaluator.run_monte_carlo(sample_profits, iterations=500)
        self.assertEqual(mc_results["iterations"], 500)
        self.assertIn("95th_percentile_drawdown_usd", mc_results)
        self.assertGreater(mc_results["median_profit_usd"], 0)

if __name__ == "__main__":
    unittest.main()
