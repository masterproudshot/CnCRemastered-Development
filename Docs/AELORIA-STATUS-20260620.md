# Aeloria Project Status

**Date:** 2026-06-20  
**Branch:** `experimental` @ `e8619e8`  
**Owner:** Jackson  
**Purpose:** Single living status doc — supersedes stale June 7–14 snapshots for day-to-day work.

---

## Executive Summary

Custom 4p Aeloria skirmish **loads and plays** with starting forces visible at t=0. Mid-game **war-factory / refinery harvester production** was crashing due to unsafe `Class->` reads in `DLL_Draw_Intercept` (fixed in **5z-n**) and invalid bulk-export positions for moving harvesters (fixed in **5z-n2**, awaiting soak validation).

**North star not yet met:** No clean P4 soak PASS (`max_frame ≥ 7500`, 20–30+ min, no AV).

---

## North Star Definition

Launch → custom 4p skirmish → visible/selectable/orderable units (human + AI) → stable 20–30+ minutes → full-zoom mods active → no crash.

---

## Crash Timeline & Fixes

### Phase 1: `REDALERT.DLL+0x00045e5c` (intercept AV)

- **Symptom:** Crash shortly after harvester production; `HARVESTER_FIRST_DRAW` / `SAFE_SHAPE_EMIT` in log tail.
- **Root cause:** `DLL_Draw_Intercept` dereferenced `unit->Class->Type`, `infantry->Class->*`, `aircraft->Class->*` on pool-reused harvesters with `bad_plus_8=1`.
- **Fix (5z-n, 2026-06-19):** `Aeloria_Intercept_Unit_Type_Enum()` via `Aeloria_Safe_Techno_Type`; analyzer `no_windows_av` + tighter `no_abrupt_tail`.
- **Validation:** Post-fix soak `6ae341ea` survived harvester MAIN draw @ frame 4700; old offset did not reproduce.

### Phase 2b: `VCRUNTIME140.dll+0x161ee` (bulk idx gap — soak `9169dc6d`, 2026-06-20)

- **Symptom:** Crash ~3 min in when two war-factory harvesters bulk-registered same frame.
- **Root cause:** 5z-n2 `FindBulkAppendIndex` skipped stale slots 85–88 and wrote second harvester at **idx=89** while **finalCount=85**. Client buffer must be dense `[0..Count-1]`; hole + out-of-range write → heap corruption (VCRUNTIME140 AV, not REDALERT.DLL).
- **Evidence:** `idx=84` + `idx=89`, `finalCount=85` @ frame 4545. Positions were valid `(564,1128)` / `(2748,1008)` — position fix held.
- **Fix (5z-n2b):** Contiguous append only (`normalTotal + bulkAdded`); `BULK_SLOT_STOMP_GUARD` clears stale tail slot before write.

### Phase 2: `REDALERT.DLL+0x000caae0` (bulk export AV)

- **Symptom:** Harvester in motion stops unexpectedly; crash ~4 min in.
- **Root cause:** Moving harvester bulk-inserted with `pos=(-12,-24)` (`Render_Coord` invalid during `MARK_UP`). Two harvesters stomped same `idx=76` when `normalTotal` bounced between exports.
- **Fix (5z-n2, 2026-06-20):**
  - `Aeloria_NotifyMainDrawCache` stores MAIN draw `x,y`
  - `Aeloria_ResolveBulkPixelPos` (live → MAIN cache → virtual cache)
  - `BULK_SKIP_INVALID_POS` defers insert until coords valid
  - `Aeloria_FindBulkAppendIndex` prevents idx stomp

---

## Build & Deploy

