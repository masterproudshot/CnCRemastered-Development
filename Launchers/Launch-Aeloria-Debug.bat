@echo off
:: ============================================================
:: Project Aeloria - Debug / Developer Launcher
:: ============================================================
:: Extra debug flags. Best when attached to Visual Studio debugger.
:: Use when actively developing or hunting crashes.

set GAME_PATH=C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered
set MOD_NAME=Aeloria-Experimental
set APPID=1213210

echo.
echo [Project Aeloria] Launching in DEBUG mode...
echo - MOD_DEBUG enabled
echo - NO_EVENT_HANDLER enabled (helps with debugger attachment)
echo - Attach Visual Studio to ClientG.exe after launch for breakpoints
echo.

cd /d "%GAME_PATH%"
echo %APPID% > steam_appid.txt

start "" "ClientG.exe" REDALERT MOD=%MOD_NAME% MOD_DEBUG NO_EVENT_HANDLER -FastLaunch

echo Debug launch initiated.
echo.
echo Tip: In Visual Studio, use Debug > Attach to Process > ClientG.exe
pause >nul
