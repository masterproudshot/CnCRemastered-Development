# Project Aeloria — handoff statement

**Date:** 2026-07-05  
**Branch:** `experimental` @ `edc270e`  
**DLL submodule:** `Source/Rampastring-MoreQoL` · `improvements` @ `66637ad` (E.2.66)

---

## Mission (north star)

Playable **4p+ Experimental skirmish** on Remastered:

- Menus and launch OK  
- Units **visible, selectable, orderable** (human + AI) **indefinitely** on modern hardware (no artificial time limits; `max_frame` targets are for testing milestones only)  
- Full-zoom mod stack  
- **No WER / hard crash** on long soaks  
- **No frame-1 `LIVE_SKIRMISH_ARMED`**  
- **512 `CNCObjectStruct` client cap unchanged** (Unity/Remastered contract)

This is **not** “every sim entity on the map in the client buffer at once.” Late 4p can have **far more than 512** active technos; the DLL **admits ≤512 per `Get_Layer_State` export**. Invisibility = **not in client list this frame**, not deleted from sim.

---

## What is implemented (experimental arc)

| Epic | Status | Summary |
|------|--------|---------|
| E.2.56–58 | Shipped | Preview / layer populate, map buildings, human MCV |
| E.2.59–61 + 61b | Shipped | Cap log throttle, fail-closed, slot replace, draw-it replace, stab on replace |
| E.2.65 | Shipped | **Uniform** 512 policy — priority + list order; **no** map Y-third / south band hacks |
| E.2.66 | Shipped | Reshuffle cadence (default 15f), ramp `NEAR_CAP` throttle, sustain pending cache |

**Primary code:** `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`  
**Launch / soak:** `Scripts/Launch-Aeloria.ps1`, `Scripts/Analyze-AeloriaSoak.ps1`  
**Plans / RCA:** `Docs/37-AELORIA-PHASE-E22-PLAN.md`, `Docs/43-AELORIA-RCA-SKIRMISH-CRASH-20260702.md`

---

## Soak evidence (recent)

| Session | Wall | Frames (log) | G1 visibility | G4 stability | Perf / notes |
|---------|------|--------------|---------------|--------------|--------------|
| `a0e5d651-bf48` | ~44 min | ~67k | **Degraded 2nd half** — buildings/units disappearing | **PASS** — no WER | OK early; slow + vanish after ~cap onset ~43k f; ~24k replace, ~2.1M `LATE_GAME_AV_GUARD` |
| `c35496c3-7951` | ~30 min | ~53k | **PASS** (user) | **PASS** | Felt slow |
| `1f5f201c-7d98` | ~33 min | ~53k | Partial (~bottom 10%) | **PASS** | Pre–uniform cap |
| `f6af36ce-05b0` | ~60 min | crash ~61k | ~⅓ south blank | **FAIL** WER | Pre-replace; log storm |

**Interpretation:** **Stability (G4)** is largely solved for long runs. **Visibility (G1)** is **good early / mid**, **degrades under sustained 512 pressure** when object count ≫ cap. **Performance** degrades with cap + guard logging + replace churn.

---

## Why objects still disappear (root cause, one paragraph)

Remastered draws from a **512-slot LAYERS export** built each `Get_Layer_State`. When candidates exceed 512, Aeloria **trims**, **replaces** (evict tail non-priority slot), or **skips** (`layer_walk_skip`, `intercept_guard`). Retain priority favors **starting units, human deployed buildings, human-house technos**; other objects rotate out. **Replace** (~24k events in `a0e5d651`) swaps who holds a slot — sim objects remain, client mirror drops them. **Guards** skip unsafe/stale draws to avoid AV (E.2.51 lineage). **Universal literal visibility for every unit all game** requires **raising 512** or **client-side LOD/virtualization** — out of current DLL-only scope.

---

## Distance to “done” (honest)

| Bar | Distance |
|-----|----------|
| Long skirmish, no crash | **Near** — anchor `a0e5d651` |
| Uniform map policy (no regional hacks) | **Done** — E.2.65 |
| Full session “feels fast” | **Far** — AV guard + cap hot paths |
| No late-game disappearing (practical north star) | **Medium** — needs cap policy + perf; **impossible** for all AI clutter if ≫512 without contract change |
| Literal every unit always on screen | **Blocked** by **512** unless product changes client buffer |

---

## Recommended next work (priority order)

1. **E.2.67 — Late-game guard / log tax**  
   Throttle `LATE_GAME_AV_GUARD` in `-NC` (keep fail-closed **actions**); target second-half slowdown (`a0e5d651`: ~2.1M lines).

2. **E.2.68 — Cap replace debounce / churn**  
   Reduce re-evict of same pointers; optional retain for objects in tactical viewport (design: **not** north/south bands).

3. **Soak gate**  
   Analyzer on `a0e5d651-bf48`; compare `linesPerFrame`, replace rate, first `count==512` frame vs `c35496c3`.

4. **P1 hardening** (QE backlog)  
   `preview_safe_emit` replace @ cap; `LAYERS_SLOT_REPLACE_FAIL reason=all_priority`.

5. **Backlog**  
   E.2.60 MCV deploy; MapGen scripts (`GeneratedMaps/` local, gitignored).

---

## Operations

```powershell
# Build, deploy, soak (2h monitor cap)
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC

# Post-soak
.\Scripts\Analyze-AeloriaSoak.ps1 -DebugLog Logs\Aeloria-Debug_<session>.log -Profile P3
.\Scripts\Analyze-AeloriaSoak.ps1 -DebugLog Logs\Aeloria-Debug_<session>.log -Profile NS
```

**Rollback env (attribution):**

| Variable | Effect |
|----------|--------|
| `AELORIA_LAYERS_RESHUFFLE_CADENCE=0` | Reshuffle every near-cap export (E.2.65) |
| `AELORIA_LAYERS_SLOT_REPLACE=0` | No replace/reshuffle |
| `AELORIA_LAYERS_FAIR_TRIM=0` | Legacy trim only |
| `AELORIA_LAYERS_FAIL_CLOSED=0` | Disable fail-closed draw skip (debug) |

---

## Doc map

| Doc | Use |
|-----|-----|
| `33-AELORIA-COMPACT-HANDOFF.md` | `/compact` paste block |
| `35-AELORIA-NEXT-ROUNDS.md` | Active engineering queue |
| `AELORIA-PLAN-E265-UNIFORM-CAP.md` | Uniform cap design |
| `32-AELORIA-STATUS-WAVES.md` | Wave table |
| `archive/bugfixer-411/` | Old agent audits (reference only) |

---

## Handoff one-liner (paste)

```
experimental @ edc270e · DLL improvements @ 66637ad (E.2.66)
North star: 4p Experimental skirmish 20–30+ min, selectable units, no WER; 512 cap fixed
Done: uniform cap E.2.65, replace+61b, perf cadence E.2.66
Last soak a0e5d651-bf48: ~44m ~67kf no crash; 2nd half slow + disappear under 512 churn
Next: E.2.67 AV guard log throttle + E.2.68 replace churn; read Docs/AELORIA-PROJECT-HANDOFF.md
Launch: .\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
```

---

*Successor: treat **512 admission** as the visibility ceiling unless product approves client buffer work. Optimize for **stable, fast, human-playable** long skirmish under that constraint.*