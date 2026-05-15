@echo off
:: ============================================================
:: Project Aeloria - Vanilla-Plus Launcher (Safe Baseline)
:: ============================================================
:: Minimal changes. Use this to verify that a crash is caused by Aeloria.

set GAME_PATH=C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered
set MOD_NAME=Vanilla-Plus
set APPID=1213210

echo.
echo [Project Aeloria] Launching VANILLA-PLUS (safe baseline)...
echo.

cd /d "%GAME_PATH%"
echo %APPID% > steam_appid.txt

start "" "ClientG.exe" REDALERT MOD=%MOD_NAME% -FastLaunch

echo Vanilla-Plus launched.
pause >nul
