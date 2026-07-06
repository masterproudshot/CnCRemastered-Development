# Aeloria compact handoff — 2026-06-27

## Branches
- **`stable`** @ `4ba2adf` — long-soak baseline (Phase E.1, ~2h PASS `ef4cfe9d`). **Do not advance** until VFX + stability sign-off.
- **`experimental`** @ `d2a7d09` — VFX work + **E.2.1 crash hotfix** (submodule `9c38d8f`).

## Yes — E.2.1 fix is implemented & committed (not playtested after fix)
| Commit | What |
|--------|------|
| `bb1b9f4` | Phase E.2: heli LAYERS/emit, flame anim export, Mig VIRTUAL emit in lite-seed |
| `9c38d8f` | **E.2.1:** restore `PRODUCED_AIRCRAFT_INTERCEPT_DEFER` for plausible+8 fixed-wing until MAIN cache; **no** `Aeloria_DrawProducedRotorVirtualLayers` when `bad_plus_8` |
| `d2a7d09` | Parent bump to `9c38d8f` |

**Not deployed to live** unless user runs launcher after build. Last playtest was **E.2** DLL (`7644cab9`, ~10m user crash, no WER).

## Open symptoms (pre–E.2.1 retest)
- Helis often invisible; Mig blink; flame tower no VFX — E.2 targeted; visibility unconfirmed.
- E.2 **regression:** ~10m crash — blamed on removed Mig intercept defer + legacy rotor on bad +8.

## Next actions after compact
1. Build/deploy: `Launch-Aeloria.ps1 -Profile Experimental -B -A -NC` (optional `-D` if crash).
2. Playtest: helipad, Mig move, flame tower, **20+ min** stability.
3. Promote **stable** only after G1–G4 + user OK.

## Key files (E.2 / E.2.1)
`REDALERT/AIRCRAFT.CPP`, `REDALERT/DLLInterface.cpp` (~5184 intercept defer), `REDALERT/ANIM.CPP`, `REDALERT/CONQUER.CPP`, `REDALERT/function.h`.

## Plans
`Docs/AELORIA-PHASE-E2-VFX-PLAN.md`, `Docs/AELORIA-PHASE-E-COMPACT.md`.

## Launcher rule
Never deploy while `ClientG` / `InstanceServerG` running.