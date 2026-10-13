//+------------------------------------------------------------------+
//|                                          SmartScalper_Config.mqh |
//|                                  Copyright 2026, Institutional AI |
//|                          Master Configuration for SmartScalper V2 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"

//+------------------------------------------------------------------+
//| Input Parameters: Group A - Position Sizing & Risk Engine        |
//+------------------------------------------------------------------+
input group "=== [GROUP A] POSITION SIZING & RISK ENGINE ==="
input bool   InpUseDynamicLot       = true;     // Use Dynamic Risk % Lot Sizing (true = Dynamic Institutional Sizing)
input double InpRiskPercent         = 1.0;      // Risk Percentage per Trade (1.0% of Capital)
input double InpFixedLot            = 0.01;     // Fallback Micro-Lot Size
input double InpMinLot              = 0.01;     // Minimum Allowed Lot Size
input double InpMaxLot              = 0.40;     // Maximum Allowed Lot Size (Hard Ceiling: 0.40 Lots Max)
input double InpMaxDailyLossPct     = 0.0;      // Max Daily Loss Limit (%) [0.0 = DISABLED]
input double InpMaxDrawdownPct      = 0.0;      // Max Total Equity Drawdown Limit (%) [0.0 = DISABLED]

//+------------------------------------------------------------------+
//| Input Parameters: Group B - Dynamic SL, TP & Institutional RR    |
//+------------------------------------------------------------------+
input group "=== [GROUP B] DYNAMIC SL, TP & INSTITUTIONAL RR ==="
input ENUM_SL_MODE InpSLMode        = SL_MODE_OPPOSITE_SIGNAL; // Stop Loss Strategy Mode (Exit on Opposite Signal)
input int    InpATRPeriod           = 14;       // ATR Period for Dynamic Volatility
input double InpATRMultiplierSL     = 2.0;      // ATR Multiplier for Stop Loss (2.0x ATR Breathing Room)
input ENUM_TP_MODE InpTPMode        = TP_MODE_HYBRID;      // Take Profit Strategy Mode
input double InpMinimumRR           = 1.2;      // Minimum Strict Risk-to-Reward Ratio Floor (1:1.2)
input double InpTargetRR            = 1.8;      // Preferred Target Risk-to-Reward Ratio (1:1.8)
input int    InpMinSLPoints         = 8000;     // Broker Safety SL Floor (8,000 pts = $80.00 on BTC / $8.00 on Gold)
input int    InpMaxSLPoints         = 25000;    // Broker Safety SL Cap (25,000 pts = $250.00 on BTC / $25.00 on Gold)


//+------------------------------------------------------------------+
//| Input Parameters: Group C - Market Structure & SMC Engine        |
//+------------------------------------------------------------------+
input group "=== [GROUP C] MARKET STRUCTURE & SMART MONEY (SMC) ==="
input int    InpSwingLookback       = 5;        // Left/Right Bars for Swing High/Low
input int    InpFVGMinSizePoints    = 10;       // Minimum Fair Value Gap Size (points)
input int    InpOBMitigationBars    = 50;       // Order Block Max Active Bars
input int    InpSweepBufferPoints   = 5;        // Liquidity Sweep Penetration Buffer (points)
input bool   InpEnforcePremiumDisc  = true;     // Enforce Discount BUY / Premium SELL Rule

