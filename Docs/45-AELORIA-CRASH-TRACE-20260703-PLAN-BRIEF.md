# Crash trace + plan-mode brief (2026-07-03)

**Purpose:** Handoff for plan mode — full *logical* stack from evidence, gaps (no WER zip), and PR-sized fix vectors.

---

## Evidence index (newest first)

| Session | Debug log | Launcher | DLL | MaxFrame | WER/Steam zip |
|---------|-----------|----------|-----|----------|---------------|
| `3f9170a1-e136` | `Logs/Aeloria-Debug_20260703_171628_3f9170a1-e136.log` | `Launch-Aeloria_20260703_171440_035_3f9170a1-e136.log` | E.2.46 (post-build) | **283** | None captured |
| **`885446a6-f040`** | `Logs/Aeloria-Debug_20260703_171102_885446a6-f040.log` | `Launch-Aeloria_20260703_165248_056_885446a6-f040.log` | E.2.45 (16:53:17) | **4135** | None captured |

**User-reported “just crashed” soak** maps to **`885446a6-f040`** (longest / latest user session). Short `e136` run was auto-launch after E.2.46 build (~0.7 min).

**Gap:** Launcher checked Steam + WER; **no** `Crash_*.zip` / `Crash_WER_*` for either session. Native **fault offset / module** not in repo — correlate manually via Event Viewer → Application Error (`InstanceServerG.exe` / `ClientG.exe`, `0xc0000005`) around **17:11:00** local.

---

## Primary crash — `885446a6-f040` (E.2.45)

### Timeline (wall clock)

| Phase | Frame | Event |
|-------|-------|--------|
| T0 | 0 | 17× `PLAYER_OBJECT_CREATED` / `FORCED_AT_UNLIMBO_CREATION` |
| T0 | 0 | **`DEAD_TRACKING_PRUNED creation=11`** @ `Get_Layer_State_preview` |
| T0 | 0 | `PREVIEW_PRUNE_DROP … plausible=0 has_creation=1` (misaligned pool `this`) |
| T0 | 0 | `STABILITY_RESEED_FROM_CREATION n=6` (only aligned subset kept) |
| Early | 0–66 | `UNIT_MAIN_GUARD` + `CLIENT_DRAW_INTERCEPT` OK for subset |
| Mid | 666 | **1TNK** `0D2C15C1`: `Unit guard passed` → `Techno_Draw_Object` → `IsRadarEquipped` log → **survives** (placeholder/CC path) |
| Mid | 2850+ | AI buildings `CONSTRUCTION_COMPLETE`; human refinery/WEAP seeds |
| Late | **3159** | **MCV** `0D2C1376`: `Unit guard passed` `Class.Raw=7`, `at+8=0x782d8800`, **`has_creation=0`** |
| Late | 3159–3161 | `CC_Draw_Shape` + `VIRTUAL_DRAW_ATTEMPT` (overload=main) for same MCV |
| Tail | **4135** | Log ends mid-`Get_Layer_State` burst: **only** `CLIENT_DRAW_INTERCEPT` (units/infantry/buildings), **no** shutdown marker |

**Skirmish lifecycle:** **No** `LIVE_SKIRMISH_ARMED` / `PENDING_MISSION_TIMER_APPLIED` in entire log → **PREVIEW-only** sim for full session.

### Logical call stack (instrumented path — MCV @ frame 3159)

This is the **last confirmed legacy MAIN unit path** before a long continued run; same class of bug as sub-minute crashes.

```
Remastered client requests layer
  → Get_Layer_State (preview disarm + Aeloria_PruneDeadTrackingKeys)
       → [frame 0] wiped 11/17 creation keys (plausible=0 on this pointer)
  → Draw_It / layer export
  → UnitClass::Draw_It (WINDOW_MAIN or tactical)
       → Aeloria_IsEarlyStartingUnitMainGuarded → false (no creation row)
       → Aeloria_StartingUnitLegacyMainBlocked → false (no creation / scenarioStart)
       → Aeloria_NeedsSafeMainDrawGuard → false
       → **"Unit guard passed"** (UNIT.CPP ~2324)
       → Get_Image_Data() / Shape_Number()
       → Techno_Draw_Object(...)
            → CC_Draw_Shape(Object overload) (CONQUER.CPP ~3479)
                 → [logged] at+8=0x782d8800
                 → VIRTUAL_DRAW_ATTEMPT / placeholder path (game continued)
       → **"DRAWING UNIT … IsRadarEquipped access about to happen"** (UNIT.CPP ~2388)
       → safeForRadarExtras gate (may skip radar blitter if +8 bad)
```

