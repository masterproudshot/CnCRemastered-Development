@echo off
:: ============================================================
:: Project Aeloria - Stable Launcher (Improved)
:: ============================================================

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set APP_ID=1213210
set MOD_NAME=Aeloria-Stable

:: Normal play: verbose draw logging OFF for speed. Use Scripts\Launch-Aeloria.ps1 -Profile Stable -D for diagnosis.
set AELORIA_ENABLE_VERBOSE_DRAW_LOGS=0

echo.
echo [Project Aeloria] Launching STABLE version...
echo Mod: %MOD_NAME%
echo.

start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% -FastLaunch

exit
