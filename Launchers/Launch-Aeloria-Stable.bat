@echo off
:: ============================================================
:: Project Aeloria - Stable Launcher (P4 daily driver)
:: ============================================================
:: Routes through Launch-Aeloria.ps1 so crashes collect Aeloria debug logs
:: and auto-analyze P4 gates. P4 = -NC only (no -D verbose draw spam).

setlocal
set "PS1=%~dp0..\Scripts\Launch-Aeloria.ps1"

echo.
echo [Project Aeloria] Launching STABLE via PowerShell launcher...
echo Profile: Stable  Mode: P4 (-NC, no -D)
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Profile Stable -NC
set "EXITCODE=%ERRORLEVEL%"

endlocal & exit /b %EXITCODE%