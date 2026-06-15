Project Aeloria - Launchers (Updated Version)

These batch files now use the recommended method of launching through Steam itself.
This is more reliable than directly running ClientG.exe.

How to use:
- Double-click the .bat file you want to run.
- Steam will launch Red Alert with the selected mod automatically.

Available Launchers:
- Launch-Aeloria-Experimental.bat   → For testing new changes
- Launch-Aeloria-Stable.bat         → Your main daily driver
- Launch-Vanilla-Plus.bat           → Clean baseline for comparison
- Launch-Aeloria-Debug.bat          → For attaching debuggers (MOD_DEBUG enabled)

Important:
- Steam must be running (or it will start automatically).
- Make sure your mod folder exists in:
  Development/Mods/Red_Alert/[ModName]/
  with a Data/RedAlert.dll inside it.

New in 2026: Use `Launch-Aeloria.ps1 -Profile Stable -NoCleanup` (or -Permanent / -NC)
when you want the mod to stay deployed in your live Documents folder after the game exits.
This makes the simple .bat launchers continue to work for daily play without re-running the full ps1.

**For rich diagnostic logs from a pure .bat launch (critical for north star visibility debugging):**
The .bat files now set `AELORIA_ENABLE_VERBOSE_DRAW_LOGS=1` (plus MOD_DEBUG on Debug/Experimental).
This produces the same detailed Aeloria-Debug-*.log (with DIRECT_CLIENT_LIST_FLUSH_HASCREATION, has_creation=1, clientListInserted, cur/Total counts, enriched position/strength data, etc.) as ps1 -D runs.
The log goes to %USERPROFILE% (or C:\ fallbacks) and is flushed for every key event. Include a tail of the latest Aeloria debug log + launcher log when reporting "no units" or crashes.

**Reliable deploy contract for .bat (prevents "launched Stable but got Experimental bits"):**
Always do `Scripts\Launch-Aeloria.ps1 -Profile Stable -BuildFirst -AutoDeployDll -NoCleanup` (or -B -A -NC -P Stable) first.
Then double-click the .bat. The ps1 pins the correct DLL + XMLs into the live Aeloria-Stable folder.
Re-run the ps1 (with explicit -P) any time you edit source. ps1 now has stronger profile guards + post-deploy size/GameConstants checks + logging to catch mis-selection.

**North-star soak validation (2026-06-14, Phase 5s-5w):**
- Dev soak: `Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NoCleanup -DebugMode`
- In-game: 4p Aeloria skirmish → ref+silo → war factory → queue 3 light tanks → harvesters → play 5+ min.
- On exit, ps1 auto-runs `Scripts\Analyze-AeloriaSoak.ps1` (P1 gates: max frame >= 7500, no abrupt tail, tank unlimbo if WF built).
- Daily-driver check: same soak without `-DebugMode` after Experimental P1 passes.
- Expected live DLL size after 5s-5w build: ~1.32 MB (check ps1 post-deploy line).

Customizing:
If your Steam is installed in a different location, edit the STEAM_EXE line in the .bat file.

Example:
set STEAM_EXE="D:\Steam\steam.exe"