**Root cause (proven):** Preview prune used `Is_Plausible_Class_Pointer(this)` before creation retain → **misaligned** unit pool addresses (`0x….376` → `plausible=0`) erased from `g_AeloriaObjectCreationFrame` @ frame 0 → guards keyed on creation/`scenarioStartUnlimbo` **false** later → intermittent **legacy MAIN** for starting MCV/1TNK.

**Fix in tree:** **E.2.46** — `Aeloria_PreviewSkirmishTrackingRetain` retains on creation map without `this` plausibility; preview bad+8 belt in `Aeloria_IsEarlyStartingUnitMainGuarded`. **Not verified** on user P4 soak yet.

### Tail crash @ frame 4135 (hypothesis — plan mode should validate)

Last ~20 lines are **dense `CLIENT_DRAW_INTERCEPT`** only (RTTI 5/13/28, many `has_creation=1 stab=0`). **No** final `Unit guard passed` / `CC_Draw_Shape` after line 115573.

| Hypothesis | Clue | Plan action |
|------------|------|-------------|
| **H1 — ClientG / Unity** | Process dies without DLL logging final draw | Capture WER; check `ClientG.exe` vs `InstanceServerG.exe` |
| **H2 — Unlogged legacy draw** | Verbose off on some BUILDING/MAIN paths | Add one-shot tail marker before `Buffer_Frame_To_Page` for RTTI_BUILDING when `!DLL_Draw_Intercept` |
| **H3 — Sim / AI tick** | Long preview (4135 frames) with AI construction | Grep `CONSTRUCTION_`, `Place_*`, `TRACKING_CLEARED` near tail (sparse at 4135) |
| **H4 — Log flush lag** | 17:11:00 file end vs user crash | Compare launcher “Game processes have exited” timestamp |

**Analyzer:** `Analyze-AeloriaSoak.ps1 -Profile P1` → FAIL `no_abrupt_tail`, `max_frame_ge_7500`; PASS `crash_wer_captured` (misleading — means WER *not* archived, not “no crash”).

---

## Secondary crash — `3f9170a1-e136` (E.2.46 smoke)

- **M0 gates PASS:** `no_preview_mass_creation_prune`, `no_unit_guard_before_live_arm`.
- **Frame 0:** `PREVIEW_PRUNE_RETAINED creation=19` (no mass wipe).
- **Tail @ 283:** Repeating `CC_Draw_Shape got Object … RTTI=5 at+8=0xffffff00` interleaved with `CLIENT_DRAW_INTERCEPT` for same building pointers (`0DAB5A70`, `0DAB554E`, …).

**Logical stack (building):**

```
Get_Layer_State_preview
  → CLIENT_DRAW_INTERCEPT (safe slot fill)
  → [parallel?] CC_Draw_Shape(building) with corrupt +8 0xffffff00
       → if not caught by Aeloria_HumanBuildingNeedsPlaceholderDraw → blitter AV
```

**Plan vector E.2.47 (candidate):** Extend preview **building** policy: all `RTTI_BUILDING` with `!Is_Plausible_Class_Pointer(at+8)` in PREVIEW → force intercept/placeholder (mirror unit belt). Files: `CONQUER.CPP`, `BUILDING.CPP`, `OBJECT.H` (`Aeloria_HumanBuildingNeedsPlaceholderDraw` scope).

---

## Plan-mode PR DAG (suggested)

