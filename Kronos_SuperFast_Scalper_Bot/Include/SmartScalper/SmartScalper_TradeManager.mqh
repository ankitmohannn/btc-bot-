//+------------------------------------------------------------------+
//|                                    SmartScalper_TradeManager.mqh |
//|                                  Copyright 2026, Institutional AI |
//|               Smart Position Lifecycle & Stop Management Engine   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"
#include "SmartScalper_Telegram.mqh"

//+------------------------------------------------------------------+
//| Trade Manager Class                                              |
//+------------------------------------------------------------------+
class CSmartTradeManager
  {
private:
   string            m_symbol;
   CTrade            m_trade;
   ulong             m_partial_tp_tickets[];
   CSmartTelegram*   m_telegram;

public:
   CSmartTradeManager() : m_symbol(""), m_telegram(NULL) {}

   void SetTelegram(CSmartTelegram* tg) { m_telegram = tg; }

   void Init(string symbol)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      m_trade.SetExpertMagicNumber(InpMagicNumber);
      m_trade.SetDeviationInPoints(InpSlippagePoints);

      long filling = SymbolInfoInteger(m_symbol, SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
         m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      else
         m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
     }

   CTrade* GetTradeHandle() { return GetPointer(m_trade); }

   bool HasTakenPartialTP(ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_partial_tp_tickets); i++)
        {
         if(m_partial_tp_tickets[i] == ticket) return true;
        }
      return false;
     }

   void RecordPartialTP(ulong ticket)
     {
      if(HasTakenPartialTP(ticket)) return;
      int sz = ArraySize(m_partial_tp_tickets);
      ArrayResize(m_partial_tp_tickets, sz + 1);
      m_partial_tp_tickets[sz] = ticket;
     }

   double NormalizePartialLot(double raw_lot)
     {
      double min_lot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double max_lot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double step_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

      if(min_lot <= 0.0)  min_lot = 0.01;
      if(max_lot <= 0.0)  max_lot = 100.0;
      if(step_lot <= 0.0) step_lot = 0.01;

      double normalized = MathFloor(raw_lot / step_lot) * step_lot;
      if(normalized < min_lot) normalized = min_lot;
      if(normalized > max_lot) normalized = max_lot;

      int lot_digits = 2;
      if(step_lot == 0.1)   lot_digits = 1;
      if(step_lot == 1.0)   lot_digits = 0;
      if(step_lot == 0.001) lot_digits = 3;

      return NormalizeDouble(normalized, lot_digits);
     }

   //+---------------------------------------------------------------+
   //| Execute Institutional Market Order                            |
   //+---------------------------------------------------------------+
   bool ExecuteMarketOrder(bool is_buy, double lot, double sl, double tp, string comment, ulong &out_ticket)
     {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      sl = NormalizeDouble(sl, digits);
      tp = NormalizeDouble(tp, digits);

      bool res = false;
      if(is_buy)
        {
         res = m_trade.Buy(lot, m_symbol, ask, sl, tp, comment);
        }
      else
        {
         res = m_trade.Sell(lot, m_symbol, bid, sl, tp, comment);
        }

      if(res)
        {
         out_ticket = m_trade.ResultOrder();
         PrintFormat("⚡ [EXECUTE] %s %.2f lots on %s @ %s | SL: %s | TP: %s | Ticket #%d",
                     (is_buy ? "BUY" : "SELL"), lot, m_symbol,
                     DoubleToString((is_buy ? ask : bid), digits),
                     DoubleToString(sl, digits), DoubleToString(tp, digits), out_ticket);
         return true;
        }
      else
        {
         PrintFormat("❌ [EXECUTE_FAIL] %s order failed. RetCode: %d | Msg: %s",
                     (is_buy ? "BUY" : "SELL"), m_trade.ResultRetcode(), m_trade.ResultComment());
         return false;
        }
     }



   //+---------------------------------------------------------------+
   //+---------------------------------------------------------------+
   //| Count Open Positions by Magic and Symbol                      |
   //+---------------------------------------------------------------+
   int GetOpenPositionsCount()
     {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(PositionSelectByTicket(PositionGetTicket(i)))
           {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
               count++;
           }
        }
      return count;
     }

   //+---------------------------------------------------------------+
   //| Calculate Total Volume of Active Positions on Symbol & Magic   |
   //+---------------------------------------------------------------+
   double GetOpenPositionsTotalVolume(long match_type=-1)
     {
      double total_volume = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;

         long p_type = PositionGetInteger(POSITION_TYPE);
         if(match_type == -1 || p_type == match_type)
           {
            total_volume += PositionGetDouble(POSITION_VOLUME);
           }
        }
      return total_volume;
     }

   //+---------------------------------------------------------------+
   //| Calculate Total Broker Margin Locked by Active Positions      |
   //+---------------------------------------------------------------+
   double GetBasketMarginUsed()
     {
      double total_margin = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;

         long pos_type = PositionGetInteger(POSITION_TYPE);
         double pos_vol = PositionGetDouble(POSITION_VOLUME);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);

         double pos_margin = 0.0;
         ENUM_ORDER_TYPE ord_type = (pos_type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(OrderCalcMargin(ord_type, m_symbol, pos_vol, open_price, pos_margin) && pos_margin > 0.0)
           {
            total_margin += pos_margin;
           }
         else
           {
            long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
            if(leverage <= 0) leverage = 100;
            double contract_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            if(contract_size <= 0.0) contract_size = 1.0;
            total_margin += (pos_vol * contract_size * open_price) / (double)leverage;
           }
        }
      return total_margin;
     }

   //+---------------------------------------------------------------+
   //| Close All Open Positions for Symbol and Magic                 |
   //+---------------------------------------------------------------+
   int CloseAllPositions(string exit_reason_comment="")
     {
      int closed_count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;

         if(m_trade.PositionClose(ticket))
           {
            closed_count++;
            PrintFormat("✅ [BASKET_CLOSE] Ticket #%I64u closed successfully. %s", ticket, exit_reason_comment);
           }
         else
           {
            PrintFormat("❌ [BASKET_CLOSE_FAIL] Ticket #%I64u close failed. RetCode: %u | Msg: %s",
                        ticket, m_trade.ResultRetcode(), m_trade.ResultComment());
           }
        }
      return closed_count;
     }

   //+---------------------------------------------------------------+
   //| Close all positions opposite to the new candidate direction   |
   //+---------------------------------------------------------------+
   int CloseOppositePositions(bool is_new_buy, double &out_closed_pnl, string reason="")
     {
      int closed_count = 0;
      out_closed_pnl = 0.0;
      long target_type = is_new_buy ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;

         if(PositionGetInteger(POSITION_TYPE) == target_type)
           {
            double pos_pnl = PositionGetDouble(POSITION_PROFIT);
            double pos_vol = PositionGetDouble(POSITION_VOLUME);
            if(m_trade.PositionClose(ticket))
              {
               closed_count++;
               out_closed_pnl += pos_pnl;
               PrintFormat("🔄 [REVERSAL_CLOSE] Closed opposite %s Ticket #%I64u (%.2f lots) @ %s | PnL: %s$%.2f USD (%s)",
                           (target_type == POSITION_TYPE_BUY ? "BUY" : "SELL"), ticket,
                           pos_vol, m_symbol, (pos_pnl >= 0 ? "+" : ""), pos_pnl, reason);
              }
           }
        }
      return closed_count;
     }

   //+---------------------------------------------------------------+
   //| Manage Smart Basket DCA Exits (Target Profit & Emergency SL)  |
   //+---------------------------------------------------------------+
   bool ManageBasketExits(double &out_basket_pnl, int &out_basket_count, double &out_avg_price)
     {
      out_basket_pnl = 0.0;
      out_basket_count = 0;
      out_avg_price = 0.0;

      double total_profit = 0.0;
      double total_volume = 0.0;
      double sum_price_vol = 0.0;
      int count = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;

         double p_profit = PositionGetDouble(POSITION_PROFIT);
         double p_swap   = PositionGetDouble(POSITION_SWAP);
         double p_vol    = PositionGetDouble(POSITION_VOLUME);
         double p_price  = PositionGetDouble(POSITION_PRICE_OPEN);

         total_profit += (p_profit + p_swap);
         total_volume += p_vol;
         sum_price_vol += (p_price * p_vol);
         count++;
        }

      out_basket_pnl = total_profit;
      out_basket_count = count;
      if(total_volume > 0.0)
         out_avg_price = sum_price_vol / total_volume;

      if(count == 0) return false;

      // 1. Check Dynamic Margin ROI Take Profit (Floating Profit >= Total Margin Invested)
      if(InpEnableInvestedMarginTP && count > 0)
        {
         double total_margin = GetBasketMarginUsed();
         double target_margin_roi = total_margin * (InpInvestedMarginROI_Pct / 100.0);
         if(target_margin_roi < 10.0) target_margin_roi = 10.0; // Minimum $10.00 USD safety floor

         if(total_profit >= target_margin_roi)
           {
            PrintFormat("🎯 [MARGIN_ROI_TP] %.0f%% Invested Margin Return reached! Net PnL: +$%.2f USD >= Target +$%.2f USD (Margin Locked: $%.2f USD). Closing all %d positions.",
                        InpInvestedMarginROI_Pct, total_profit, target_margin_roi, total_margin, count);
            CloseAllPositions(StringFormat("MARGIN_ROI_TP (+$%.2f)", total_profit));
            return true;
           }
        }

      // 2. Check Basket Target Profit (if Basket DCA enabled)
      if(InpEnableBasketDCA && total_profit >= InpBasketTargetUSD)
        {
         PrintFormat("🎯 [BASKET_TP] Target reached! Net PnL: +$%.2f (>= +$%.2f Target). Closing all %d positions.",
                     total_profit, InpBasketTargetUSD, count);
         CloseAllPositions(StringFormat("BASKET_TP (+$%.2f)", total_profit));
         return true;
        }

      // 3. Check Basket Emergency Stop Loss
      if(InpEnableBasketDCA && total_profit <= -InpBasketStopLossUSD)
        {
         PrintFormat("🛑 [BASKET_SL] Emergency cutoff hit! Net PnL: -$%.2f (<= -$%.2f Cutoff). Closing all %d positions.",
                     MathAbs(total_profit), InpBasketStopLossUSD, count);
         CloseAllPositions(StringFormat("BASKET_SL (-$%.2f)", MathAbs(total_profit)));
         return true;
        }

      return false;
     }
  };
