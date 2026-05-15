@echo off
:: ============================================================
:: Project Aeloria - Stable Profile Launcher (Fast Direct Launch)
:: ============================================================
:: This bypasses the slow Steam mod selection workflow.
:: Uses direct ClientG.exe execution for much faster iteration.

set GAME_PATH=C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered
set MOD_NAME=Aeloria-Stable
set APPID=1213210

echo.
echo [Project Aeloria] Launching STABLE profile...
echo Game Path: %GAME_PATH%
echo Mod: %MOD_NAME%
echo.

cd /d "%GAME_PATH%"

:: Enable direct Steam appid (faster launch, less Steam UI overhead)
echo %APPID% > steam_appid.txt

:: Launch directly into Red Alert with the mod pre-loaded
:: MOD_DEBUG enables better debugging support for DLL development
start "" "ClientG.exe" REDALERT MOD=%MOD_NAME% MOD_DEBUG -FastLaunch

echo Launched. Close this window if desired.
echo.
pause >nul
