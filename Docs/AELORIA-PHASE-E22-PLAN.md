# Aeloria Phase E.2.2 — VFX Implementation Plan

See session plan for full detail; this file mirrors the implementation DAG for the repo.

**Branch:** `experimental` only. **Stable:** frozen until G1–G4.

## DAG

PR0 instrumentation → PR1 Mig → PR2 Heli → PR3 Flame → PR4 playtest → PR5 soak → PR6 promote

## Acceptance

- G1: HIND/LONGBOW visible + rotors  
- G2: MIG no blink when moving  
- G3: Flame tower FBALL VFX visible  
- G4: 20+ min no abrupt crash  

## Evidence

Soak `d8ee4506-c453` (74 min PASS); log `Logs/Aeloria-Debug_20260627_165256_d8ee4506-c453.log`

## E.2.1 guards (keep)

- Fixed-wing intercept defer until MAIN cache  
- No rotor virtual layers when `bad_plus_8`  

## E.2.2 shipped (experimental)

- **PR1:** Skip `PRODUCED_AIRCRAFT_INTERCEPT_DEFER` when `shape_file_name` is set (explicit VIRTUAL emit); Mig uses guarded facing shape every frame.
- **PR2:** `bad_plus_8` rotors use emit+accessories; `PRODUCED_HELI_DRAW_PATH` logs.
- **PR3:** `Aeloria_TryVirtualCombatAnimExport` on normal LAYERS path; `EPHEMERAL_ANIM_EXPORT`; anim `AssetName` without `Class_Of` for FBALL types.