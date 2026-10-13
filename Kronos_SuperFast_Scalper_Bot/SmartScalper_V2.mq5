//+------------------------------------------------------------------+
//|                                            SmartScalper_V2.mq5   |
//|                                  Copyright 2026, Institutional AI |
//|          AI-Enhanced Institutional MT5 Smart Scalper (Vibe-Trading)|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI / HKUDS Vibe-Trading"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property description "Institutional MT5 Smart Scalper EA with Non-Repainting SMC, MTF Matrix, Regime Engine, Explainable 0-100 Scoring & Resilient AI Bridge"
#property strict

// Include all modular subsystems
#include "Include\SmartScalper\SmartScalper_Types.mqh"
#include "Include\SmartScalper\SmartScalper_Config.mqh"
#include "Include\SmartScalper\SmartScalper_FeatureEngine.mqh"
#include "Include\SmartScalper\SmartScalper_SMC.mqh"
#include "Include\SmartScalper\SmartScalper_MTF.mqh"
#include "Include\SmartScalper\SmartScalper_Regime.mqh"
#include "Include\SmartScalper\SmartScalper_Scoring.mqh"
#include "Include\SmartScalper\SmartScalper_RiskEngine.mqh"
#include "Include\SmartScalper\SmartScalper_TradeManager.mqh"
#include "Include\SmartScalper\SmartScalper_Filters.mqh"
#include "Include\SmartScalper\SmartScalper_AIBridge.mqh"
#include "Include\SmartScalper\SmartScalper_Journal.mqh"
#include "Include\SmartScalper\SmartScalper_HUD.mqh"
#include "Include\SmartScalper\SmartScalper_VolatilityShield.mqh"
#include "Include\SmartScalper\SmartScalper_Telegram.mqh"

// Subsystem Engine Instances
CSmartFeatureEngine    g_features_m5;
CSmartSMC              g_smc_m5;
CSmartMTF              g_mtf;
CSmartRegimeEngine     g_regime_engine;
CSmartScoringEngine    g_scoring_engine;
CSmartRiskEngine       g_risk_engine;
CSmartTradeManager     g_trade_manager;
CSmartFilters          g_filters;
CSmartAIBridge         g_ai_bridge;
CSmartJournal          g_journal;
CSmartHUD              g_hud;
CSmartVolatilityShield g_vol_shield;
CSmartTelegram         g_telegram;

// Active System State
ENUM_MARKET_REGIME  g_current_regime = REGIME_NO_TRADE;
ENUM_SESSION_TYPE   g_current_session = SESSION_CLOSED;
string              g_active_signal_dir = "HOLD";
string              g_prev_signal_dir = "HOLD";  // Track previous signal for direction-change alerts
double              g_active_score = 0.0;
double              g_active_ai_conf = 0.0;
bool                g_ai_online = false;
string              g_gate_filter_status = "READY";
double              g_candidate_lot = 0.01;
double              g_candidate_rr = 2.0;
double              g_current_atr = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("🚀 [INIT] Initializing SmartScalper V2 Institutional Architecture...");

   g_features_m5.Init(_Symbol, PERIOD_M5);
   g_smc_m5.Init(_Symbol, PERIOD_M5, InpSwingLookback);
   g_mtf.Init(_Symbol);
   g_regime_engine.Init(_Symbol, PERIOD_M5);
   g_scoring_engine.Init(_Symbol);
   g_risk_engine.Init(_Symbol);
   g_trade_manager.Init(_Symbol);
   g_telegram.Init(InpEnableTelegram, InpTelegramBotToken, InpTelegramChatID);
   g_trade_manager.SetTelegram(&g_telegram);
   g_filters.Init(_Symbol);
   g_ai_bridge.Init(_Symbol);
   g_journal.Init(_Symbol);
   g_vol_shield.Init(_Symbol, PERIOD_M5);
   g_vol_shield.Configure(InpEnableVolShield,
                          InpVolFastPeriod,
                          InpVolSlowPeriod,
                          InpTailRiskLookback,
                          InpVolHighRatioThreshold,
                          InpVolExtremeRatioThreshold,
                          InpTailRiskBlockThreshold,
                          InpBlockExtremeVol,
                          InpMaxSymbolExposureLots);

   // Configure Millisecond Timer
   EventSetMillisecondTimer(MathMax(100, InpTimerFrequencyMS));

   // Initial calculation run
   ProcessMarketCycle();

   Print("✅ [INIT_SUCCESS] SmartScalper V2 Initialized Successfully.");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_filters.PrintRejectionBreakdown();
   g_features_m5.ReleaseHandles();
   g_mtf.ReleaseMTF();
   g_hud.RemoveHUD();
   PrintFormat("🛑 [DEINIT] SmartScalper V2 Deinitialized (Reason: %d)", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function (High-Speed Trade Management)               |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Manage Smart Basket DCA Exits (Target Profit + Emergency Stop Loss)
   double basket_pnl = 0.0;
   int basket_count = 0;
   double avg_entry = 0.0;
   bool basket_closed = false;

   if(InpEnableBasketDCA)
     {
      basket_closed = g_trade_manager.ManageBasketExits(basket_pnl, basket_count, avg_entry);
      if(basket_closed)
        {
         g_telegram.SendBasketClosedAlert(_Symbol, basket_pnl, (basket_pnl >= 0), basket_count);
        }
     }

   // In Strategy Tester, evaluate market cycle on ticks
   if(MQLInfoInteger(MQL_TESTER))
     {
      ProcessMarketCycle();
     }
  }

