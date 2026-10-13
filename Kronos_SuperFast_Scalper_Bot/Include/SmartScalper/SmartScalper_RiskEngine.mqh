//+------------------------------------------------------------------+
//|                                      SmartScalper_RiskEngine.mqh |
//|                                  Copyright 2026, Institutional AI |
//|        Institutional Dynamic Position Sizing, SL, TP & RR Engine  |
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
//| Risk & Position Sizing Engine Class                              |
//+------------------------------------------------------------------+
class CSmartRiskEngine
  {
private:
   string m_symbol;

public:
   CSmartRiskEngine() : m_symbol("") {}

   void Init(string symbol)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
     }

   //+---------------------------------------------------------------+
   //| Calculate Dynamic Institutional Lot Size                      |
   //+---------------------------------------------------------------+
   double CalculateRiskLotSize(string symbol, double risk_percent, double entry_price, double sl_price, double regime_multiplier=1.0)
     {
      string sym = (symbol == "") ? m_symbol : symbol;
      if(!InpUseDynamicLot)
        {
         return NormalizeLotSize(sym, InpFixedLot);
        }

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0) equity = AccountInfoDouble(ACCOUNT_BALANCE);
      if(equity <= 0.0) return InpMinLot;

      double sl_dist = MathAbs(entry_price - sl_price);
      if(sl_dist <= 0.0) return NormalizeLotSize(sym, InpFixedLot);

      double tick_size  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double point      = SymbolInfoDouble(sym, SYMBOL_POINT);

      if(tick_size <= 0.0)  tick_size = (point > 0.0) ? point : 0.00001;
      if(tick_value <= 0.0) tick_value = 1.0;

      double effective_risk_pct = risk_percent * MathMax(0.1, regime_multiplier);
      double risk_amount = equity * (effective_risk_pct / 100.0);

      double ticks_at_risk = sl_dist / tick_size;
      double loss_per_lot  = ticks_at_risk * tick_value;

      if(loss_per_lot <= 0.0) return NormalizeLotSize(sym, InpFixedLot);

      double raw_lot = risk_amount / loss_per_lot;
      return NormalizeLotSize(sym, raw_lot);
     }

   //+---------------------------------------------------------------+
   //| Broker Volume Step Normalization & Boundary Clamping          |
   //+---------------------------------------------------------------+
   double NormalizeLotSize(string symbol, double lot)
     {
      string sym = (symbol == "") ? m_symbol : symbol;
      double min_lot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      double max_lot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
      double step_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

      if(min_lot <= 0.0)  min_lot = 0.01;
      if(max_lot <= 0.0)  max_lot = 100.0;
      if(step_lot <= 0.0) step_lot = 0.01;

      min_lot = MathMax(min_lot, InpMinLot);
      max_lot = MathMin(max_lot, InpMaxLot);
      if(max_lot > 0.40) max_lot = 0.40;

      // Floor to volume step
      double normalized = MathFloor(lot / step_lot) * step_lot;

      if(normalized < min_lot) normalized = min_lot;
      if(normalized > max_lot) normalized = max_lot;

      int lot_digits = 2;
      if(step_lot == 0.1)  lot_digits = 1;
      if(step_lot == 1.0)  lot_digits = 0;
      if(step_lot == 0.001) lot_digits = 3;

      return NormalizeDouble(normalized, lot_digits);
     }

   //+---------------------------------------------------------------+
   //| Calculate Institutional Dynamic Stop Loss                     |
   //+---------------------------------------------------------------+
   double CalculateDynamicSL(bool is_buy, double entry_price, CSmartSMC &smc, double atr_val)
     {
      // 100% SL-Free institutional architecture: Always returns 0.0!
      // Positions have full breathing room; exit governed strictly by Take Profit or Opposite Signal.
      return 0.0;
     }

   //+---------------------------------------------------------------+
   //| Calculate Institutional Dynamic Take Profit                   |
   //+---------------------------------------------------------------+
   double CalculateDynamicTP(bool is_buy, double entry_price, double sl_price, CSmartSMC &smc)
     {
      double point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int    digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      if(point <= 0.0) point = 0.00001;

      // Handle cases where sl_price is 0.0 (SL_MODE_OPPOSITE_SIGNAL) or abnormally distant
      double sl_dist = 0.0;
      if(sl_price > 0.0 && MathAbs(entry_price - sl_price) < (entry_price * 0.15))
        {
         sl_dist = MathAbs(entry_price - sl_price);
        }
      else
        {
         sl_dist = MathMax((double)InpMinSLPoints * point, 50.0);
        }

      if(sl_dist <= 0.0) sl_dist = (double)InpMinSLPoints * point;

      double min_tp_dist = sl_dist * InpMinimumRR;
      double target_tp_dist = sl_dist * InpTargetRR;

      // Safety: Never let target TP distance exceed 10% of market price
      if(target_tp_dist > entry_price * 0.10)
         target_tp_dist = entry_price * 0.02;

      double candidate_tp = 0.0;

      if(InpTPMode == TP_MODE_FIXED_RR)
        {
         candidate_tp = is_buy ? (entry_price + target_tp_dist) : (entry_price - target_tp_dist);
        }
      else if(InpTPMode == TP_MODE_LIQUIDITY_OB || InpTPMode == TP_MODE_HYBRID)
        {
         double liq_target = smc.GetNearestOpposingLiquidityTarget(is_buy);
         if(is_buy)
           {
            if(liq_target >= (entry_price + min_tp_dist))
               candidate_tp = liq_target;
            else
               candidate_tp = entry_price + target_tp_dist;
           }
         else
           {
            if(liq_target > 0.0 && liq_target <= (entry_price - min_tp_dist))
               candidate_tp = liq_target;
            else
               candidate_tp = entry_price - target_tp_dist;
           }
        }

      // Final directional safety clamping
      if(is_buy && candidate_tp <= entry_price)
         candidate_tp = entry_price + target_tp_dist;
      else if(!is_buy && (candidate_tp >= entry_price || candidate_tp <= 0.0))
         candidate_tp = entry_price - target_tp_dist;

      // Enforce Minimum Stop Level
      double min_stop_pts = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double min_broker_dist = (min_stop_pts + 5) * point;
      if(MathAbs(candidate_tp - entry_price) < min_broker_dist)
        {
         candidate_tp = is_buy ? (entry_price + min_broker_dist) : (entry_price - min_broker_dist);
        }

      // Absolute protection: TP must be strictly positive
      if(!is_buy && candidate_tp <= 0.0)
         candidate_tp = entry_price - min_broker_dist;

      return NormalizeDouble(candidate_tp, digits);
     }

   //+---------------------------------------------------------------+
   //| Validate Risk-Reward Ratio                                    |
   //+---------------------------------------------------------------+
   bool IsRRValid(double entry, double sl, double tp, double &out_rr)
     {
      if(InpSLMode == SL_MODE_OPPOSITE_SIGNAL)
        {
         out_rr = 2.0;
         return true; // Bypass strict RR floor when exiting on opposite signal
        }

      double sl_dist = MathAbs(entry - sl);
      double tp_dist = MathAbs(entry - tp);
      if(sl_dist <= 0.0) { out_rr = 0.0; return false; }

      out_rr = tp_dist / sl_dist;
      return (out_rr >= InpMinimumRR);
     }
  };
