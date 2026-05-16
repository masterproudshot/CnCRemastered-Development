@echo off
:: ============================================================
:: Project Aeloria - Debug Launcher (Improved)
:: ============================================================
:: Use this when you need to attach a debugger or investigate crashes.

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set APP_ID=1213210
set MOD_NAME=Aeloria-Experimental

echo.
echo [Project Aeloria] Launching in DEBUG mode...
echo Mod: %MOD_NAME%
echo.
echo Tip: You can now attach Visual Studio to ClientG.exe after launch.
echo.

start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% MOD_DEBUG NO_EVENT_HANDLER -FastLaunch

exit
