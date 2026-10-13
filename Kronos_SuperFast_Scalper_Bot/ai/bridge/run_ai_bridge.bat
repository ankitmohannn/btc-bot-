@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title SmartScalper V2 - Vibe-Trading AI Bridge Server
cd /d "%~dp0"
echo ======================================================================
echo   STARTING SMARTSCALPER V2 - VIBE-TRADING AI BRIDGE SERVER
echo ======================================================================
echo.

python -u ai_bridge_server.py

pause
