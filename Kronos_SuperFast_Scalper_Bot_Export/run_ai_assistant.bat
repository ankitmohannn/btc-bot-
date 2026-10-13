@echo off
set "PATH=%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts;%PATH%"
title Modal GPT-OSS 120B Assistant - Kronos SmartScalper V2
cls
echo ==============================================================================
echo  Launching Antigravity -> Modal GPT-OSS 120B Workspace Assistant
echo ==============================================================================
python ai\openai_assistant.py
pause
