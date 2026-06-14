@echo off
:: ============================================================
:: Project Aeloria - Experimental Launcher (Improved)
:: ============================================================
:: This version properly launches through Steam for best compatibility.

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set CLIENTG_EXE="C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered\ClientG.exe"
set APP_ID=1213210
set MOD_NAME=Aeloria-Experimental

:: Verbose draw logging (default OFF for play — late-game I/O is costly). Set to 1 for diagnosis (same as ps1 -D).
set AELORIA_ENABLE_VERBOSE_DRAW_LOGS=0

echo.
echo [Project Aeloria] Launching EXPERIMENTAL version...
echo Mod: %MOD_NAME%
echo.

:: Warm Steam: if already running use ClientG; if not, start Steam then -applaunch (ClientG alone fails DRM).
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
    start "" %CLIENTG_EXE% REDALERT MOD=%MOD_NAME% -FastLaunch
) else (
    start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% -FastLaunch
)

exit
