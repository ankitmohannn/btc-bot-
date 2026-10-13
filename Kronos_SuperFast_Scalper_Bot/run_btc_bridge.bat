@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title Option C Enhanced Vibe Multi-Agent Scalper Launcher
cd /d "%~dp0"

echo ======================================================================
echo          OPTION C ENHANCED VIBE MULTI-AGENT SCALPER (M5)
echo          Targets: $50 TP / $35 SL | Step-Lock: +$18 -> +$35
echo ======================================================================
echo.
echo 1. Starting AI Bridge Server (MT5 HUD ONLINE)...
echo 2. Starting Option C Enhanced Scalper Engine...
echo.

:: 1. Launch AI Bridge Server
start "SmartScalper AI Bridge Server (MT5 ONLINE)" cmd /k "cd /d ""%~dp0"" && :loop && python -u ai\bridge\ai_bridge_server.py && echo AI Bridge exited. Restarting in 3s... && timeout /t 3 /nobreak >nul && goto loop"

:: 2. Launch Option C Vibe Scalper Engine
start "Option C Vibe Multi-Agent Scalper - BTCUSD (M5 - 24/7)" cmd /k "cd /d ""%~dp0"" && :loop && python super_fast_scalper.py --symbol BTCUSD --timeframe M5 && echo Scalper exited. Restarting in 3s... && timeout /t 3 /nobreak >nul && goto loop"

echo ======================================================================
echo [OK] OPTION C ENHANCED SCALPER RUNNING 24/7!
echo ======================================================================
echo You can minimize this window.
pause