| Step | Command / path |
|------|----------------|
| Source | `worktrees/bon-5k-5/REDALERT/` |
| Build | MSBuild `worktrees/bon-5k-5/CnCRemastered.sln` Release x86 v145 |
| Output | `worktrees/bon-5k-5/bin/Win32/RedAlert.dll` (1,295,360 bytes) |
| Dev deploy | `Mods/Red_Alert/Aeloria-Experimental/Data/RedAlert.dll` |
| Live deploy | `%USERPROFILE%\Documents\CnCRemastered\Mods\Red_Alert\Aeloria-Experimental\` |
| Launcher | `Scripts/Launch-Aeloria.ps1` |

**Profiles:**

| Profile | Use |
|---------|-----|
| Experimental | Active development; use `-D` for debug soaks |
| Stable | Daily driver after promotion; P4 flags (`-NC`, `NO_EVENT_HANDLER`) |
| Vanilla-Plus | Baseline reference only |

**Launcher flags:**

| Flag | Effect |
|------|--------|
| `-D` / `-DebugMode` | `MOD_DEBUG` + verbose draw logs |
| `-NC` / `-NoCleanup` | Leave live mod deployed (required for `.bat` contract) |
| `-B` | Build before deploy |
| `-A` | Auto-copy newest DLL to profile dev folder |

---

## Soak Validation

**Analyzer:** `Scripts/Analyze-AeloriaSoak.ps1`

```powershell
.\Scripts\Analyze-AeloriaSoak.ps1 -Profile P4 -LauncherLog <path-to-launcher-log>
```

| Profile | Key gates |
|---------|-----------|
| P1 | `max_frame_ge_7500`, `no_abrupt_tail`, `no_windows_av`, `harvester_past_4546` |
| P3 | `max_frame_ge_27000`, tank production, harvester relocate +100 frames |
| P4 | `max_frame_ge_7500`, `no_abrupt_tail`, `no_windows_av`, `no_crash_zip` |

**Windows AV gate:** Queries Application log for `InstanceServerG.exe` + `REDALERT.DLL` + `0xc0000005`. Crash zips are often missing — this gate is mandatory.

---

## Git / Submodule Reality

| Repo | State |
|------|-------|
| Parent `experimental` | `e8619e8` — infantry-scale P4 PASS stack promoted to Stable profile |
| Submodule `Source/Rampastring-MoreQoL` | On-disk `a5e7d5f` (older baseline) |
| Pinned commit `9423c04` | Not on remote — submodule update fails |
| Active work | `worktrees/bon-5k-5/` (full Aeloria copy, not yet merged to submodule) |

**Before declaring stable:** Commit bon-5k-5 changes inside submodule, update parent pointer, verify clean `git submodule status`.

---

## Open Work (Roadmap)

### Immediate

1. Complete 5z-n2 soak validation (`9169dc6d-ac10` or next session).
2. P4 PASS → promote Experimental → Stable.
3. Submodule commit + pointer sync.

### Next features (after stability gate)

| ID | Task |
|----|------|
| 5z-l | War Factory roofs + tank turret sub-draws |
| 5z-m | Late-game performance (log volume, tracking prune) |

### Known residual risks

- `bad_plus_8=1` still present on produced units; mitigated by safe-type paths, not eliminated at ABI level.
- Bulk sustain budget / tracking maps — bounded but not fully pruned under heavy production.
- Launcher "newest profile" auto-detect can surprise users omitting `-Profile` (see `bugfixer-launcher-deploy-audit.md`).

---

## Key Files

| File | Role |
|------|------|
| `worktrees/bon-5k-5/REDALERT/DLLInterface.cpp` | Bulk export, intercept, stability maps |
| `worktrees/bon-5k-5/REDALERT/OBJECT.H` | `AeloriaObjectStability`, safe-type helpers |
| `worktrees/bon-5k-5/REDALERT/CONQUER.CPP` | Draw intercept, MAIN draw cache notify |
| `worktrees/bon-5k-5/REDALERT/UNIT.CPP` | Produced unit draw diagnostics |
| `Scripts/Launch-Aeloria.ps1` | Build, deploy, launch, log collection |
| `Scripts/Analyze-AeloriaSoak.ps1` | Post-session gate analysis |

---

## Historical Docs (context only)

These reflect earlier investigation phases — do not treat as current state:

- `Docs/411-SHORT-SWEET-SUMMARY.md` — June 7 owner briefing (pre-bulk-registration era)
- `agent-tools/NORTH-STAR-PRINCIPLES-SCORECARD-20260614.md` — infantry-scale @ 5d63c39
- `Docs/HANDOFF-TO-NEW-OWNER-20260607.txt` — original visibility crisis handoff
- `Docs/bugfixer-*.md` — draw pipeline, lifecycle, launcher audit reports

---

**Last updated:** 2026-06-20  
**Next update trigger:** P4 soak PASS or new crash signature