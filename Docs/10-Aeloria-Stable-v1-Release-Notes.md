# Aeloria-Stable-v1 Release Notes

**Project:** Project Aeloria  
**Version:** Stable v1  
**Release Date:** May 17, 2026  
**Status:** First Official Baseline

---

## Overview

Aeloria-Stable-v1 is the **first official, production-ready release** of Project Aeloria — a comprehensive stability and quality-of-life overhaul for *Command & Conquer: Red Alert Remastered*.

This baseline was created to finally resolve the long-standing 0xC0000005 access violation crashes that occurred shortly after scenario initialization. These crashes were caused by struct packing / ODR mismatches under the game's legacy `/Zp1` + `WINDOWS_IGNORE_PACKING_MISMATCH` configuration, which corrupted `CCPtr<T>` layout.

---

## Core Problem & Solution

**Root Cause**  
Struct packing mismatch between Westwood's 1990s-era classes and modern compiler defaults led to corrupted pointers (especially `CCPtr<T>` members) once `ScenarioInit` dropped to zero, triggering immediate crashes on the first `Map.Render()` call.

**Approach Taken (Option A – RedAlert only)**  
Instead of deep surgery on object creation paths, the team implemented a layered defense:

- Virtual guards on every `*Class`-derived type (`Is_Plausible_Class_Pointer` + `Class_Is_Valid`)
- One-frame early-load grace period
- Long human-player exemption window (`PLAYER_EXEMPTION_FRAME_COUNT = 18000` frames ≈ 5 minutes)
- Phase-C safe 32×32 placeholder rendering for exempt objects via `DLL_Draw_Intercept`

---

## Major Improvements

### 1. Stability System
- Virtual pointer validation on all major class hierarchies (AbstractTypeClass and derived types)
- Extended human exemption window with grace frame handling
- Safe fallback rendering path for objects that fail validation during the exemption period

### 2. Logging & Diagnostics Overhaul
- "Log once per object per message" system (`Aeloria_ShouldLogOncePerObject` + bitmask)
- Global runtime toggle: `g_AeloriaEnableVerboseDrawLogs` (default **off**)
- Controlled via the `AELORIA_ENABLE_VERBOSE_DRAW_LOGS` environment variable
- All severe safety reports and final exemption statistics remain always enabled

### 3. Production Launcher (`Launch-Aeloria.ps1`)
Major modernization of the daily workflow tool:

- Real MSBuild integration (prefers `vswhere`, with multiple fallback paths)
- `-BuildFirst` + deferred `-AutoDeployDll` logic ("build first, then deploy only on success")
- `-DebugMode` (`-D`) now forces verbose logging for the entire session via environment variable
- Short options: `-B` (BuildFirst), `-D` (DebugMode), `-A` (AutoDeployDll), `-P` (Profile), `-F` (ForceCleanup)
- Robust MSBuild output handling, state machine, backup/restore, crash report capture, and visible window monitoring

---

## Verified Behavior

- 20+ minute play sessions stable in both normal and DebugMode
- First successful end-to-end run of the recommended command:
  ```powershell
  .\Launch-Aeloria.ps1 -Profile Stable -BuildFirst -AutoDeployDll
  ```
- Fresh DLL correctly auto-deployed and launched with `MOD=Aeloria-Stable`
- DLL successfully propagated to Experimental and Vanilla-Plus profiles

---

## Known Limitations & Remaining Issues

While Aeloria-Stable-v1 represents a major improvement in stability for normal play, it is a **pragmatic stabilization layer**, not a complete architectural fix for the underlying struct packing problems. The following issues are known and still require attention:

### Remaining Crash Potential
- Crashes can still occur, especially after the human exemption window expires (after ~5 minutes of real-time play).
- Certain edge cases, late-game reinforcements, or specific unit combinations may still trigger access violations.
- The current guards and exemption logic significantly reduce frequency, but do not eliminate all risk.

### Performance & Visual Issues
- **DebugMode slowdowns**: Enabling `-DebugMode` (which forces verbose logging) can cause noticeable performance degradation, especially in the first 1–2 minutes of a skirmish.
- **Invisible units**: Infantry and other units (including enemy AI) may fail to render properly in some situations. This is more common during the early phase of a game or when many objects are created simultaneously.
- **Initial performance ramp-up**: Even in normal mode, some players may experience a brief period of reduced performance in the first 60–120 seconds as the exemption and logging systems settle.

### Other Known Trade-offs
- The current implementation uses a long human exemption window and safe placeholder rendering as a mitigation strategy rather than solving the root cause at the object creation level.
- Some visual glitches and rendering anomalies may still appear under heavy load or with specific unit mixes.
- The solution is currently RedAlert-only. TiberianDawn has not received the same level of stabilization work.

### Why These Are Being Called Out

These limitations are documented so players understand that while Aeloria-Stable-v1 is a **solid, playable baseline**, it is not yet a "set and forget" perfect fix. Further work is planned in the Experimental branch to address the remaining crash vectors, rendering issues, and performance problems.

---

## Recommended Usage

From the `Scripts` folder:

```powershell
.\Launch-Aeloria.ps1 -Profile Stable -BuildFirst -AutoDeployDll
```

Use `-DebugMode` (or `-D`) when you want the full internal diagnostic logs for troubleshooting.

---

## Scope

All changes in this baseline are **RedAlert-only**. TiberianDawn remains untouched, per the original design decision.

---

## Verification

- Multiple 20+ minute play sessions completed with no crashes in both DebugMode (full diagnostics) and normal mode (minimal logging, snappy performance).
- End-to-end launcher workflow validated.
- All three profiles (Stable, Experimental, Vanilla-Plus) successfully updated with the baseline DLL.

---

**This is the first shippable Stable baseline for Project Aeloria.**