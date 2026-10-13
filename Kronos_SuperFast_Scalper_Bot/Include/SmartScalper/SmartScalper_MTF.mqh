//+------------------------------------------------------------------+
//|                                             SmartScalper_MTF.mqh |
//|                                  Copyright 2026, Institutional AI |
//|                     Multi-Timeframe Synchronization & Matrix      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"
#include "SmartScalper_FeatureEngine.mqh"
#include "SmartScalper_SMC.mqh"

//+------------------------------------------------------------------+
//| Multi-Timeframe Matrix Engine Class                              |
//+------------------------------------------------------------------+
class CSmartMTF
  {
private:
   string            m_symbol;
   CSmartFeatureEngine m_engine_h1;
   CSmartFeatureEngine m_engine_m15;
   CSmartFeatureEngine m_engine_m5;
   CSmartFeatureEngine m_engine_m1;

   CSmartSMC         m_smc_h1;
   CSmartSMC         m_smc_m15;
   CSmartSMC         m_smc_m5;
   CSmartSMC         m_smc_m1;

   MqlMTFState       m_state_h1;
   MqlMTFState       m_state_m15;
   MqlMTFState       m_state_m5;
   MqlMTFState       m_state_m1;

   bool              m_initialized;

public:
   CSmartMTF() : m_symbol(""), m_initialized(false)
     {
     }

   ~CSmartMTF()
     {
      ReleaseMTF();
     }

   //+---------------------------------------------------------------+
   //| Initialize all timeframe feature engines and SMC modules      |
   //+---------------------------------------------------------------+
   bool Init(string symbol)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      
      bool ok = true;
      ok &= m_engine_h1.Init(m_symbol, PERIOD_H1);
      ok &= m_engine_m15.Init(m_symbol, PERIOD_M15);
      ok &= m_engine_m5.Init(m_symbol, PERIOD_M5);
      ok &= m_engine_m1.Init(m_symbol, PERIOD_M1);

      m_smc_h1.Init(m_symbol, PERIOD_H1, 3);
      m_smc_m15.Init(m_symbol, PERIOD_M15, 4);
      m_smc_m5.Init(m_symbol, PERIOD_M5, 5);
      m_smc_m1.Init(m_symbol, PERIOD_M1, 5);

      m_initialized = ok;
      return m_initialized;
     }

   //+---------------------------------------------------------------+
   //| Release indicator resources                                   |
   //+---------------------------------------------------------------+
   void ReleaseMTF()
     {
      m_engine_h1.ReleaseHandles();
      m_engine_m15.ReleaseHandles();
      m_engine_m5.ReleaseHandles();
      m_engine_m1.ReleaseHandles();
      m_initialized = false;
     }

   //+---------------------------------------------------------------+
   //| Update and Sync All Timeframes                                |
   //+---------------------------------------------------------------+
   void UpdateAll()
     {
      if(!m_initialized) return;

      // Update SMC
      m_smc_h1.UpdateStructure(60);
      m_smc_m15.UpdateStructure(80);
      m_smc_m5.UpdateStructure(100);
      m_smc_m1.UpdateStructure(120);

      // Populate H1 State
      UpdateTFState(m_engine_h1, m_smc_h1, PERIOD_H1, m_state_h1);
      // Populate M15 State
      UpdateTFState(m_engine_m15, m_smc_m15, PERIOD_M15, m_state_m15);
      // Populate M5 State
      UpdateTFState(m_engine_m5, m_smc_m5, PERIOD_M5, m_state_m5);
      // Populate M1 State
      UpdateTFState(m_engine_m1, m_smc_m1, PERIOD_M1, m_state_m1);
     }

   //+---------------------------------------------------------------+
   //| Helper: Update State for a Specific Timeframe                 |
   //+---------------------------------------------------------------+
   void UpdateTFState(CSmartFeatureEngine &engine, CSmartSMC &smc,
                      ENUM_TIMEFRAMES tf, MqlMTFState &state)
     {
      state.timeframe = tf;
      double slope, dist;
      int align = 0;
      engine.GetTrendFeatures(state.ema9, state.ema20, state.ema50, state.ema200, slope, dist, align);

      double rsi_sl, macd_m, macd_s, macd_h, dip, dim, body_s;
      engine.GetMomentumFeatures(state.rsi, rsi_sl, macd_m, macd_s, macd_h, state.adx, dip, dim, body_s);
      state.atr = engine.GetCurrentATR();

      state.last_structure_event = smc.GetLastStructureEvent();
      state.last_event_time = smc.GetLastEventTime();

      // Directional bias synthesis
      int bias = 0;
      if(state.ema9 > state.ema20 && state.rsi >= 50.0) bias++;
      if(state.ema20 > state.ema50) bias++;
      if(state.ema50 > state.ema200) bias++;
      if(state.last_structure_event == STRUCT_BOS_BULL || state.last_structure_event == STRUCT_CHOCH_BULL || state.last_structure_event == STRUCT_SWEEP_SSL) bias += 2;

      if(state.ema9 < state.ema20 && state.rsi <= 50.0) bias--;
      if(state.ema20 < state.ema50) bias--;
      if(state.ema50 < state.ema200) bias--;
      if(state.last_structure_event == STRUCT_BOS_BEAR || state.last_structure_event == STRUCT_CHOCH_BEAR || state.last_structure_event == STRUCT_SWEEP_BSL) bias -= 2;

      if(bias >= 2) state.trend_direction = 1;
      else if(bias <= -2) state.trend_direction = -1;
      else state.trend_direction = 0;
     }

   //+---------------------------------------------------------------+
   //| Compute Weighted MTF Alignment Score (-10.0 to +10.0)         |
   //+---------------------------------------------------------------+
   double GetMTFAlignmentScore()
     {
      // Weights: H1 = 35%, M15 = 30%, M5 = 25%, M1 = 10%
      double score = 0.0;
      score += (double)m_state_h1.trend_direction * 3.5;
      score += (double)m_state_m15.trend_direction * 3.0;
      score += (double)m_state_m5.trend_direction * 2.5;
      score += (double)m_state_m1.trend_direction * 1.0;
      return score;
     }

   //+---------------------------------------------------------------+
   //| Check if lower timeframes agree with higher timeframe bias    |
   //+---------------------------------------------------------------+
   bool IsMTFAligned(bool is_buy)
     {
      int req_dir = is_buy ? 1 : -1;
      // Ensure H1 and M15 are not directly conflicting
      if(m_state_h1.trend_direction == -req_dir) return false;
      if(m_state_m15.trend_direction == -req_dir) return false;
      return true;
     }

   // Getters for specific state
   MqlMTFState GetH1State()  { return m_state_h1; }
   MqlMTFState GetM15State() { return m_state_m15; }
   MqlMTFState GetM5State()  { return m_state_m5; }
   MqlMTFState GetM1State()  { return m_state_m1; }

   CSmartFeatureEngine* GetM5Engine() { return GetPointer(m_engine_m5); }
   CSmartSMC*           GetM5SMC()    { return GetPointer(m_smc_m5); }
  };
