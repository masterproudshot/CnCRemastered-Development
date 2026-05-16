@echo off
:: ============================================================
:: Project Aeloria - Vanilla-Plus Launcher (Improved)
:: ============================================================
:: Minimal baseline for comparison.

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set APP_ID=1213210
set MOD_NAME=Vanilla-Plus

echo.
echo [Project Aeloria] Launching VANILLA-PLUS baseline...
echo.

start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% -FastLaunch

exit
