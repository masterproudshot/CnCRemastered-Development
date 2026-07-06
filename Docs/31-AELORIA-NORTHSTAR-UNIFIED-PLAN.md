# Aeloria North Star — Unified Multi-Agent Implementation Plan

> **Status:** Executing — master orchestrator WAVE-0+.  
> **Branch:** `experimental` only (parent repo + `Source/Rampastring-MoreQoL` submodule `improvements`).  
> **North star:** Custom **4p+ skirmish** on **Experimental**, stable menus, **visible/selectable/orderable** units (human + AI) **indefinitely** on modern hardware (no artificial duration caps — `max_frame` numbers are testing milestones only), full-zoom mods, **no crash**. Reference-quality **126×126** procedural maps (not flat clear + ore printout).

See `Docs/32-AELORIA-STATUS-WAVES.md` for live wave checklist.

## Key Decisions

1. Perf before deep visibility fix (E.2.50 before E.2.49).
2. Late AV E.2.51 before conditional Start hardening PR 4.
3. MapGen v2 parallel lane B0–B4.
4. Plain-git stack on experimental.
5. Evidence gates P1/P4 + WER.

## PR Plan

### PR 0: Roadmap and unified status doc

- **Description:** Docs mirror, RCA `1c4c2d18`, STATUS-WAVES.
- **Files/components affected:** `Docs/31-AELORIA-NORTHSTAR-UNIFIED-PLAN.md`, `Docs/39-AELORIA-PLAN-E245-NORTHSTAR-PATH.md`, `Docs/43-AELORIA-RCA-SKIRMISH-CRASH-20260702.md`, `Docs/32-AELORIA-STATUS-WAVES.md`
- **Dependencies:** None

### PR 1: E.2.50 — Non-debug performance (quiet critical path)

- **Description:** Rate-limit critical tags; throttle preview prune/ensure; `AELORIA_QUIET=1` for `-NC`.
- **Files/components affected:** `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`, `Source/Rampastring-MoreQoL/REDALERT/OBJECT.H`, `Scripts/Launch-Aeloria.ps1`, `Docs/09-Project-Aeloria-Configuration-Guide.md`
- **Dependencies:** PR 0

### PR 2: E.2.51 — Late-game REDALERT.DLL AV (~58k frames)

- **Description:** Fix WER `000b7fdf`; symbolize; guards + `LATE_GAME_AV_GUARD`.
- **Files/components affected:** `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`, `Source/Rampastring-MoreQoL/REDALERT/OBJECT.H`, `Source/Rampastring-MoreQoL/REDALERT/CONQUER.CPP`, `Docs/AELORIA-RCA-SKIRMISH-CRASH-20260702.md`
- **Dependencies:** PR 1

### PR 3: E.2.49 — LAYERS visibility / 512 cap instrumentation

- **Description:** `LAYERS_CAP_DROP` / `LAYERS_NEAR_CAP`; analyzer summary.
- **Files/components affected:** `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`, `Scripts/Analyze-AeloriaSoak.ps1`, `Docs/37-AELORIA-PHASE-E22-PLAN.md`
- **Dependencies:** PR 2

### PR 4: E.2.52 — Start transition hardening (conditional) — **SKIPPED**

- **Status:** Skipped 2026-07-04 — no Start-transition repro after E.2.47–E.2.51; late crash was family D @ ~58k frames (`1c4c2d18-c1be`), addressed by E.2.51. No DLL change.
- **Description:** Start/@2426 only if repro; else doc skip. **Gate not met** — documented skip in RCA + STATUS-WAVES.
- **Files/components affected:** `Docs/43-AELORIA-RCA-SKIRMISH-CRASH-20260702.md`, `Docs/32-AELORIA-STATUS-WAVES.md` (docs only)
- **Dependencies:** PR 3
- **Re-open when:** New soak shows abrupt tail at Start (~2426) with preview intercept storm and no `LIVE_SKIRMISH_ARMED`.

### PR 5: C1–C3 — Analyzer, launcher, WER hygiene

- **Description:** Quit vs crash; WER snippet; soak ladder.
- **Files/components affected:** `Scripts/Analyze-AeloriaSoak.ps1`, `Scripts/Launch-Aeloria.ps1`, `Docs/10-Development-Process-and-Deployment-Checklist.md`
- **Dependencies:** PR 1, PR 2, PR 3

### PR 6: B4 — MapGen v2 integration (126×8 reference-style)

- **Description:** 126×8 defaults; sidecars; Generate-RAMap recipes.
- **Files/components affected:** `Source/Rampastring-MoreQoL/CnCTDRAMapEditor/MapGen/*.cs`, `Scripts/Generate-RAMap.ps1`, `Scripts/Sync-LocalMap.ps1`, `Docs/CUSTOM-MAPS-CATALOG.md`, `Docs/11-Custom-Map-Local-Iteration.md`
- **Dependencies:** PR 9, PR 10, PR 11

### PR 7: A5 — Promote readiness docs + E.22 table

- **Description:** E.2.49–52 docs; Stable criteria draft.
- **Files/components affected:** `Docs/37-AELORIA-PHASE-E22-PLAN.md`, `Docs/10-Aeloria-Stable-v1-Release-Notes.md`, `Docs/HANDOFF-TO-NEW-OWNER-20260607.txt`
- **Dependencies:** PR 5, PR 6

### PR 8: B0 — Commit map tooling and local iteration docs

- **Description:** Commit Generate-RAMap, Sync-LocalMap, MapGen CLI.
- **Files/components affected:** `Scripts/Generate-RAMap.ps1`, `Scripts/Sync-LocalMap.ps1`, `Docs/11-Custom-Map-Local-Iteration.md`, `Source/Rampastring-MoreQoL/CnCTDRAMapEditor/MapGen/`
- **Dependencies:** PR 0

### PR 9: B1 — MapGen recipe schema and reference survey

- **Description:** TerrainProfile, SpawnLayout; catalog patterns.
- **Files/components affected:** `RedAlertSkirmishGenerator.cs`, `RedAlertMapSidecars.cs`, `Docs/CUSTOM-MAPS-CATALOG.md`
- **Dependencies:** PR 8

### PR 10: B2 — Terrain v2 (non-flat MapPack)

- **Description:** Non-flat terrain placement.
- **Files/components affected:** `RedAlertSkirmishGenerator.cs`, `TerrainPlacement.cs`, `ResourcePlacement.cs`
- **Dependencies:** PR 9

### PR 11: B3 — 126×8 spawn layouts and overlay richness

- **Description:** Octagon/no-shortage spawns; default 126 8p.
- **Files/components affected:** `RedAlertSkirmishGenerator.cs`, `ResourcePlacement.cs`, `Scripts/Generate-RAMap.ps1`
- **Dependencies:** PR 10