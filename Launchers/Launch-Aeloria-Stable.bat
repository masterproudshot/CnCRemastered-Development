@echo off
:: ============================================================
:: Project Aeloria - Stable Launcher (Improved)
:: ============================================================

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set APP_ID=1213210
set MOD_NAME=Aeloria-Stable

echo.
echo [Project Aeloria] Launching STABLE version...
echo Mod: %MOD_NAME%
echo.

start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% -FastLaunch

exit
