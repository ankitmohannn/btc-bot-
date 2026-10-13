//+------------------------------------------------------------------+
//|                                    SmartScalper_FeatureEngine.mqh |
//|                                  Copyright 2026, Institutional AI |
//|             Deterministic Multi-Indicator & Feature Calculation   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"

//+------------------------------------------------------------------+
//| Feature Engine Class                                             |
//+------------------------------------------------------------------+
class CSmartFeatureEngine
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   
   // Indicator handles for primary timeframe
   int               m_h_ema9;
   int               m_h_ema20;
   int               m_h_ema50;
   int               m_h_ema200;
   int               m_h_rsi;
   int               m_h_macd;
   int               m_h_adx;
   int               m_h_atr;
   
   bool              m_initialized;

public:
   CSmartFeatureEngine() : m_symbol(""),
                           m_timeframe(PERIOD_M5),
                           m_h_ema9(INVALID_HANDLE),
                           m_h_ema20(INVALID_HANDLE),
                           m_h_ema50(INVALID_HANDLE),
                           m_h_ema200(INVALID_HANDLE),
                           m_h_rsi(INVALID_HANDLE),
                           m_h_macd(INVALID_HANDLE),
                           m_h_adx(INVALID_HANDLE),
                           m_h_atr(INVALID_HANDLE),
                           m_initialized(false)
     {
     }

   ~CSmartFeatureEngine()
     {
      ReleaseHandles();
     }

   //+---------------------------------------------------------------+
   //| Initialize all indicator handles                              |
   //+---------------------------------------------------------------+
   bool Init(string symbol, ENUM_TIMEFRAMES tf)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_timeframe = tf;
      
      ReleaseHandles();

      m_h_ema9   = iMA(m_symbol, m_timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
      m_h_ema20  = iMA(m_symbol, m_timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
      m_h_ema50  = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_h_ema200 = iMA(m_symbol, m_timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_h_rsi    = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
      m_h_macd   = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
      m_h_adx    = iADX(m_symbol, m_timeframe, 14);
      m_h_atr    = iATR(m_symbol, m_timeframe, InpATRPeriod);

      if(m_h_ema9 == INVALID_HANDLE || m_h_ema20 == INVALID_HANDLE ||
         m_h_ema50 == INVALID_HANDLE || m_h_ema200 == INVALID_HANDLE ||
         m_h_rsi == INVALID_HANDLE || m_h_macd == INVALID_HANDLE ||
         m_h_adx == INVALID_HANDLE || m_h_atr == INVALID_HANDLE)
        {
         PrintFormat("❌ [FeatureEngine] Failed to create indicator handles for %s %s", m_symbol, EnumToString(m_timeframe));
         m_initialized = false;
         return false;
        }

      m_initialized = true;
      return true;
     }

   //+---------------------------------------------------------------+
   //| Release indicator handles properly                            |
   //+---------------------------------------------------------------+
   void ReleaseHandles()
     {
      if(m_h_ema9 != INVALID_HANDLE)   { IndicatorRelease(m_h_ema9);   m_h_ema9 = INVALID_HANDLE; }
      if(m_h_ema20 != INVALID_HANDLE)  { IndicatorRelease(m_h_ema20);  m_h_ema20 = INVALID_HANDLE; }
      if(m_h_ema50 != INVALID_HANDLE)  { IndicatorRelease(m_h_ema50);  m_h_ema50 = INVALID_HANDLE; }
      if(m_h_ema200 != INVALID_HANDLE) { IndicatorRelease(m_h_ema200); m_h_ema200 = INVALID_HANDLE; }
      if(m_h_rsi != INVALID_HANDLE)    { IndicatorRelease(m_h_rsi);    m_h_rsi = INVALID_HANDLE; }
      if(m_h_macd != INVALID_HANDLE)   { IndicatorRelease(m_h_macd);   m_h_macd = INVALID_HANDLE; }
      if(m_h_adx != INVALID_HANDLE)    { IndicatorRelease(m_h_adx);    m_h_adx = INVALID_HANDLE; }
      if(m_h_atr != INVALID_HANDLE)    { IndicatorRelease(m_h_atr);    m_h_atr = INVALID_HANDLE; }
      m_initialized = false;
     }

   //+---------------------------------------------------------------+
   //| Calculate Trend Features                                      |
   //+---------------------------------------------------------------+
   bool GetTrendFeatures(double &ema9, double &ema20, double &ema50, double &ema200,
                         double &ema9_slope, double &price_dist_ema20, int &trend_alignment)
     {
      if(!m_initialized) return false;

      double buf_ema9[3], buf_ema20[2], buf_ema50[2], buf_ema200[2];
      if(CopyBuffer(m_h_ema9, 0, 0, 3, buf_ema9) < 3 ||
         CopyBuffer(m_h_ema20, 0, 0, 2, buf_ema20) < 2 ||
         CopyBuffer(m_h_ema50, 0, 0, 2, buf_ema50) < 2 ||
         CopyBuffer(m_h_ema200, 0, 0, 2, buf_ema200) < 2)
        {
         return false;
        }

      // CopyBuffer index 0 is oldest in buffer chunk; index 2 is current bar
      ema9   = buf_ema9[2];
      ema20  = buf_ema20[1];
      ema50  = buf_ema50[1];
      ema200 = buf_ema200[1];

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.00001;

      // EMA 9 slope over last 2 bars in points
      ema9_slope = (buf_ema9[2] - buf_ema9[0]) / (2.0 * point);

      // Price distance from EMA 20 in points
      double close_price = iClose(m_symbol, m_timeframe, 0);
      price_dist_ema20 = (close_price - ema20) / point;

      // Trend Alignment: +1 = Bullish Stacked (9 > 20 > 50 > 200), -1 = Bearish Stacked, 0 = Mixed
      if(ema9 > ema20 && ema20 > ema50 && ema50 > ema200)
         trend_alignment = 1;
      else if(ema9 < ema20 && ema20 < ema50 && ema50 < ema200)
         trend_alignment = -1;
      else if(ema9 > ema20 && ema20 > ema50)
         trend_alignment = 1; // Short-term bullish
      else if(ema9 < ema20 && ema20 < ema50)
         trend_alignment = -1; // Short-term bearish
      else
         trend_alignment = 0;

      return true;
     }

   //+---------------------------------------------------------------+
   //| Calculate Momentum Features                                   |
   //+---------------------------------------------------------------+
   bool GetMomentumFeatures(double &rsi, double &rsi_slope, double &macd_main, double &macd_signal,
                           double &macd_hist, double &adx_val, double &di_plus, double &di_minus,
                           double &candle_body_strength)
     {
      if(!m_initialized) return false;

      double buf_rsi[3], buf_macd_main[2], buf_macd_sig[2];
      double buf_adx[2], buf_di_plus[2], buf_di_minus[2];

      if(CopyBuffer(m_h_rsi, 0, 0, 3, buf_rsi) < 3 ||
         CopyBuffer(m_h_macd, 0, 0, 2, buf_macd_main) < 2 ||
         CopyBuffer(m_h_macd, 1, 0, 2, buf_macd_sig) < 2 ||
         CopyBuffer(m_h_adx, 0, 0, 2, buf_adx) < 2 ||
         CopyBuffer(m_h_adx, 1, 0, 2, buf_di_plus) < 2 ||
         CopyBuffer(m_h_adx, 2, 0, 2, buf_di_minus) < 2)
        {
         return false;
        }

      rsi = buf_rsi[2];
      rsi_slope = buf_rsi[2] - buf_rsi[0];

      macd_main = buf_macd_main[1];
      macd_signal = buf_macd_sig[1];
      macd_hist = macd_main - macd_signal;

      adx_val = buf_adx[1];
      di_plus = buf_di_plus[1];
      di_minus = buf_di_minus[1];

      // Candle body strength ratio (Bar 1)
      double o = iOpen(m_symbol, m_timeframe, 1);
      double c = iClose(m_symbol, m_timeframe, 1);
      double h = iHigh(m_symbol, m_timeframe, 1);
      double l = iLow(m_symbol, m_timeframe, 1);
      double total_range = h - l;
      double body_range = MathAbs(c - o);

      if(total_range > 0.0)
         candle_body_strength = (body_range / total_range) * 100.0;
      else
         candle_body_strength = 50.0;

      return true;
     }

   //+---------------------------------------------------------------+
   //| Calculate Volatility Features                                 |
   //+---------------------------------------------------------------+
   bool GetVolatilityFeatures(double &atr_current, double &atr_percentile,
                              double &range_expansion_ratio)
     {
      if(!m_initialized) return false;

      double buf_atr[100];
      int copied = CopyBuffer(m_h_atr, 0, 0, 100, buf_atr);
      if(copied < 20) return false;

      atr_current = buf_atr[copied - 1];

      // Calculate ATR percentile rank in the 100-bar sample
      int rank_count = 0;
      for(int i = 0; i < copied; i++)
        {
         if(buf_atr[i] <= atr_current) rank_count++;
        }
      atr_percentile = ((double)rank_count / (double)copied) * 100.0;

      // Volatility expansion ratio: current ATR vs 50-bar average ATR
      double atr_sum = 0.0;
      int avg_samples = MathMin(50, copied);
      for(int i = copied - avg_samples; i < copied; i++)
        {
         atr_sum += buf_atr[i];
        }
      double atr_avg = atr_sum / (double)avg_samples;
      if(atr_avg > 0.0)
         range_expansion_ratio = atr_current / atr_avg;
      else
         range_expansion_ratio = 1.0;

      return true;
     }

   //+---------------------------------------------------------------+
   //| Quick ATR Getter                                              |
   //+---------------------------------------------------------------+
   double GetCurrentATR()
     {
      if(!m_initialized) return 0.0;
      double buf[1];
      if(CopyBuffer(m_h_atr, 0, 0, 1, buf) > 0)
         return buf[0];
      return 0.0;
     }
  };