```
PR-A  Verify E.2.46 user soak (M0)
  └─ depends: deployed DLL ≥ E.2.46 build time
  └─ gate: P1 no_preview_mass_creation_prune + no_unit_guard_before_live_arm + max_frame≥300

PR-B  WER capture hardening (evidence)
  └─ Scripts/Launch-Aeloria.ps1: widen WER poll / delay after exit
  └─ Analyze-AeloriaSoak: pass -LauncherLog; surface windowsAv line in verdict

PR-C  Starting-unit MAIN — never graduate on Class.Raw garbage (belt)
  └─ UNIT.CPP: block "guard passed" when Class.Raw < plausible threshold OR !TechnoClassRawIsHealthy in PREVIEW
  └─ even if creation map intact

PR-D  Preview building CC_Draw_Shape (e136 class)
  └─ CONQUER.CPP CC_Draw_Shape: preview + bad +8 building → DrawSafePlayerPlaceholder

PR-E  Live arm / Start transition (PR5 from E.2.45 plan)
  └─ only if M0 PASS but post-Start or ~2426 regressions return
  └─ see Docs/AELORIA-PLAN-E245-NORTHSTAR-PATH.md

PR-F  P4 north star sign-off
  └─ max_frame≥7500, no abrupt tail, 20–30 min wall clock
```

---

## Commands for plan / verify

```powershell
# Newest log + gates
Scripts\Analyze-AeloriaSoak.ps1 -Profile P1 `
  -DebugLog Logs\Aeloria-Debug_20260703_171102_885446a6-f040.log `
  -LauncherLog Logs\Launch-Aeloria_20260703_165248_056_885446a6-f040.log

# E.2.46 smoke
Scripts\Analyze-AeloriaSoak.ps1 -Profile P1 `
  -DebugLog Logs\Aeloria-Debug_20260703_171628_3f9170a1-e136.log `
  -LauncherLog Logs\Launch-Aeloria_20260703_171440_035_3f9170a1-e136.log

# Grep anchors
# creation wipe: DEAD_TRACKING_PRUNED|PREVIEW_PRUNE_DROP
# legacy unit:    Unit guard passed|Techno_Draw_Object|IsRadarEquipped
# building risk:  CC_Draw_Shape got Object.*RTTI=5.*ffffff00
```

---

## Key source anchors

| Topic | File | Symbol / area |
|-------|------|----------------|
| Preview prune | `DLLInterface.cpp` | `Aeloria_PreviewSkirmishTrackingRetain`, `Aeloria_PruneDeadTrackingKeys`, `Get_Layer_State` preview branch |
| Plausible=this | `OBJECT.H` | `Is_Plausible_Class_Pointer` (alignment `(ptr & 3)`) |
| Unit legacy MAIN | `UNIT.CPP` | `Draw_It` ~2307–2394 |
| CC intercept | `CONQUER.CPP` | `CC_Draw_Shape` ~3479+ |
| Guards | `OBJECT.H` | `Aeloria_StartingUnitLegacyMainBlocked`, `Aeloria_IsEarlyStartingUnitMainGuarded` |
| Gates | `Scripts/Analyze-AeloriaSoak.ps1` | E.2.45 lifecycle gates ~202+ |

---

## Tips for plan mode

1. **Treat “no WER zip” as first-class risk** — logical stack is strong for E.2.45; **faulting IP** still unknown for frame-4135 tail.
2. **Do not claim north star on E.2.46** until user P4 — e136 only proves **M0-style** gates for ~283 frames.
3. **Two crash families** in play: (A) starting-unit tracking prune → unit MAIN, (B) preview building `CC_Draw_Shape` with `at+8=0xffffff00`.
4. **PREVIEW without live arm** is expected for custom skirmish — plans must not reintroduce frame-1 `LIVE_SKIRMISH_ARMED`.
5. **Misaligned `this`** is not the same as **bad `at+8`** — retain policy fixes (A); alignment check in `Is_Plausible_Class_Pointer(this)` may still block other code paths.
6. Update `Docs/AELORIA-RCA-SKIRMISH-CRASH-20260702.md` session table with `885446a6` + `e136` when closing PR-A.

---

*Generated from agent trace session 2026-07-03 — evidence-first, no native stack without WER.*