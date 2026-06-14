@echo off
:: ============================================================
:: Project Aeloria - Stable Launcher (Improved)
:: ============================================================

set STEAM_EXE="C:\Program Files (x86)\Steam\steam.exe"
set APP_ID=1213210
set MOD_NAME=Aeloria-Stable

:: Enable rich Aeloria diagnostic logging (DIRECT_CLIENT_LIST_FLUSH, hasCreation inserts, cur/Total counts, clientListInserted, etc.)
:: This makes pure .bat plays produce the same detailed Aeloria-Debug-*.log evidence as ps1 -D (for north star diagnosis).
:: Matches the env set in ps1 when -DebugMode / -D.
set AELORIA_ENABLE_VERBOSE_DRAW_LOGS=1

echo.
echo [Project Aeloria] Launching STABLE version...
echo Mod: %MOD_NAME%
echo.

start "" %STEAM_EXE% -applaunch %APP_ID% REDALERT MOD=%MOD_NAME% -FastLaunch

exit
