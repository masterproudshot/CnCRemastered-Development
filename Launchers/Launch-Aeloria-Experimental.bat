@echo off
:: ============================================================
:: Project Aeloria - Experimental Launcher (Improved)
:: ============================================================
:: This version properly launches through Steam for best compatibility.

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set APP_ID=1213210
set MOD_NAME=Aeloria-Experimental

echo.
echo [Project Aeloria] Launching EXPERIMENTAL version...
echo Mod: %MOD_NAME%
echo.

start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% MOD_DEBUG -FastLaunch

exit