//+------------------------------------------------------------------+
//| Timer function (Runs at InpTimerFrequencyMS e.g. 250ms)         |
//+------------------------------------------------------------------+
void OnTimer()
  {
   ProcessMarketCycle();
  }

//+------------------------------------------------------------------+
//| Master Market Cycle Engine                                       |
//+------------------------------------------------------------------+
void ProcessMarketCycle()
  {
   // 1. Calculate Current Spread
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) point = 0.00001;
   double spread_pts = (ask - bid) / point;

   // 2. Update SMC Structure & Features
   g_smc_m5.UpdateStructure(100);
   g_mtf.UpdateAll();
   g_current_atr = g_features_m5.GetCurrentATR();
   g_current_session = g_filters.GetCurrentSession();

   // 3. Classify Market Regime
   g_current_regime = g_regime_engine.ClassifyRegime(g_features_m5, g_smc_m5, spread_pts);

   // 4. Ingest / Sync AI Bridge Signal Packet
   MqlAISignalPacket ai_packet;
   g_ai_online = g_ai_bridge.IngestSignalPacket(ai_packet);
   g_active_ai_conf = g_ai_online ? ai_packet.confidence : 0.0;

   // 5. Evaluate Long and Short Signals
   bool recent_buy_profit = g_filters.IsRecentProfitDirection("BUY", InpTrendBoosterMaxMins * 60);
   bool recent_sell_profit = g_filters.IsRecentProfitDirection("SELL", InpTrendBoosterMaxMins * 60);
   MqlScoreBreakdown score_buy, score_sell;
   g_scoring_engine.EvaluateSignal(true, g_features_m5, g_smc_m5, g_mtf, g_current_regime, g_current_session, spread_pts, g_active_ai_conf, recent_buy_profit, score_buy);
   g_scoring_engine.EvaluateSignal(false, g_features_m5, g_smc_m5, g_mtf, g_current_regime, g_current_session, spread_pts, g_active_ai_conf, recent_sell_profit, score_sell);

   // Determine Candidate Direction
   g_prev_signal_dir = g_active_signal_dir;  // Save previous for direction-change detection
   bool candidate_is_buy = false;
   if(score_buy.total_score >= score_sell.total_score && score_buy.total_score >= 60.0)
     {
      g_active_signal_dir = "BUY";
      g_active_score = score_buy.total_score;
      candidate_is_buy = true;
     }
   else if(score_sell.total_score > score_buy.total_score && score_sell.total_score >= 60.0)
     {
      g_active_signal_dir = "SELL";
      g_active_score = score_sell.total_score;
      candidate_is_buy = false;
     }
   else
     {
      g_active_signal_dir = "HOLD";
      g_active_score = MathMax(score_buy.total_score, score_sell.total_score);
     }

   // 6. Calculate Dynamic SL, TP, RR & Lot Size
   double entry_price = candidate_is_buy ? ask : bid;
   double candidate_sl = g_risk_engine.CalculateDynamicSL(candidate_is_buy, entry_price, g_smc_m5, g_current_atr);
   double sizing_sl = (candidate_sl > 0.0) ? candidate_sl : (candidate_is_buy ? entry_price - (MathMax(50.0, g_current_atr * 2.0)) : entry_price + (MathMax(50.0, g_current_atr * 2.0)));
   double candidate_tp = g_risk_engine.CalculateDynamicTP(candidate_is_buy, entry_price, sizing_sl, g_smc_m5);
   
   double actual_rr = 0.0;
   g_risk_engine.IsRRValid(entry_price, candidate_sl, candidate_tp, actual_rr);
   g_candidate_rr = actual_rr;

   double regime_mult = g_regime_engine.GetRegimeRiskMultiplier(g_current_regime);
   g_candidate_lot = g_risk_engine.CalculateRiskLotSize(_Symbol, InpRiskPercent, entry_price, sizing_sl, regime_mult);

   // 7. Export Feature Packet to AI Bridge
   MqlFeaturePacket feat_packet;
   feat_packet.symbol = _Symbol;
   feat_packet.timestamp = TimeCurrent();
   feat_packet.bid = bid;
   feat_packet.ask = ask;
   feat_packet.spread_points = spread_pts;
   feat_packet.timeframe_seconds = PeriodSeconds(PERIOD_M5);
   feat_packet.open = iOpen(_Symbol, PERIOD_M5, 0);
   feat_packet.high = iHigh(_Symbol, PERIOD_M5, 0);
   feat_packet.low = iLow(_Symbol, PERIOD_M5, 0);
   feat_packet.close = iClose(_Symbol, PERIOD_M5, 0);
   feat_packet.tick_volume = iTickVolume(_Symbol, PERIOD_M5, 0);
   feat_packet.atr_m5 = g_current_atr;

   double ema9 = 0, ema20 = 0, ema50 = 0, ema200 = 0, ema9_slope = 0, dist_ema20 = 0;
   int trend_align = 0;
   if(g_features_m5.GetTrendFeatures(ema9, ema20, ema50, ema200, ema9_slope, dist_ema20, trend_align))
     {
      feat_packet.ema9_m5 = ema9;
      feat_packet.ema20_m5 = ema20;
      feat_packet.ema50_m5 = ema50;
      feat_packet.ema200_m5 = ema200;
     }

   double rsi = 50, rsi_slope = 0, macd_m = 0, macd_s = 0, macd_h = 0, adx = 20, di_p = 0, di_m = 0, body_str = 50;
   if(g_features_m5.GetMomentumFeatures(rsi, rsi_slope, macd_m, macd_s, macd_h, adx, di_p, di_m, body_str))
     {
      feat_packet.rsi_m5 = rsi;
      feat_packet.adx_m5 = adx;
     }

   feat_packet.regime_id = (int)g_current_regime;
   feat_packet.structure_id = (int)g_smc_m5.GetLastStructureEvent();
   feat_packet.session_id = (int)g_current_session;
   feat_packet.recent_win_rate = 75.0;
   feat_packet.consecutive_losses = g_filters.GetConsecutiveLosses();
   g_ai_bridge.ExportFeaturePacket(feat_packet);

   // 8. Quality Filter Gating & Execution Decision
   int open_positions = g_trade_manager.GetOpenPositionsCount();
   string rejection_msg = "";

   if(g_active_signal_dir == "BUY" || g_active_signal_dir == "SELL")
     {
      // A. Priority Reversal Flip: Liquidate opposite positions immediately upon confirmed signal
      double closed_opp_pnl = 0.0;
      int opp_closed = g_trade_manager.CloseOppositePositions(candidate_is_buy, closed_opp_pnl, "Signal Reversal Flip");
      if(opp_closed > 0)
        {
         PrintFormat("🔄 [SIGNAL_REVERSAL] Closed %d opposite trades. Realized PnL: %s$%.2f USD. Resetting basket for %s.",
                     opp_closed, (closed_opp_pnl >= 0 ? "+" : ""), closed_opp_pnl, g_active_signal_dir);
         open_positions = g_trade_manager.GetOpenPositionsCount();
        }

      bool allowed_by_regime = g_regime_engine.IsRegimeDirectionAllowed(g_current_regime, candidate_is_buy);
      if(!allowed_by_regime)
        {
         g_filters.RecordRegimeRejection();
         g_gate_filter_status = "Blocked by Regime";
        }
      else if(actual_rr < InpMinimumRR)
        {
         g_filters.RecordRRRejection();
         g_gate_filter_status = StringFormat("RR Too Low (1:%.2f < 1:%.2f)", actual_rr, InpMinimumRR);
        }
      else
        {
         bool passed_filters = g_filters.ValidateEntryQuality(candidate_is_buy,
                                                             g_active_score,
                                                             spread_pts,
                                                             open_positions,
                                                             g_active_ai_conf,
                                                             g_ai_online,
                                                             rejection_msg);
         g_gate_filter_status = rejection_msg;

         if(passed_filters)
           {
            open_positions = g_trade_manager.GetOpenPositionsCount();
            double current_basket_vol = g_trade_manager.GetOpenPositionsTotalVolume(candidate_is_buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

            if(open_positions >= InpMaxOpenTrades)
              {
               g_gate_filter_status = StringFormat("MAX_POSITIONS_REACHED (%d/%d)", open_positions, InpMaxOpenTrades);
              }
            else if(current_basket_vol >= InpMaxTotalBasketLots)
              {
               g_gate_filter_status = StringFormat("MAX_BASKET_LOTS_REACHED (%.2f >= %.2f Lots)", current_basket_vol, InpMaxTotalBasketLots);
              }
            else
              {
               // Evaluate Volatility Clustering & Tail-Risk Shield
               MqlVolShieldAssessment vol_assess;
               double signal_confidence_val = (g_ai_online ? g_active_ai_conf : g_active_score);
               g_vol_shield.AssessVolatilityAndTailRisk(g_candidate_lot, signal_confidence_val, vol_assess);
               g_vol_shield.LogAssessment(vol_assess);

               if(!vol_assess.is_trade_allowed)
                 {
                  g_gate_filter_status = vol_assess.decision_reason;
                 }
               else
                 {
                  double final_lot = vol_assess.adjusted_lot;
                  if(final_lot > InpMaxLot) final_lot = InpMaxLot;
                  if(final_lot > 0.40) final_lot = 0.40;

                  // Enforce hard ceiling on total basket volume
                  if(current_basket_vol + final_lot > InpMaxTotalBasketLots)
                    {
                     final_lot = InpMaxTotalBasketLots - current_basket_vol;
                     final_lot = MathFloor(final_lot * 100.0) / 100.0;
                    }

                  if(final_lot >= 0.01)
                    {
                     string comment = StringFormat("SSV2 %s (Score:%.0f|AI:%.0f|VS:%.2f)", g_active_signal_dir, g_active_score, g_active_ai_conf, vol_assess.risk_multiplier);
                     ulong ticket = 0;
                     if(g_trade_manager.ExecuteMarketOrder(candidate_is_buy, final_lot, candidate_sl, candidate_tp, comment, ticket))
                       {
                        g_filters.OnTradeExecuted(g_active_signal_dir);
                        PrintFormat("🏆 [SIGNAL_EXPLANATION] %s", (candidate_is_buy ? score_buy.explanation : score_sell.explanation));

                        // Telegram: Send VIP Institutional Trade Execution Alert with full reasons
                        double entry_exec_price = candidate_is_buy ? ask : bid;
                        double exec_risk_dist = MathAbs(entry_exec_price - candidate_sl);
                        double exec_tp1 = candidate_is_buy ? (entry_exec_price + exec_risk_dist * InpPartialTPTriggerR) :
                                                             (entry_exec_price - exec_risk_dist * InpPartialTPTriggerR);
                        double exec_tp2 = candidate_tp;

                        g_telegram.SendVIPTradeAlert(_Symbol, g_active_signal_dir, final_lot,
                                                     entry_exec_price, candidate_sl, exec_tp1, exec_tp2,
                                                     (candidate_is_buy ? score_buy : score_sell),
                                                     EnumToString(g_current_regime),
                                                     EnumToString(g_current_session),
                                                     g_current_atr);
                       }
                    }
                  else
                    {
                     g_gate_filter_status = StringFormat("MAX_BASKET_LOTS_REACHED (%.2f/%.2f Lots)", current_basket_vol, InpMaxTotalBasketLots);
                    }
                 }
              }
           }
        }
     }
   else
     {
      g_gate_filter_status = "HOLD / Searching Setup";
     }

   // 9. Manage Basket Exits (Target Margin ROI TP & Basket Exits)
   double cur_basket_pnl = 0.0;
   int cur_basket_cnt = 0;
   double cur_avg_p = 0.0;
   g_trade_manager.ManageBasketExits(cur_basket_pnl, cur_basket_cnt, cur_avg_p);

   g_hud.Render(_Symbol,
                g_current_regime,
                g_current_session,
                g_active_signal_dir,
                g_active_score,
                g_active_ai_conf,
                g_ai_online,
                spread_pts,
                g_current_atr,
                g_candidate_lot,
                g_candidate_rr,
                open_positions,
                g_filters.GetTradesToday(),
                g_filters.GetLossesToday(),
                g_gate_filter_status,
                cur_basket_pnl);
  }

