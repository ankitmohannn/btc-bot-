@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title Kronos Super-Fast High-Frequency Scalper Bot (0.01 Lot)
cd /d "%~dp0"
echo ======================================================================
echo   STARTING KRONOS SUPER-FAST SCALPING BOT (0.01 LOT)
echo ======================================================================
echo.

if exist "super_fast_scalper.py" (
    python -u super_fast_scalper.py --symbol XAUUSD --timeframe M5
) else if exist "kronos_btc\super_fast_scalper.py" (
    python -u kronos_btc\super_fast_scalper.py
) else if exist "Kronos-master\kronos_btc\super_fast_scalper.py" (
    python -u Kronos-master\kronos_btc\super_fast_scalper.py
) else (
    echo [ERROR] Could not locate super_fast_scalper.py
)

pause