//+------------------------------------------------------------------+
//| Input Parameters: Group D - Multi-Timeframe Scoring Weights      |
//+------------------------------------------------------------------+
input group "=== [GROUP D] SCORING ENGINE WEIGHTS (TOTAL: 100) ==="
input double InpWeightTrend         = 15.0;     // Trend Alignment Weight (Max 15)
input double InpWeightStructure     = 15.0;     // Market Structure (BOS/CHoCH) Weight (Max 15)
input double InpWeightLiquidity     = 15.0;     // Liquidity Sweeps Weight (Max 15)
input double InpWeightMomentum      = 10.0;     // Momentum (RSI/MACD/ADX) Weight (Max 10)
input double InpWeightVolatility    = 10.0;     // Volatility Regime Weight (Max 10)
input double InpWeightFVG_OB        = 10.0;     // FVG / Order Block Tap Weight (Max 10)
input double InpWeightMTF           = 10.0;     // Multi-Timeframe Synergy Weight (Max 10)
input double InpWeightSpread        = 5.0;      // Spread Quality Weight (Max 5)
input double InpWeightSession       = 5.0;      // Session Alignment Weight (Max 5)
input double InpWeightAI            = 5.0;      // AI Bridge / Vibe-Trading Weight (Max 5)
input double InpScoreThresholdValid = 70.0;     // Minimum Score for Valid Entry (0-100)
input double InpScoreThresholdStrong= 80.0;     // Minimum Score for Strong Entry (0-100)
input bool   InpEnableTrendBooster  = true;     // Enable Trend Continuation Booster
input double InpTrendBoosterScore   = 10.0;     // Score Bonus for Trend Continuation (+10.0 pts)
input int    InpTrendBoosterMaxMins = 20;       // Max Minutes After Winner to Keep Booster Active (mins)

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Input Parameters: Group E - Trade Management & Anti-Overtrading  |
//+------------------------------------------------------------------+
input group "=== [GROUP E] TRADE MANAGEMENT & ANTI-OVERTRADING ==="
input bool   InpEnableBasketDCA     = false;    // Disable Basket DCA (Institutional Partial TP & Trailing Active)
input double InpBasketTargetUSD     = 5.00;     // Basket Target Profit in USD
input double InpBasketStopLossUSD   = 25.00;    // Emergency Basket Stop Loss in USD
input int    InpGridStepPoints      = 6000;     // Pullback Step Distance
input int    InpMaxOpenTrades       = 12;       // Maximum Concurrent Open Positions (Max 12 positions)
input double InpMaxTotalBasketLots  = 4.50;     // Maximum Total Combined Volume on Active Side (Max 4.50 Lots)
input bool   InpEnableInvestedMarginTP = true;  // Close Basket when Floating Profit >= Target Margin ROI (50% Margin ROI)
input double InpInvestedMarginROI_Pct = 50.0;   // Target ROI on Invested Margin (50% = 1:0.5 Profit to Margin)
input bool   InpEnablePartialTP     = false;    // Disable Partial TP (Let full position run to Take Profit)
input double InpPartialTPTriggerR   = 1.0;      // Partial TP Trigger at X R-Multiple (1.0R)
input double InpPartialTPPercent   = 50.0;     // Percentage of Volume to Close (50.0%)
input bool   InpEnableBreakEven     = false;    // Disable Auto Break-Even (Do NOT drag SL to entry price)
input double InpBreakEvenTriggerR   = 1.0;      // Move to BE when Trade reaches X R-Multiple (1.0R)
input int    InpBreakEvenBufferPts  = 20;       // Profit buffer locked above open price (20 points)
input bool   InpEnableTrailingStop  = false;    // Disable Trailing Stop moving SL (Keep SL-free until TP / Opp Signal)
input double InpTrailingATRMult     = 1.5;      // Trailing Distance in ATR multiples
input int    InpTrailingStepPts     = 20;       // Trailing Minimum Step Advancement (points)
input bool   InpEnableProfitLock    = false;    // Disable Profit Lock moving SL (Positions exit strictly at TP or Opp Signal)
input double InpProfitLockUSD       = 5.00;     // Profit USD Trigger ($5.00)
input int    InpMaxSpreadPoints     = 60;       // Maximum Allowed Spread (points)
input bool   InpAllowDuplicateSignals = true;   // Allow Trades on Duplicate Signals (Scale in on same-direction signals)
input int    InpDuplicateThrottleSecs = 30;     // Min Seconds Between Same-Direction Entries (30s Debounce)
input int    InpCooldownAfterTrade  = 0;        // Cooldown Seconds After Trade (0s Instant Continuation)
input int    InpCooldownAfterLoss   = 60;       // Cooldown Seconds After a Losing Basket (1 min)
input int    InpMaxTradesPerSession = 9999;     // Maximum Trades Allowed per Session [Unlimited]
input int    InpMaxLossesPerSession = 9999;     // Maximum Allowed Losses per Session [Unlimited]


