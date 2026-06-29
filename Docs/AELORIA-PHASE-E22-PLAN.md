# Aeloria Phase E.2.2 — VFX Implementation Plan

See session plan for full detail; this file mirrors the implementation DAG for the repo.

**Branch:** `experimental` for new work. **Stable:** promoted E.2.9/E.2.10 @ 2026-06-28 (submodule 9ad2ae4).

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

## E.2.4 (heli move crash)

- **Cause:** After `BAD_PLUS8_CLEARED` + MAIN cache, produced helis took `DrawProducedRotorVirtualLayers` → legacy `Techno_Draw_Object` / `Draw_Rotors` while `sustainRetired` still false.
- **Fix:** `Aeloria_ProducedRotorPrefersSafeEmit` — guarded emit until sustain handoff; block legacy fall-through.

## E.2.8 (spy plane) — LOCKED WIN

- Eternal bad+8 pin for fixed-wing produced aircraft.
- Evidence: soak `e8c9e63e-f505` 80min, zero `BAD_PLUS8_CLEARED` on type_enum=2.

## E.2.9 (rotor eternal pin) — PROMOTED STABLE

- Never clear `producedUnitBadPlus8` for rotors in Draw_It or MAIN cache notify.
- Evidence: soak `77c18c92-c862` 83min clean quit; `72db29b5-a2b7` P4 PASS.

## E.2.10 (perf logging/prune) — PROMOTED STABLE

- Placeholder logs gated verbose + once-per-object; aggressive stab prune when remain_stab > 400.
- Note: late-game FPS still unacceptable; E.2.11 graduation planned on experimental.

## E.2.11 (next, experimental only)

- Produced-unit graduation off eternal guarded draw; yellow marker removal. See `Docs/superpowers/plans/2026-06-29-e211-produced-unit-graduation.md`.