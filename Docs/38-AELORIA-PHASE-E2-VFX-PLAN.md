# Aeloria Phase E.2 — Aircraft & Flame VFX Plan

**Branch:** `experimental` only (leave `stable` @ `4ba2adf` as long-soak baseline until user sign-off)  
**Date:** 2026-06-27  
**Evidence:** Soak `ef4cfe9d-8498` — ~120 min, smooth, no WER; helis invisible, Mig blink, flame tower no VFX.

## Goals (acceptance)

| # | Symptom | Pass criteria |
|---|---------|----------------|
| G1 | Produced **Hind/Longbow** invisible | Visible at full zoom, selectable, rotors spin, orders/combat work |
| G2 | **Mig** (and other fixed-wing produced) blink while moving | Steady sprite on VIRTUAL every frame; no flicker during transit |
| G3 | **Flame tower** (and flamer stream) | `FBALL` / `FB2` stream visible when firing; no regression on other explosions |
| G4 | Stability | 20+ min 4p Aeloria skirmish without crash/WER (no `-D` for cert) |

## Root cause (one sentence)

Stability work routes produced aircraft through **cache-only MAIN + partial VIRTUAL emit**, leaving **empty VIRTUAL frames for fixed-wing** and **emit-only / guarded placeholders for rotors**; combat **anims** are not on bulk/sustain and can fail before client export.

## Workstreams

### WS1 — Helicopter visibility (P0)

**Problem:** Player helis (`bad_plus_8=0`) hit `PRODUCED_AIRCRAFT_LITE_MAIN_SEED` + early `return` at ~737–754; emit path uses intercept without guaranteed full LAYERS parity. AI helis (`bad_plus_8=1`) use guarded intercept + shape 16 / `DIR_N`.

**Changes (`AIRCRAFT.CPP`):**

1. **Unify produced rotor VIRTUAL draw** — Single function `Aeloria_DrawProducedRotorVirtualLayers(...)` called from:
   - E.1 block (full Techno + shadow + `Draw_Rotors` + overlay)
   - Lite-seed VIRTUAL branch (replace bare `EmitClientDraw` only)
   - Guarded VIRTUAL branch when `rotorProducedAircraft` (prefer full chain when `Get_Image_Data()` valid; fall back to emit + rotors)
2. **Reorder lite-seed block** — For `window == WINDOW_VIRTUAL` + rotor: **draw first**, then optionally refresh MAIN cache; never `return` without a VIRTUAL draw.
3. **Bad +8 rotors** — Use `Aeloria_Safe_Techno_Type` + `Shape_Number()` / guarded facing; pass **graphic name** (`HIND`, etc.) into `DLL_Draw_Intercept` where C# needs asset identity (mirror accessory intercept pattern).
4. **Logging** — One-shot `PRODUCED_ROTOR_VIRTUAL_PATH=legacy|emit|guarded` for soak grep.

**Changes (`DLLInterface.cpp`):**

5. Relax `Aeloria_RecordProducedAircraftVirtualEmit` / bulk defer: rotor with plausible +8 may bulk after **N** virtual layer draws even if MAIN cache used placeholder shape (coordinate with `Aeloria_ProducedRotorMayBulkWithoutMainCache`).
6. `Aeloria_PopulateEarlyBulkSlot` for aircraft: prefer **cached facing shape** + correct `AssetName` from `AircraftTypeClass::Graphic_Name()` when stab cache exists.

**Regression:** Scenario-start Migs unchanged; no guarded intercept when runtime +8 OK (5z-m7).

---

### WS2 — Fixed-wing blink (P0)

**Problem:** At ~737–754, produced **fixed-wing** on `WINDOW_VIRTUAL` hits `return` with **no draw** while `!mainCacheReady`.

**Changes (`AIRCRAFT.CPP`):**

1. In lite-seed block, add `else if (aircraft_type->IsFixedWing)` → call **`Aeloria_ProducedAircraftEmitClientDraw`** (or full virtual Techno path when Class valid) **every VIRTUAL frame**.
2. In `Aeloria_ProducedAircraftEmitClientDraw`: always apply **rotation** from `SecondaryFacing` / `Rotation16` (already partial); ensure **shape** from `Shape_Number()` not static 16 when drawable.
3. Sustain handoff (~757–771): MAIN still cache-only; VIRTUAL must **always** emit until `sustainRetired` — audit that fixed-wing never falls through with zero VIRTUAL work.

