# E.2.14 Produced Unit Unlimbo Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stop ~2-minute Experimental skirmish crashes by unifying produced war-factory / shipyard unlimbo draw policy — one coherent fix, not another edge patch.

**Architecture:** All recent WER crashes (`0xcebxx`–`0xcecxx`) share one root cause: `DLL_Draw_Intercept(0,0,0,…, shape=0)` at produced-unit unlimbo races VIRTUAL LAYERS export before MAIN tactical draw. E.2.13h/i fixed individual exit nodes (VIRTUAL shape-0, harvester grand opening, cache seed) but left the zero-map unlimbo intercept intact. E.2.14 mirrors the proven grand-opening harvester pattern: map-coord intercept with guarded shape 16 + mandatory MAIN cache before any bulk/sustain path runs.

**Tech Stack:** C++ REDALERT.DLL (Rampastring-MoreQoL), MSBuild v145, Launch-Aeloria.ps1 soak gates.

---

## Root Cause (Evidence)

| Session | Build | Last log | WER offset |
|---------|-------|----------|------------|
| `cfd9624e` | E.2.13g | `PRODUCED_UNIT_FIRST_DRAW` VIRTUAL | `0xcebbd` |
| `90bf63a9` | E.2.13h | `GRAND_OPENING_HARVESTER_OK` → `BULK_POST_COUNT` | `0xcebcc` |
| `46d82388` | E.2.13i | `PRODUCED_UNIT_UNLIMBO_SEED` medium tank, no FIRST_DRAW | `0xcec3d` |

Crash always in produced-unit draw graph, never infantry combat.

## Regression Gates (mandatory before Stable promotion)

- P1 soak: max frame ≥ 7500 (~10 min), no WER
- Kennel place: `CONSTRUCTION_COMPLETE type_enum=8` survives
- Zero `PRODUCED_AIRCRAFT_BAD_PLUS8_CLEARED`
- Main menu must not crash on exit

## Keep (do not regress)

- E.2.13h: VIRTUAL never shape-0 for produced units (`Aeloria_GuardedUnitShapeNumber`)
- E.2.13i: bulk/sustain defer until `Aeloria_HasValidMainDrawCache`
- E.2.9: aircraft eternal bad+8 pin
- E.2.13f: kennel human building place seed

---

### Task 1: Add unified ground-unit unlimbo seed helper

**Files:**
- Modify: `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`
- Modify: `Source/Rampastring-MoreQoL/REDALERT/FUNCTION.H`

- [ ] **Step 1:** Add `Aeloria_SeedProducedGroundUnitOnUnlimbo(TechnoClass*, int shapenum, int drawW, int drawH, bool runtime_bad_plus_8)`
- [ ] **Step 2:** Implementation mirrors `BUILDING.CPP` grand-opening harvester:
  - `Map.Coord_To_Pixel(Center_Coord())` for drawX/drawY
  - `DLL_Draw_Intercept(shapenum, drawX, drawY, w, h, AELORIA_CLIENT_DRAW_FLAGS_CENTER, …)`
  - `Aeloria_TryNotifyProducedUnitMainDrawCache` for MAIN cache
  - Guard: `shapenum <= 0` → 16

### Task 2: Wire TECHNO.CPP produced unit + vessel unlimbo

**Files:**
- Modify: `Source/Rampastring-MoreQoL/REDALERT/TECHNO.CPP` (~1437–1529)

- [ ] **Step 1:** Replace `DLL_Draw_Intercept(0,0,0,…)` in `producedUnit` block with helper call
- [ ] **Step 2:** Replace same in `producedVessel` block
- [ ] **Step 3:** Extend log line: `shape=%d pos=(%d,%d)` for soak verification
- [ ] **Step 4:** Remove redundant post-intercept cache seed (helper owns it)

### Task 3: Build and deploy

- [ ] **Step 1:** Sync worktree → `Development\Source`
- [ ] **Step 2:** `Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC`
- [ ] **Step 3:** Verify DLL timestamp + size in launcher log

### Task 4: P1 soak verification

- [ ] **Step 1:** Run 10+ min skirmish (kennel + WF + refinery + combat)
- [ ] **Step 2:** `Analyze-AeloriaSoak.ps1 -Profile P1` on session log
- [ ] **Step 3:** Only promote to Stable if P1 PASS

---

## Out of Scope (separate tracks)

- E.2.11 produced-unit graduation (perf/subjective speed)
- Infantry zero-map seed path (working; different policy)
- Stable promotion (blocked until P1+P3 PASS)