# SESSION HANDOFF: North Star for Aeloria-Experimental (Custom 4p Skirmish)

**Date:** 2026-06-20  
**Branch:** `experimental` (post n9/n10 cert)  
**Read this first** when starting a new agent session or resuming after compaction.

---

## North Star (verbatim target)

User (or simple `.bat`) launches, custom 4p skirmish on the target map shows **visible, selectable, orderable** starting infantry + vehicles for the human house (and AI), game is **stable for 20–30+ minutes** of actual play, mods (full-zoom `GameConstants_Mod.xml` etc.) are active, no immediate crash or "map but no units" experience.

**Daily driver goal:** `Launch-Aeloria-Stable.bat` (or Experimental) just works for a playable custom 4p skirmish.

---

## Current State (2026-06-20 evening) — MAJOR MILESTONE

### Full-game cert PASS (session `83bb73d1-5892`)

- **Human played entire match and won** — no crashes, clean launcher exit.
- **max_frame 57,352** (~32 min wall clock); DLL **1,302,528 bytes** (n9 aircraft + n10 vessel).
- Spy plane (U2) hit `PRODUCED_AIRCRAFT_*` safe-draw path at frame 42k.
- Automated P1: all crash gates PASS; `no_abrupt_tail` FAIL only (quit-mid-combat false positive).
- **Promoted to Stable** as `stable-v3-full-game-pass`.

### What's working

- **Launch + deploy:** `Scripts/Launch-Aeloria.ps1` deploys Experimental/Stable; `-NC` leaves live mod for `.bat` play.
- **t=0 visibility:** Bulk registration + LAYERS export.
- **5z-n8/n8c/n8d:** WF produced units, harvester gem rejection, cache spam fixes.
- **5z-n9:** Aircraft/spy plane eternal-safe `Draw_It`.
- **5z-n10:** Vessel shipyard eternal-safe `Draw_It` + `Aeloria_Safe_Techno_Type` fallback.
- **Crash coverage audit:** `Scripts/Audit-AeloriaCoverage.ps1` + matrix doc.

### What's next (priority)

| Status | Task |
|--------|------|
| **Next** | **5z-l:** War Factory roofs + tank turret sub-draws |
| Pending | 5z-m: Late-game perf (user noted slowdown late match) |
| Pending | Naval map soak for n10 vessel (land-only Aeloria skipped shipyard) |

---

## Active Implementation Source

| Item | Path |
|------|------|
| Primary DLL worktree | `worktrees/bon-5k-5/REDALERT/` |
| Submodule | `Source/Rampastring-MoreQoL/REDALERT/` |
| Build solution | `worktrees/bon-5k-5/CnCRemastered.sln` |
| Build output | `worktrees/bon-5k-5/bin/Win32/RedAlert.dll` |
| Deploy targets | `Mods/Red_Alert/Aeloria-Experimental/Data/`, `Aeloria-Stable/Data/`, live `Documents/CnCRemastered/Mods/...` |
| Current DLL size | **1,302,528 bytes** |

**Build command:**

```powershell
& "C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe" `
  "worktrees\bon-5k-5\CnCRemastered.sln" /t:RedAlert `
  /p:Configuration=Release /p:Platform=x86 /p:PlatformToolset=v145 /verbosity:minimal
```

---

## How to Launch & Validate

### Daily driver (Stable — promoted)

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Stable -BuildFirst -AutoDeployDll -NC
```

Or `Launchers/Launch-Aeloria-Stable.bat` after deploy.

### Debug soak

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -DebugMode -NC
```

### Analyze after exit

```powershell
.\Scripts\Analyze-AeloriaSoak.ps1 -Profile P4 -LauncherLog (Get-ChildItem Logs\Launch-Aeloria_*<session>*.log | Select-Object -First 1).FullName
```

---

## Related Docs

- `Docs/09-Full-Roster-Crash-Coverage-Matrix.md`
- `Docs/09-Full-Roster-Gameplay-Cert-Checklist.md`
- `Docs/AELORIA-STATUS-20260620.md`
- `Docs/10-Development-Process-and-Deployment-Checklist.md`

---

*End of handoff. North star = visible units + stable full-game play on custom 4p Aeloria.*