**Changes (`DLLInterface.cpp`):**

4. Avoid graduating aircraft off sustain while VIRTUAL exports drop (optional: require `sustainNormalHits` only increment on non-zero `CurrentDrawCount` contribution).

**Regression:** 5z-m7 — no guarded `DLL_Draw_Intercept` when +8 plausible on first Mig unlimbo.

---

### WS3 — Flame tower & combat anims (P1)

**Problem:** Flame stream = `BulletClass` spawns `ANIM_FBALL_FADE` (`FB2`); tower impact uses `ANIM_FBALL1`. `AnimClass::Draw_It` → `CC_Draw_Shape` on VIRTUAL; anims lack creation/bulk tracking; `Is_Drawable` / bad `+8` / `Class_Of()` in intercept may drop frames.

**Changes (`ANIM.CPP`):**

1. For `WINDOW_VIRTUAL` + combat types (`ANIM_FBALL1`, `ANIM_FBALL_FADE`, flamer-related): force `render_legacy = true` when `!IsInvisible` (override `VirtualAnim` gating on LAYERS).
2. Ensure `Stages`/`LoopEnd` resolved **before** stage check (keep Phase E fix).
3. Optional: pass explicit `width`/`height` from `Get_Build_Frame_*` for FBALL on VIRTUAL (helps intercept dims).

**Changes (`CONQUER.CPP` / `DLLInterface.cpp`):**

4. **`Aeloria_TryVirtualCombatAnimExport`**: if `object->What_Am_I() == RTTI_ANIM` and `window == WINDOW_VIRTUAL`, call `DLL_Draw_Intercept` with `shape_file_name` = anim type data name (`FB2`, `FBALL1`) even when `at+8` fails plausibility (extend E.1 pattern beyond techno).
5. In `DLL_Draw_Intercept` anim branch: if `Convert_Type` succeeds, set `AssetName` from anim virtual name; do not early-return `UNKNOWN` for anim without `hasCreation`.

**Verification:** Flame tower fires at infantry — visible stream; structure death FBALL still OK.

---

### WS4 — Prove it (P1)

1. **Build:** Release x86, `PlatformToolset=v145`.
2. **Deploy:** `Launch-Aeloria.ps1 -Profile Experimental -B -A -NC` (no `-D` for feel test).
3. **Short `-D` repro** (optional): grep `PRODUCED_ROTOR_VIRTUAL_PATH`, `PRODUCED_AIRCRAFT_FIRST_DRAW`, anim intercept lines.
4. **Playtest script:** helipad ×2 → 4 helis; airfield → 2 Migs move across map; 2 flame towers vs blobs.
5. **Soak:** `Analyze-AeloriaSoak.ps1` gates; 20+ min without WER.
6. **Promote stable:** only after G1–G4 + user sign-off; FF stable to experimental as today.

## Implementation order (DAG)

```
WS2 (Mig blink) ──┐
WS1 (heli)      ──┼──► WS4 playtest ──► stable promote (later)
WS3 (flame)     ──┘
```

WS2 is smallest diff and validates “never empty VIRTUAL” invariant. WS1 builds on same invariant for rotors. WS3 is parallel-safe.

## Files touched (expected)

| File | WS |
|------|-----|
| `REDALERT/AIRCRAFT.CPP` | 1, 2 |
| `REDALERT/DLLInterface.cpp` | 1, 2, 3 |
| `REDALERT/ANIM.CPP` | 3 |
| `REDALERT/CONQUER.CPP` | 3 (anim export helper) |
| `Docs/AELORIA-PHASE-E-COMPACT.md` | after ship |

## Out of scope (E.2)

- Perf overhaul beyond existing selection-gated HUD
- Stable branch code changes until promote
- Ore truck / infantry / starting-unit regressions (must stay green)

## Branch discipline

- All commits on **`experimental`** (submodule `improvements`).
- **`stable`** frozen at `4ba2adf` for daily long-play; document in commit messages: `E.2 experimental only`.