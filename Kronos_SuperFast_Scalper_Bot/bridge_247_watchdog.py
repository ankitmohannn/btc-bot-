"""
SmartScalper V2 - 24/7 AI Bridge & Scalper Watchdog Supervisor
Ensures zero-downtime, self-healing operation of AI Bridge Server and Scalper Engine.
"""

import os
import sys
import time
import subprocess
import logging
from datetime import datetime

# Force UTF-8 stdout/stderr on Windows
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
if sys.stderr and hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [24/7 WATCHDOG] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
log = logging.getLogger("BridgeWatchdog")

_ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
if _ROOT_DIR not in sys.path:
    sys.path.insert(0, _ROOT_DIR)

class Bot247Supervisor:
    def __init__(self, symbol: str = "XAUUSD", tf: str = "M5"):
        self.symbol = symbol.upper()
        self.tf = tf.upper()
        self.running = True
        
        self.proc_bridge = None
        self.proc_scalper = None
        
        appdata = os.getenv("APPDATA", "")
        self.common_files = os.path.join(appdata, "MetaQuotes", "Terminal", "Common", "Files")
        self.sig_json = os.path.join(self.common_files, "smart_scalper_signal.json")
        self.sig_csv = os.path.join(self.common_files, "kronos_signal.csv")
        
        log.info(f"🛡️ 24/7 Supervisor Initialized for {self.symbol} ({self.tf})")

    def _start_bridge_server(self):
        cmd = [sys.executable, "-u", os.path.join("ai", "bridge", "ai_bridge_server.py")]
        log.info(f"🚀 Spawning AI Bridge Server: {' '.join(cmd)}")
        return subprocess.Popen(cmd, cwd=_ROOT_DIR)

    def _start_scalper_engine(self):
        cmd = [sys.executable, "-u", "super_fast_scalper.py", "--symbol", self.symbol, "--timeframe", self.tf]
        log.info(f"🚀 Spawning Scalper Engine: {' '.join(cmd)}")
        return subprocess.Popen(cmd, cwd=_ROOT_DIR)

    def _check_file_freshness(self, filepath: str, max_age_sec: float = 10.0) -> bool:
        if not os.path.exists(filepath):
            return False
        age = time.time() - os.path.getmtime(filepath)
        return age <= max_age_sec

    def run(self):
        log.info("🌟 Starting 24/7 Auto-Healing Watchdog Loop with 45-Min Discord Telemetry...")
        
        # Import Discord Reporter
        try:
            from ai.bridge.discord_notifier import DiscordReporter
            discord_reporter = DiscordReporter(interval_minutes=45)
            # Send initial startup notification
            discord_reporter.send_discord_update(is_startup=True)
        except Exception as e:
            log.warning(f"Could not initialize Discord reporter: {e}")
            discord_reporter = None
            
        # Initial Launch
        self.proc_bridge = self._start_bridge_server()
        time.sleep(1.0)
        self.proc_scalper = self._start_scalper_engine()
        
        last_heartbeat_report = 0
        last_discord_report = time.time()
        
        while self.running:
            try:
                now = time.time()
                
                # 1. Check AI Bridge Server Process
                if self.proc_bridge.poll() is not None:
                    code = self.proc_bridge.returncode
                    log.warning(f"⚠️ AI Bridge Server terminated (exit code: {code}). Reviving immediately...")
                    self.proc_bridge = self._start_bridge_server()

                # 2. Check Scalper Engine Process
                if self.proc_scalper.poll() is not None:
                    code = self.proc_scalper.returncode
                    log.warning(f"⚠️ Scalper Engine terminated (exit code: {code}). Reviving immediately...")
                    self.proc_scalper = self._start_scalper_engine()

                # 3. Check Stream Signal Freshness (Only if active stream was established)
                if os.path.exists(self.sig_json):
                    json_age = now - os.path.getmtime(self.sig_json)
                    if json_age > 120.0 and self.proc_scalper.poll() is not None:
                        log.warning(f"⚠️ Stream signal stall detected (age: {json_age:.1f}s). Restarting Scalper Engine...")
                        try:
                            self.proc_scalper.terminate()
                            self.proc_scalper.wait(timeout=2)
                        except Exception:
                            self.proc_scalper.kill()
                        self.proc_scalper = self._start_scalper_engine()

                # 4. Periodic Heartbeat Summary (every 60s)
                if now - last_heartbeat_report >= 60.0:
                    last_heartbeat_report = now
                    bridge_pid = self.proc_bridge.pid if self.proc_bridge else "N/A"
                    scalper_pid = self.proc_scalper.pid if self.proc_scalper else "N/A"
                    log.info(
                        f"💚 [24/7 HEARTBEAT] All Systems Operational | Bridge PID: {bridge_pid} | "
                        f"Scalper PID: {scalper_pid} | Target: {self.symbol} {self.tf}"
                    )

                # 5. Periodic 45-Minute Discord Performance & PnL Telemetry
                if discord_reporter and (now - last_discord_report >= (45.0 * 60.0)):
                    last_discord_report = now
                    log.info("📢 Emitting scheduled 45-minute Discord telemetry update...")
                    discord_reporter.send_discord_update(is_startup=False)

                time.sleep(2.0)
                
            except KeyboardInterrupt:
                log.info("Shutdown signal received. Gracefully stopping child processes...")
                self.running = False
                break
            except Exception as e:
                log.error(f"Watchdog loop exception: {e}")
                time.sleep(3.0)

        # Cleanup on exit
        if self.proc_bridge:
            try: self.proc_bridge.terminate()
            except Exception: pass
        if self.proc_scalper:
            try: self.proc_scalper.terminate()
            except Exception: pass
        log.info("Watchdog shutdown complete.")

if __name__ == "__main__":
    sym = sys.argv[1] if len(sys.argv) > 1 else "XAUUSD"
    tf = sys.argv[2] if len(sys.argv) > 2 else "M5"
    supervisor = Bot247Supervisor(symbol=sym, tf=tf)
    supervisor.run()