//+------------------------------------------------------------------+
//| Trade transaction event handler (Journal & Cooldown Sync)        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // Check for closed deals
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong deal_ticket = trans.deal;
      if(HistoryDealSelect(deal_ticket))
        {
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         long magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);

         if(deal_entry == DEAL_ENTRY_OUT && magic == InpMagicNumber)
           {
            double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            double net_pnl = profit + commission + swap;

            g_filters.OnTradeClosed(net_pnl >= 0.0);

            // Populate Journal Record
            MqlTradeJournalRecord rec;
            rec.ticket = deal_ticket;
            rec.close_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
            rec.open_time = rec.close_time - 60; // Approximate fallback
            rec.symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
            rec.direction = (HistoryDealGetInteger(deal_ticket, DEAL_TYPE) == DEAL_TYPE_BUY) ? "BUY" : "SELL";
            rec.open_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            rec.close_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
            rec.sl_price = 0.0;
            rec.tp_price = 0.0;
            rec.lot_size = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
            rec.profit_usd = net_pnl;
            rec.profit_pips = 0.0;
            rec.commission = commission;
            rec.swap = swap;
            rec.entry_spread = 0.0;
            rec.entry_atr = g_current_atr;
            rec.regime_name = RegimeToString(g_current_regime);
            rec.deterministic_score = g_active_score;
            rec.ai_confidence = g_active_ai_conf;
            rec.reason_codes = g_ai_bridge.GetLatestReasonCodes();
            rec.session_name = SessionToString(g_current_session);
            rec.mae_points = 0.0;
            rec.mfe_points = 0.0;
            rec.duration_seconds = 60;
            rec.exit_reason = (net_pnl >= 0.0) ? "TP" : "SL";

            g_journal.LogCompletedTrade(rec);
            PrintFormat("📝 [JOURNAL] Logged closed trade #%d | PnL: $%+.2f | Exit: %s", deal_ticket, net_pnl, rec.exit_reason);
           }
        }
     }
  }
