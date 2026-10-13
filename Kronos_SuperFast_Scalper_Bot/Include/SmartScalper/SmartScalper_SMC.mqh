//+------------------------------------------------------------------+
//|                                             SmartScalper_SMC.mqh |
//|                                  Copyright 2026, Institutional AI |
//|          Non-Repainting Smart Money Concepts & Structure Engine   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"

//+------------------------------------------------------------------+
//| Smart Money Concepts Engine Class                                |
//+------------------------------------------------------------------+
class CSmartSMC
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;
   
   MqlSwingPoint     m_swing_highs[];
   MqlSwingPoint     m_swing_lows[];
   MqlFairValueGap   m_fvgs[];
   MqlOrderBlock     m_order_blocks[];
   
   ENUM_STRUCTURE_EVENT m_last_structure_event;
   datetime          m_last_event_time;
   
   double            m_current_range_high;
   double            m_current_range_low;
   double            m_equilibrium_price;

public:
   CSmartSMC() : m_symbol(""),
                 m_timeframe(PERIOD_M5),
                 m_lookback(5),
                 m_last_structure_event(STRUCT_NONE),
                 m_last_event_time(0),
                 m_current_range_high(0.0),
                 m_current_range_low(0.0),
                 m_equilibrium_price(0.0)
     {
      ArrayResize(m_swing_highs, 0);
      ArrayResize(m_swing_lows, 0);
      ArrayResize(m_fvgs, 0);
      ArrayResize(m_order_blocks, 0);
     }

   //+---------------------------------------------------------------+
   //| Initialize SMC Engine                                         |
   //+---------------------------------------------------------------+
   void Init(string symbol, ENUM_TIMEFRAMES tf, int lookback=5)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_timeframe = tf;
      m_lookback = MathMax(2, lookback);
     }

   //+---------------------------------------------------------------+
   //| Refresh & Compute Market Structure and SMC Events             |
   //+---------------------------------------------------------------+
   void UpdateStructure(int bars_to_scan=120)
     {
      int available_bars = iBars(m_symbol, m_timeframe);
      if(available_bars < m_lookback * 3 + 10) return;

      int scan_limit = MathMin(bars_to_scan, available_bars - m_lookback - 2);

      DetectSwingPoints(scan_limit);
      DetectFVGs(scan_limit);
      DetectOrderBlocks(scan_limit);
      EvaluateStructureAndSweeps();
      CalculateDealingRange();
     }

   //+---------------------------------------------------------------+
   //| Non-Repainting Swing High & Low Detection                     |
   //+---------------------------------------------------------------+
   void DetectSwingPoints(int scan_limit)
     {
      ArrayResize(m_swing_highs, 0);
      ArrayResize(m_swing_lows, 0);

      // Start scanning from right (most recent confirmed bar) to left
      for(int i = m_lookback + 1; i <= scan_limit; i++)
        {
         double cur_h = iHigh(m_symbol, m_timeframe, i);
         double cur_l = iLow(m_symbol, m_timeframe, i);
         datetime cur_t = iTime(m_symbol, m_timeframe, i);

         bool is_swing_high = true;
         bool is_swing_low = true;

         // Check left and right neighbor bars
         for(int j = 1; j <= m_lookback; j++)
           {
            if(iHigh(m_symbol, m_timeframe, i - j) >= cur_h || iHigh(m_symbol, m_timeframe, i + j) > cur_h)
               is_swing_high = false;
            if(iLow(m_symbol, m_timeframe, i - j) <= cur_l || iLow(m_symbol, m_timeframe, i + j) < cur_l)
               is_swing_low = false;
           }

         if(is_swing_high)
           {
            int sz = ArraySize(m_swing_highs);
            ArrayResize(m_swing_highs, sz + 1);
            m_swing_highs[sz].time = cur_t;
            m_swing_highs[sz].bar_index = i;
            m_swing_highs[sz].price = cur_h;
            m_swing_highs[sz].is_high = true;
            m_swing_highs[sz].is_major = (sz == 0 || MathAbs(cur_h - m_swing_highs[sz-1].price) > (iATR(m_symbol, m_timeframe, 14)));
            m_swing_highs[sz].is_swept = false;
           }

         if(is_swing_low)
           {
            int sz = ArraySize(m_swing_lows);
            ArrayResize(m_swing_lows, sz + 1);
            m_swing_lows[sz].time = cur_t;
            m_swing_lows[sz].bar_index = i;
            m_swing_lows[sz].price = cur_l;
            m_swing_lows[sz].is_high = false;
            m_swing_lows[sz].is_major = (sz == 0 || MathAbs(cur_l - m_swing_lows[sz-1].price) > (iATR(m_symbol, m_timeframe, 14)));
            m_swing_lows[sz].is_swept = false;
           }
        }
     }

   //+---------------------------------------------------------------+
   //| Detect Fair Value Gaps (FVG) with Mitigation Status           |
   //+---------------------------------------------------------------+
   void DetectFVGs(int scan_limit)
     {
      ArrayResize(m_fvgs, 0);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.00001;

      double min_gap = InpFVGMinSizePoints * point;

      for(int i = 1; i <= scan_limit; i++)
        {
         double low_bar0 = iLow(m_symbol, m_timeframe, i);
         double high_bar2 = iHigh(m_symbol, m_timeframe, i + 2);

         double high_bar0 = iHigh(m_symbol, m_timeframe, i);
         double low_bar2 = iLow(m_symbol, m_timeframe, i + 2);

         datetime t = iTime(m_symbol, m_timeframe, i + 1);

         // Bullish FVG: Low of Bar[i] > High of Bar[i+2]
         if(low_bar0 - high_bar2 >= min_gap)
           {
            int sz = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, sz + 1);
            m_fvgs[sz].time = t;
            m_fvgs[sz].bar_index = i + 1;
            m_fvgs[sz].is_bullish = true;
            m_fvgs[sz].top_price = low_bar0;
            m_fvgs[sz].bottom_price = high_bar2;
            m_fvgs[sz].mid_price = (low_bar0 + high_bar2) / 2.0;
            
            // Check if mitigated by bars between i and 0
            bool mitigated = false;
            for(int k = i - 1; k >= 0; k--)
              {
               if(iLow(m_symbol, m_timeframe, k) <= m_fvgs[sz].mid_price)
                 {
                  mitigated = true;
                  m_fvgs[sz].mitigation_time = iTime(m_symbol, m_timeframe, k);
                  break;
                 }
              }
            m_fvgs[sz].is_mitigated = mitigated;
           }
         // Bearish FVG: High of Bar[i] < Low of Bar[i+2]
         else if(low_bar2 - high_bar0 >= min_gap)
           {
            int sz = ArraySize(m_fvgs);
            ArrayResize(m_fvgs, sz + 1);
            m_fvgs[sz].time = t;
            m_fvgs[sz].bar_index = i + 1;
            m_fvgs[sz].is_bullish = false;
            m_fvgs[sz].top_price = low_bar2;
            m_fvgs[sz].bottom_price = high_bar0;
            m_fvgs[sz].mid_price = (low_bar2 + high_bar0) / 2.0;

            bool mitigated = false;
            for(int k = i - 1; k >= 0; k--)
              {
               if(iHigh(m_symbol, m_timeframe, k) >= m_fvgs[sz].mid_price)
                 {
                  mitigated = true;
                  m_fvgs[sz].mitigation_time = iTime(m_symbol, m_timeframe, k);
                  break;
                 }
              }
            m_fvgs[sz].is_mitigated = mitigated;
           }
        }
     }

   //+---------------------------------------------------------------+
   //| Detect Order Blocks (OB)                                      |
   //+---------------------------------------------------------------+
   void DetectOrderBlocks(int scan_limit)
     {
      ArrayResize(m_order_blocks, 0);
      int max_bars = MathMin(scan_limit, InpOBMitigationBars);

      for(int i = 2; i <= max_bars; i++)
        {
         double c_prev = iClose(m_symbol, m_timeframe, i);
         double o_prev = iOpen(m_symbol, m_timeframe, i);
         double c_disp = iClose(m_symbol, m_timeframe, i - 1);
         double o_disp = iOpen(m_symbol, m_timeframe, i - 1);
         
         double atr = iATR(m_symbol, m_timeframe, 14);
         if(atr <= 0) atr = 0.0010;

         // Bullish Demand OB: Bearish candle followed by strong bullish displacement
         if(c_prev < o_prev && c_disp > o_disp && (c_disp - o_disp) > 1.2 * atr)
           {
            int sz = ArraySize(m_order_blocks);
            ArrayResize(m_order_blocks, sz + 1);
            m_order_blocks[sz].time = iTime(m_symbol, m_timeframe, i);
            m_order_blocks[sz].bar_index = i;
            m_order_blocks[sz].is_bullish = true;
            m_order_blocks[sz].high_price = iHigh(m_symbol, m_timeframe, i);
            m_order_blocks[sz].low_price = iLow(m_symbol, m_timeframe, i);
            m_order_blocks[sz].open_price = o_prev;
            m_order_blocks[sz].close_price = c_prev;
            
            // Check if mitigated
            bool mitigated = false;
            for(int k = i - 2; k >= 0; k--)
              {
               if(iLow(m_symbol, m_timeframe, k) <= m_order_blocks[sz].high_price)
                 {
                  mitigated = true;
                  break;
                 }
              }
            m_order_blocks[sz].is_mitigated = mitigated;
            m_order_blocks[sz].strength = (int)MathMin(5, MathMax(1, (c_disp - o_disp) / atr));
           }
         // Bearish Supply OB: Bullish candle followed by strong bearish displacement
         else if(c_prev > o_prev && c_disp < o_disp && (o_disp - c_disp) > 1.2 * atr)
           {
            int sz = ArraySize(m_order_blocks);
            ArrayResize(m_order_blocks, sz + 1);
            m_order_blocks[sz].time = iTime(m_symbol, m_timeframe, i);
            m_order_blocks[sz].bar_index = i;
            m_order_blocks[sz].is_bullish = false;
            m_order_blocks[sz].high_price = iHigh(m_symbol, m_timeframe, i);
            m_order_blocks[sz].low_price = iLow(m_symbol, m_timeframe, i);
            m_order_blocks[sz].open_price = o_prev;
            m_order_blocks[sz].close_price = c_prev;

            bool mitigated = false;
            for(int k = i - 2; k >= 0; k--)
              {
               if(iHigh(m_symbol, m_timeframe, k) >= m_order_blocks[sz].low_price)
                 {
                  mitigated = true;
                  break;
                 }
              }
            m_order_blocks[sz].is_mitigated = mitigated;
            m_order_blocks[sz].strength = (int)MathMin(5, MathMax(1, (o_disp - c_disp) / atr));
           }
        }
     }

   //+---------------------------------------------------------------+
   //| Evaluate Structure Breaks (BOS / CHoCH) and Liquidity Sweeps  |
   //+---------------------------------------------------------------+
   void EvaluateStructureAndSweeps()
     {
      m_last_structure_event = STRUCT_NONE;

      int h_count = ArraySize(m_swing_highs);
      int l_count = ArraySize(m_swing_lows);
      if(h_count < 2 || l_count < 2) return;

      double last_swing_high = m_swing_highs[0].price;
      double last_swing_low  = m_swing_lows[0].price;
      double prev_swing_high = m_swing_highs[1].price;
      double prev_swing_low  = m_swing_lows[1].price;

      double bar1_high  = iHigh(m_symbol, m_timeframe, 1);
      double bar1_low   = iLow(m_symbol, m_timeframe, 1);
      double bar1_close = iClose(m_symbol, m_timeframe, 1);

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.00001;
      double sweep_buf = InpSweepBufferPoints * point;

      // 1. Check Buy-Side Liquidity Sweep (BSL): High pierced swing high, close came back below
      if(bar1_high >= last_swing_high + sweep_buf && bar1_close < last_swing_high)
        {
         m_last_structure_event = STRUCT_SWEEP_BSL;
         m_last_event_time = iTime(m_symbol, m_timeframe, 1);
         return;
        }

      // 2. Check Sell-Side Liquidity Sweep (SSL): Low pierced swing low, close came back above
      if(bar1_low <= last_swing_low - sweep_buf && bar1_close > last_swing_low)
        {
         m_last_structure_event = STRUCT_SWEEP_SSL;
         m_last_event_time = iTime(m_symbol, m_timeframe, 1);
         return;
        }

      // 3. Check Bullish Break of Structure (BOS) vs Change of Character (CHoCH)
      if(bar1_close > last_swing_high)
        {
         // If prior structure was in a downtrend (LH series), breaking above is CHoCH
         if(last_swing_high < prev_swing_high)
            m_last_structure_event = STRUCT_CHOCH_BULL;
         else
            m_last_structure_event = STRUCT_BOS_BULL;

         m_last_event_time = iTime(m_symbol, m_timeframe, 1);
         return;
        }

      // 4. Check Bearish Break of Structure (BOS) vs Change of Character (CHoCH)
      if(bar1_close < last_swing_low)
        {
         // If prior structure was in an uptrend (HL series), breaking below is CHoCH
         if(last_swing_low > prev_swing_low)
            m_last_structure_event = STRUCT_CHOCH_BEAR;
         else
            m_last_structure_event = STRUCT_BOS_BEAR;

         m_last_event_time = iTime(m_symbol, m_timeframe, 1);
         return;
        }
     }

   //+---------------------------------------------------------------+
   //| Calculate Active Dealing Range & Equilibrium (50%)            |
   //+---------------------------------------------------------------+
   void CalculateDealingRange()
     {
      int h_count = ArraySize(m_swing_highs);
      int l_count = ArraySize(m_swing_lows);

      if(h_count > 0 && l_count > 0)
        {
         m_current_range_high = m_swing_highs[0].price;
         m_current_range_low  = m_swing_lows[0].price;
         m_equilibrium_price  = (m_current_range_high + m_current_range_low) / 2.0;
        }
      else
        {
         m_current_range_high = iHigh(m_symbol, m_timeframe, 1);
         m_current_range_low  = iLow(m_symbol, m_timeframe, 1);
         m_equilibrium_price  = (m_current_range_high + m_current_range_low) / 2.0;
        }
     }

   //+---------------------------------------------------------------+
   //| Check if Current Price is in Discount (Favors BUY)            |
   //+---------------------------------------------------------------+
   bool IsInDiscountZone()
     {
      double cur_price = iClose(m_symbol, m_timeframe, 0);
      return (cur_price <= m_equilibrium_price);
     }

   //+---------------------------------------------------------------+
   //| Check if Current Price is in Premium (Favors SELL)            |
   //+---------------------------------------------------------------+
   bool IsInPremiumZone()
     {
      double cur_price = iClose(m_symbol, m_timeframe, 0);
      return (cur_price >= m_equilibrium_price);
     }

   //+---------------------------------------------------------------+
   //| Get Most Recent Unmitigated FVG in Direction                  |
   //+---------------------------------------------------------------+
   bool GetNearestUnmitigatedFVG(bool bullish, MqlFairValueGap &out_fvg)
     {
      int sz = ArraySize(m_fvgs);
      for(int i = 0; i < sz; i++)
        {
         if(m_fvgs[i].is_bullish == bullish && !m_fvgs[i].is_mitigated)
           {
            out_fvg = m_fvgs[i];
            return true;
           }
        }
      return false;
     }

   //+---------------------------------------------------------------+
   //| Get Most Recent Unmitigated Order Block in Direction          |
   //+---------------------------------------------------------------+
   bool GetNearestUnmitigatedOB(bool bullish, MqlOrderBlock &out_ob)
     {
      int sz = ArraySize(m_order_blocks);
      for(int i = 0; i < sz; i++)
        {
         if(m_order_blocks[i].is_bullish == bullish && !m_order_blocks[i].is_mitigated)
           {
            out_ob = m_order_blocks[i];
            return true;
           }
        }
      return false;
     }

   //+---------------------------------------------------------------+
   //| Get Nearest Structural Swing Level for SL                     |
   //+---------------------------------------------------------------+
   double GetNearestSwingSL(bool is_buy)
     {
      if(is_buy)
        {
         int sz = ArraySize(m_swing_lows);
         if(sz > 0) return m_swing_lows[0].price;
         return iLow(m_symbol, m_timeframe, 1);
        }
      else
        {
         int sz = ArraySize(m_swing_highs);
         if(sz > 0) return m_swing_highs[0].price;
         return iHigh(m_symbol, m_timeframe, 1);
        }
     }

   //+---------------------------------------------------------------+
   //| Get Nearest Opposing Swing Level for TP                       |
   //+---------------------------------------------------------------+
   double GetNearestOpposingLiquidityTarget(bool is_buy)
     {
      if(is_buy)
        {
         int sz = ArraySize(m_swing_highs);
         if(sz > 0) return m_swing_highs[0].price;
         return iHigh(m_symbol, m_timeframe, 1);
        }
      else
        {
         int sz = ArraySize(m_swing_lows);
         if(sz > 0) return m_swing_lows[0].price;
         return iLow(m_symbol, m_timeframe, 1);
        }
     }

   // Getters
   ENUM_STRUCTURE_EVENT GetLastStructureEvent() { return m_last_structure_event; }
   datetime             GetLastEventTime()      { return m_last_event_time; }
   double               GetRangeHigh()          { return m_current_range_high; }
   double               GetRangeLow()           { return m_current_range_low; }
   double               GetEquilibrium()        { return m_equilibrium_price; }
  };
