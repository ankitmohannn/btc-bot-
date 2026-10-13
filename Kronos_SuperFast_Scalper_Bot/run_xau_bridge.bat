@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title Vibe Waterfall XAUUSD (Gold) 24/7 Scalper Launcher
cd /d "%~dp0"

echo ======================================================================
echo          VIBE WATERFALL XAUUSD (GOLD) 24/7 SCALPER (M5)
echo          Features: Structural Candle SL + Retest Entry + Candle Trailing
echo ======================================================================
echo.
echo 1. Starting AI Bridge Server (MT5 HUD ONLINE)...
echo 2. Starting Vibe Waterfall Scalper for XAUUSD (Gold)...
echo.

:: 1. Launch AI Bridge Server
start "SmartScalper AI Bridge Server (MT5 ONLINE)" cmd /k "cd /d ""%~dp0"" && :loop && python -u ai\bridge\ai_bridge_server.py && echo AI Bridge exited. Restarting in 3s... && timeout /t 3 /nobreak >nul && goto loop"

:: 2. Launch Vibe Waterfall Scalper Engine for XAUUSD
start "Vibe Waterfall Scalper - XAUUSD Gold (M5 - 24/7)" cmd /k "cd /d ""%~dp0"" && :loop && python super_fast_scalper.py --symbol XAUUSD --timeframe M5 && echo Scalper exited. Restarting in 3s... && timeout /t 3 /nobreak >nul && goto loop"

echo ======================================================================
echo [OK] VIBE WATERFALL XAUUSD SCALPER RUNNING 24/7!
echo ======================================================================
echo You can minimize this window.
pause
