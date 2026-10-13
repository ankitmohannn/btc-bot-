# SmartScalper V2: Installation, Setup & Instant Rollback Guide

## 1. MetaTrader 5 Expert Advisor Setup

### Prerequisites
- MetaTrader 5 Desktop (Build 4000+ recommended)
- Python 3.9+ (Installed on system PATH)

### Installation Steps
1. **Locate Compiled EA**:
   The compiled EA binary is located at:
   `SmartScalper_V2.ex5`
2. **Copy to MT5 Experts Folder**:
   - In MT5, click **File -> Open Data Folder**.
   - Navigate to `MQL5\Experts\`.
   - Copy `SmartScalper_V2.ex5` (and the `Include\SmartScalper` folder if recompiling locally) into `MQL5\Experts\`.
3. **Attach to Chart**:
   - Open a **BTCUSD** (or target symbol) chart on the **M5** timeframe.
   - Drag `SmartScalper_V2` from the Navigator panel onto the chart.
   - In the **Common** tab, check **Allow Algo Trading**.
   - In the **Inputs** tab, adjust parameters as desired (defaults are pre-optimized for institutional safety).
   - Click **OK**.
4. **Verify HUD**:
   - The on-chart HUD panel will appear on the top-left showing the market state, regime, signal, score, and AI bridge heartbeat.

---

## 2. Python AI Bridge & Vibe-Trading Setup

### Launching the AI Bridge:
1. Double-click the launcher batch file:
   `ai/bridge/run_ai_bridge.bat`
   *Or from PowerShell / Command Prompt:*
   ```bash
   cd ai/bridge
   python ai_bridge_server.py
   ```
2. The bridge will automatically discover the MT5 Data folder, begin ingesting feature packets, evaluate them via the `VibeTradingAdapter`, and write structured signal packets.

### Offline Failsafe Behavior:
- If the Python bridge is closed or disconnected:
  - `SmartScalper_V2` automatically sets `AI_CONFIDENCE = 0.0`.
  - With default `InpAIRequiredForEntry = false`, the EA continues trading deterministically without interruption.
  - If `InpAIRequiredForEntry = true`, the EA halts new orders until the bridge is reopened.

---

## 3. Instant Rollback Procedure

If you ever wish to revert to the original baseline EA:

1. **Remove SmartScalper V2**:
   - Right-click on the active MT5 chart -> **Expert List** -> Click **Remove** on `SmartScalper_V2`.
2. **Attach Baseline EA**:
   - The original unmodified baseline EA is preserved at:
     `Kronos_SuperFast_Scalper_EA.mq5` / `Kronos_SuperFast_Scalper_EA.ex5`
   - Attach `Kronos_SuperFast_Scalper_EA` to your chart.
3. **Launch Legacy Python Script (Optional)**:
   - Run `run_super_fast_scalper.bat` to launch the legacy Python process if needed.

Zero files from the baseline were deleted or corrupted during the upgrade.
