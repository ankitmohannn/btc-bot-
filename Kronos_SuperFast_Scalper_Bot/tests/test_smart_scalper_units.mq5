//+------------------------------------------------------------------+
//|                                   test_smart_scalper_units.mq5   |
//|                                  Copyright 2026, Institutional AI |
//|                     Unit & Module Test Suite for SmartScalper V2  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property script_show_inputs
#property strict

#include "..\Include\SmartScalper\SmartScalper_Types.mqh"
#include "..\Include\SmartScalper\SmartScalper_Config.mqh"
#include "..\Include\SmartScalper\SmartScalper_RiskEngine.mqh"
#include "..\Include\SmartScalper\SmartScalper_Scoring.mqh"
#include "..\Include\SmartScalper\SmartScalper_Filters.mqh"
#include "..\Include\SmartScalper\SmartScalper_AIBridge.mqh"

int g_tests_passed = 0;
int g_tests_failed = 0;

void AssertTrue(bool condition, string test_name)
  {
   if(condition)
     {
      PrintFormat("  ✅ [PASS] %s", test_name);
      g_tests_passed++;
     }
   else
     {
      PrintFormat("  ❌ [FAIL] %s", test_name);
      g_tests_failed++;
     }
  }

void AssertDoubleEqual(double actual, double expected, double epsilon, string test_name)
  {
   if(MathAbs(actual - expected) <= epsilon)
     {
      PrintFormat("  ✅ [PASS] %s (Actual: %.4f == Expected: %.4f)", test_name, actual, expected);
      g_tests_passed++;
     }
   else
     {
      PrintFormat("  ❌ [FAIL] %s (Actual: %.4f != Expected: %.4f)", test_name, actual, expected);
      g_tests_failed++;
     }
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   Print("================================================================");
   Print("🧪 RUNNING SMARTSCALPER V2 UNIT & MODULE TEST SUITE");
   Print("================================================================");

   g_tests_passed = 0;
   g_tests_failed = 0;

   // -------------------------------------------------------------
   // TEST SUITE 1: Institutional Risk Engine & Lot Size Sizing
   // -------------------------------------------------------------
   Print("\n--- [SUITE 1] Risk Engine & Volume Step Normalization ---");
   CSmartRiskEngine risk_engine;
   risk_engine.Init(_Symbol);

   double norm_lot = risk_engine.NormalizeLotSize(_Symbol, 0.05432);
   AssertTrue(norm_lot >= 0.01 && norm_lot <= 10.0, "NormalizeLotSize bounds check");

   double norm_min = risk_engine.NormalizeLotSize(_Symbol, 0.001);
   AssertTrue(norm_min >= 0.01, "NormalizeLotSize minimum lot clamping");

   double norm_max = risk_engine.NormalizeLotSize(_Symbol, 50.0);
   AssertTrue(norm_max <= 10.0, "NormalizeLotSize maximum lot clamping");

   double calculated_rr = 0.0;
   bool rr_ok = risk_engine.IsRRValid(100.0, 95.0, 110.0, calculated_rr);
   AssertTrue(rr_ok && calculated_rr == 2.0, "RiskReward Calculation: 100 entry, 95 SL, 110 TP gives 2.0 RR");

   bool rr_bad = risk_engine.IsRRValid(100.0, 95.0, 102.0, calculated_rr);
   AssertTrue(!rr_bad && calculated_rr < 1.5, "RiskReward Rejection: 100 entry, 95 SL, 102 TP (0.4 RR < 1.5)");

   // -------------------------------------------------------------
   // TEST SUITE 2: Explainable Scoring Engine Bounds & Thresholds
   // -------------------------------------------------------------
   Print("\n--- [SUITE 2] 0-100 Scoring Engine Bounds & States ---");
   CSmartScoringEngine scoring;
   scoring.Init(_Symbol);

   AssertTrue(scoring.GetSignalState(95.0) == SIGNAL_EXTREME, "Score 95.0 -> SIGNAL_EXTREME");
   AssertTrue(scoring.GetSignalState(82.0) == SIGNAL_STRONG, "Score 82.0 -> SIGNAL_STRONG");
   AssertTrue(scoring.GetSignalState(72.0) == SIGNAL_VALID, "Score 72.0 -> SIGNAL_VALID");
   AssertTrue(scoring.GetSignalState(63.0) == SIGNAL_WEAK, "Score 63.0 -> SIGNAL_WEAK");
   AssertTrue(scoring.GetSignalState(45.0) == SIGNAL_NO_TRADE, "Score 45.0 -> SIGNAL_NO_TRADE");

   // -------------------------------------------------------------
   // TEST SUITE 3: Quality Filter Gating & Anti-Overtrading
   // -------------------------------------------------------------
   Print("\n--- [SUITE 3] Quality Filter Gating ---");
   CSmartFilters filters;
   filters.Init(_Symbol);

   string rejection = "";
   // High spread rejection
   bool spread_fail = filters.ValidateEntryQuality(true, 85.0, 150.0, 0, 80.0, true, rejection);
   AssertTrue(!spread_fail && StringFind(rejection, "Spread") >= 0, "High Spread Filter Rejection");

   // Low score rejection
   bool score_fail = filters.ValidateEntryQuality(true, 55.0, 15.0, 0, 80.0, true, rejection);
   AssertTrue(!score_fail && StringFind(rejection, "Score") >= 0, "Low Score Filter Rejection");

   // Max open positions rejection
   bool pos_fail = filters.ValidateEntryQuality(true, 85.0, 15.0, 5, 80.0, true, rejection);
   AssertTrue(!pos_fail && StringFind(rejection, "Max Open") >= 0, "Max Positions Filter Rejection");

   // -------------------------------------------------------------
   // TEST SUITE 4: AI Bridge Packet Serialization & Failsafe
   // -------------------------------------------------------------
   Print("\n--- [SUITE 4] AI Bridge JSON Packet Serialization ---");
   CSmartAIBridge ai_bridge;
   ai_bridge.Init(_Symbol);

   MqlFeaturePacket fp;
   fp.symbol = "BTCUSD";
   fp.timestamp = 1724345000;
   fp.bid = 60000.0;
   fp.ask = 60005.0;
   fp.spread_points = 5.0;
   fp.timeframe_seconds = 300;
   fp.open = 59900.0;
   fp.high = 60100.0;
   fp.low = 59850.0;
   fp.close = 60000.0;
   fp.tick_volume = 1500;
   fp.atr_m5 = 45.0;
   fp.rsi_m5 = 58.5;
   fp.adx_m5 = 26.0;
   fp.ema9_m5 = 59980.0;
   fp.ema20_m5 = 59950.0;
   fp.ema50_m5 = 59800.0;
   fp.ema200_m5 = 59200.0;
   fp.regime_id = 1;
   fp.structure_id = 1;
   fp.session_id = 4;
   fp.recent_win_rate = 80.0;
   fp.consecutive_losses = 0;

   bool export_ok = ai_bridge.ExportFeaturePacket(fp);
   AssertTrue(export_ok, "ExportFeaturePacket successfully wrote JSON file");

   // -------------------------------------------------------------
   // TEST SUMMARY
   // -------------------------------------------------------------
   Print("================================================================");
   PrintFormat("🏁 TEST RESULTS: %d Passed | %d Failed | Total: %d",
               g_tests_passed, g_tests_failed, g_tests_passed + g_tests_failed);
   Print("================================================================");
  }
