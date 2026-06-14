@echo off
:: ============================================================
:: Project Aeloria - Debug Launcher (Improved)
:: ============================================================
:: Use this when you need to attach a debugger or investigate crashes.

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set CLIENTG_EXE="C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered\ClientG.exe"
set APP_ID=1213210
set MOD_NAME=Aeloria-Experimental
set AELORIA_ZERO_MAP_PRODUCED_INFANTRY=1

echo.
echo [Project Aeloria] Launching in DEBUG mode...
echo Mod: %MOD_NAME%
echo.
echo Tip: You can now attach Visual Studio to ClientG.exe after launch.
echo.

set USE_CLIENTG=1
tasklist /FI "IMAGENAME eq steam.exe" 2>NUL | find /I "steam.exe" >NUL
if errorlevel 1 (
    set USE_CLIENTG=0
    echo Starting Steam client...
    start "" %STEAM_EXE% -silent
    echo Waiting for Steam login/DRM init...
    timeout /t 25 /nobreak >NUL
)

if "%USE_CLIENTG%"=="1" if exist %CLIENTG_EXE% (
    start "" %CLIENTG_EXE% REDALERT MOD=%MOD_NAME% MOD_DEBUG NO_EVENT_HANDLER -FastLaunch
) else (
    start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% MOD_DEBUG NO_EVENT_HANDLER -FastLaunch
)

exit
