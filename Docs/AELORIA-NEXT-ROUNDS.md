# Aeloria — next rounds (post E.2.65)

**Branch:** `experimental` · **DLL:** `Source/Rampastring-MoreQoL` @ `improvements` (E.2.65 `7047646`)

## Closed this cycle

| Item | Evidence |
|------|----------|
| Uniform 512 LAYERS (no Y-third) | E.2.65 landed |
| G1 full-map visibility (user) | Soak `c35496c3-7951` — **no issues**, ~30 min wall |
| G4 clean exit | Same soak, no WER zip |

## P0 — performance (E.2.66 landed — soak to confirm)

Implemented: reshuffle cadence, ramp NEAR_CAP throttle, sustain pending cache.

**Next measure:**

1. Soak vs `c35496c3-7951` — subjective speed + G1/G4.
2. If still slow: profile replace volume, foot sustain, `Reshuffle` @ 512 every export.

**Rollback:** `AELORIA_LAYERS_RESHUFFLE_CADENCE=0`

## P1 — hardening (small PRs)

- `preview_safe_emit` replace @ cap (QE Issue 6).
- `LAYERS_SLOT_REPLACE_FAIL reason=all_priority` when evict list empty (QE Issue 8).
- Analyzer: drop `LAYERS_TRIM_BAND` gate; add uniform `total_clamp_uniform` + replace idx stats.

## P2 — backlog

- E.2.60 MCV deploy/control (only if repro).
- MapGen / `GeneratedMaps/` workflow (untracked local assets — not in git).
- Consolidate accidental `Docs/archive/bugfixer-411/` reports (reference only).

## Commands

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
.\Scripts\Analyze-AeloriaSoak.ps1 -DebugLog Logs\Aeloria-Debug_*_c35496c3-7951.log -Profile P3
```

**Rollback:** `AELORIA_LAYERS_SLOT_REPLACE=0`, `AELORIA_LAYERS_FAIR_TRIM=0`, `AELORIA_LAYERS_FAIL_CLOSED=0`