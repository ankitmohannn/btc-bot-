//+------------------------------------------------------------------+
//|                                       SmartScalper_Journal.mqh   |
//|                                  Copyright 2026, Institutional AI |
//|          Machine-Readable Trade Journal & Attribution Engine      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Institutional AI"
#property link      "https://github.com/HKUDS/Vibe-Trading"
#property version   "2.00"
#property strict

#include "SmartScalper_Types.mqh"
#include "SmartScalper_Config.mqh"

//+------------------------------------------------------------------+
//| Trade Journal Class                                              |
//+------------------------------------------------------------------+
class CSmartJournal
  {
private:
   string            m_symbol;
   string            m_journal_filename;

public:
   CSmartJournal() : m_symbol(""), m_journal_filename("smart_scalper_journal.csv") {}

   void Init(string symbol)
     {
      m_symbol = (symbol == "") ? _Symbol : symbol;
      EnsureHeaderExists();
     }

   //+---------------------------------------------------------------+
   //| Ensure CSV Header Exists                                      |
   //+---------------------------------------------------------------+
   void EnsureHeaderExists()
     {
      int handle = FileOpen(m_journal_filename, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
      if(handle == INVALID_HANDLE)
        {
         handle = FileOpen(m_journal_filename, FILE_READ|FILE_CSV|FILE_ANSI, ',');
        }

      if(handle != INVALID_HANDLE)
        {
         FileClose(handle);
         return; // File already exists
        }

      // Create new file with header
      handle = FileOpen(m_journal_filename, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
      if(handle == INVALID_HANDLE)
         handle = FileOpen(m_journal_filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');

      if(handle != INVALID_HANDLE)
        {
         string header = "Ticket,OpenTime,CloseTime,Symbol,Direction,OpenPrice,ClosePrice,SL,TP,LotSize,ProfitUSD,ProfitPips,Commission,Swap,EntrySpread,EntryATR,Regime,Score,AIConfidence,ReasonCodes,Session,MAE_Points,MFE_Points,DurationSec,ExitReason";
         FileWriteString(handle, header + "\n");
         FileClose(handle);
        }
     }

   //+---------------------------------------------------------------+
   //| Append Completed Trade Record to Journal                      |
   //+---------------------------------------------------------------+
   void LogCompletedTrade(const MqlTradeJournalRecord &record)
     {
      int handle = FileOpen(m_journal_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
      if(handle == INVALID_HANDLE)
         handle = FileOpen(m_journal_filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');

      if(handle == INVALID_HANDLE) return;

      FileSeek(handle, 0, SEEK_END);

      string line = StringFormat("%d,%s,%s,%s,%s,%.5f,%.5f,%.5f,%.5f,%.2f,%.2f,%.1f,%.2f,%.2f,%.1f,%.5f,%s,%.1f,%.1f,\"%s\",%s,%.1f,%.1f,%d,%s\n",
                                 record.ticket,
                                 TimeToString(record.open_time, TIME_DATE|TIME_SECONDS),
                                 TimeToString(record.close_time, TIME_DATE|TIME_SECONDS),
                                 record.symbol,
                                 record.direction,
                                 record.open_price,
                                 record.close_price,
                                 record.sl_price,
                                 record.tp_price,
                                 record.lot_size,
                                 record.profit_usd,
                                 record.profit_pips,
                                 record.commission,
                                 record.swap,
                                 record.entry_spread,
                                 record.entry_atr,
                                 record.regime_name,
                                 record.deterministic_score,
                                 record.ai_confidence,
                                 record.reason_codes,
                                 record.session_name,
                                 record.mae_points,
                                 record.mfe_points,
                                 record.duration_seconds,
                                 record.exit_reason);

      FileWriteString(handle, line);
      FileClose(handle);
     }
  };