//+------------------------------------------------------------------+
//| Input Parameters: Group F - Sessions & News Filter Engine        |
//+------------------------------------------------------------------+
input group "=== [GROUP F] SESSION PROFILES & NEWS ENGINE ==="
input ENUM_SESSION_PROFILE_SELECT InpSessionProfile = PROFILE_ALL_SESSIONS; // Active Trading Session
input string InpCustomSessionStart  = "07:00";  // Custom Session Start (Server Time HH:MM)
input string InpCustomSessionEnd    = "20:00";  // Custom Session End (Server Time HH:MM)
input int    InpServerGMTOffset     = 0;        // Broker Server GMT Offset (Hours)
input bool   InpNewsFilterEnabled   = false;    // Enable High-Impact News Filter
input int    InpNewsPauseMinsBefore = 15;       // Mins Before High-Impact News to Pause
input int    InpNewsPauseMinsAfter  = 15;       // Mins After High-Impact News to Resume

//+------------------------------------------------------------------+
//| Input Parameters: Group G - AI Bridge & Failsafe Configuration   |
//+------------------------------------------------------------------+
input group "=== [GROUP G] AI BRIDGE & FAILSAFE SETTINGS ==="
input bool   InpEnableAIBridge      = true;     // Enable Python AI Bridge Connection
input bool   InpAIRequiredForEntry  = false;    // If True: AI Offline = Block Trades. If False: Trade Deterministically
input string InpBridgeHost          = "127.0.0.1"; // AI Bridge Host / IP
input int    InpBridgePort          = 5555;     // AI Bridge TCP Port
input int    InpSignalValidityTTL   = 30;       // AI Signal TTL / Expiry in Seconds
input double InpMinAIConfidence     = 65.0;     // Minimum AI Confidence Threshold (0-100%)
input bool   InpUseFileBridgeFallback = true;   // Use Shared File Bridge Fallback (JSON/CSV)

//+------------------------------------------------------------------+
//| Input Parameters: Group H - Diagnostics & Chart HUD Visuals     |
//+------------------------------------------------------------------+
input group "=== [GROUP H] HUD, SYSTEM & EXECUTION CONTROLS ==="
input bool   InpShowHUD             = true;     // Display On-Chart Institutional HUD Panel
input int    InpMagicNumber         = 888222;   // SmartScalper V2 Magic Number
input int    InpSlippagePoints      = 30;       // Maximum Allowed Execution Slippage (points)
input int    InpTimerFrequencyMS    = 250;      // HUD / AI Bridge Refresh Rate (ms)

//+------------------------------------------------------------------+
//| Input Parameters: Group I - Volatility Clustering & Tail Risk   |
//+------------------------------------------------------------------+
input group "=== [GROUP I] VOLATILITY CLUSTERING & TAIL-RISK SHIELD ==="
input bool   InpEnableVolShield         = true;     // Enable Volatility Clustering & Tail-Risk Sizer
input int    InpVolFastPeriod           = 5;        // Fast Volatility Period (Bars)
input int    InpVolSlowPeriod           = 50;       // Slow Baseline Volatility Period (Bars)
input int    InpTailRiskLookback        = 60;       // Tail-Risk VaR 99% Lookback Bars
input double InpVolHighRatioThreshold   = 1.35;     // High Volatility Expansion Ratio Threshold
input double InpVolExtremeRatioThreshold= 2.10;     // Extreme Volatility Shock Ratio Threshold
input double InpTailRiskBlockThreshold  = 85.0;     // Tail Risk Block Threshold (0-100 Score)
input bool   InpBlockExtremeVol         = false;    // If True: Block Extreme Vol; If False: Defensive 0.20x Sizing
input double InpMaxSymbolExposureLots   = 3.00;     // Max Cumulative Symbol Exposure Limit (Lots)

//+------------------------------------------------------------------+
//| Input Parameters: Group J - Telegram Signal Alerts               |
//+------------------------------------------------------------------+
input group "=== [GROUP J] TELEGRAM SIGNAL ALERTS ==="
input bool   InpEnableTelegram          = true;     // Enable Telegram Signal Alerts
input bool   InpTelegramOnlyTradeAlerts = true;     // Clean Mode: Alerts ONLY for Executed Trades & Exits (No Signal Spam)
input string InpTelegramBotToken        = "8899369305:AAHC5CT2oUzcVlNlHNyCSa59JxYyaKFIRXo";  // Telegram Bot Token (from @BotFather)
input string InpTelegramChatID          = "1222970665,-1004305951793";                           // Telegram Chat IDs (Admin + Test signals group)
