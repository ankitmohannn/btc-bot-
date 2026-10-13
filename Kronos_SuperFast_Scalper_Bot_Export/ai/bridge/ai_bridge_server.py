"""
SmartScalper V2 - AI Bridge Server
High-Speed Asynchronous IPC Bridge connecting MetaTrader 5 and Vibe-Trading
"""

import sys
import os
import time
import json
import socket
import logging
import threading
from typing import Optional

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

from feature_packet import FeaturePacket
from signal_packet import AISignalPacket
from vibe_trading_adapter import VibeTradingAdapter

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [AIBridge] %(message)s",
    datefmt="%H:%M:%S"
)
log = logging.getLogger("AIBridgeServer")

class AIBridgeServer:
    def __init__(self, host: str = "127.0.0.1", port: int = 5555, poll_interval: float = 0.25):
        self.host = host
        self.port = port
        self.poll_interval = poll_interval
        self.adapter = VibeTradingAdapter(min_confidence=65.0, ttl_seconds=30)
        self.running = False
        
        # Locate MT5 Data Paths
        self.file_locations = self._discover_mt5_file_paths()
        log.info(f"⚡ Discovered {len(self.file_locations)} potential MT5 file directory targets.")

    def _discover_mt5_file_paths(self) -> list:
        paths = []
        appdata = os.getenv("APPDATA")
        if appdata:
            common_files = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files")
            paths.append(common_files)
            
            terminal_base = os.path.join(appdata, "MetaQuotes", "Terminal")
            if os.path.exists(terminal_base):
                for item in os.listdir(terminal_base):
                    candidate = os.path.join(terminal_base, item, "MQL5", "Files")
                    if os.path.exists(candidate):
                        paths.append(candidate)

        # Fallback to local workspace files directory
        local_files = os.path.abspath(os.path.join(_THIS_DIR, "..", "Files"))
        paths.append(local_files)
        return paths

    def run_file_bridge_loop(self):
        """
        Polls for incoming feature packets in MT5 Files directories and writes structured signal packets.
        """
        log.info("🚀 Starting File-Based AI Bridge Poller Loop...")
        last_processed_ts = 0

        while self.running:
            try:
                for base_dir in self.file_locations:
                    feat_file = os.path.join(base_dir, "smart_scalper_features.json")
                    sig_file = os.path.join(base_dir, "smart_scalper_signal.json")

                    if os.path.exists(feat_file):
                        try:
                            with open(feat_file, "r", encoding="utf-8", errors="ignore") as f:
                                content = f.read().strip()
                            
                            if content and len(content) > 10:
                                data = json.loads(content)
                                feat = FeaturePacket.from_dict(data)

                                if feat.timestamp > last_processed_ts:
                                    start_t = time.time()
                                    last_processed_ts = feat.timestamp
                                    
                                    # Evaluate through Vibe-Trading Adapter
                                    sig = self.adapter.evaluate_features(feat)
                                    latency_ms = (time.time() - start_t) * 1000

                                    # Write Signal Packet Atomically
                                    os.makedirs(base_dir, exist_ok=True)
                                    tmp_file = sig_file + ".tmp"
                                    with open(tmp_file, "w", encoding="utf-8") as sf:
                                        sf.write(sig.to_json())
                                    os.replace(tmp_file, sig_file)

                                    log.info(
                                        f"🔄 [EVAL] {feat.symbol} -> {sig.direction} | Conf: {sig.confidence:.1f}% | "
                                        f"Risk: {sig.risk_score:.1f} | Latency: {latency_ms:.2f}ms | Reasons: [{sig.reason_codes}]"
                                    )
                        except json.JSONDecodeError:
                            pass
                        except Exception as ex:
                            log.debug(f"File loop read error: {ex}")

                time.sleep(self.poll_interval)
            except Exception as e:
                log.error(f"Error in file bridge loop: {e}")
                time.sleep(1)

    def start(self):
        self.running = True
        log.info(f"✨ AI Bridge Server Started (Host: {self.host}:{self.port})")
        
        # Start file bridge thread
        file_thread = threading.Thread(target=self.run_file_bridge_loop, daemon=True)
        file_thread.start()

        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            log.info("Shutdown requested by user.")
            self.running = False

def main():
    server = AIBridgeServer()
    server.start()

if __name__ == "__main__":
    main()
