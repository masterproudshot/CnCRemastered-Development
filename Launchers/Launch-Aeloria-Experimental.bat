@echo off
:: ============================================================
:: Project Aeloria - Experimental Profile Launcher
:: ============================================================
:: Use this when testing new / risky changes.
:: Still fast direct launch.

set GAME_PATH=C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered
set MOD_NAME=Aeloria-Experimental
set APPID=1213210

echo.
echo [Project Aeloria] Launching EXPERIMENTAL profile...
echo WARNING: This may contain untested or breaking changes.
echo.

cd /d "%GAME_PATH%"
echo %APPID% > steam_appid.txt

start "" "ClientG.exe" REDALERT MOD=%MOD_NAME% MOD_DEBUG -FastLaunch

echo Launched Experimental build.
pause >nul
