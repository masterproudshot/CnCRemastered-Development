# Aeloria — next rounds

**Handoff:** `Docs/AELORIA-PROJECT-HANDOFF.md`

**Branch:** `experimental` @ `edc270e` · **DLL:** `improvements` @ `66637ad`

## Closed

- E.2.65 uniform 512 LAYERS  
- E.2.66 reshuffle cadence, ramp log throttle, sustain cache  
- Long-run stability anchor: `a0e5d651-bf48` (~67k f, no WER)

## P0 — visibility + perf under cap (`a0e5d651` learnings)

1. **E.2.67** — `LATE_GAME_AV_GUARD` log throttle in `-NC` (keep safety skips); cut ~2M-line tax.  
2. **E.2.68** — Replace debounce / reduce churn (~24k `LAYERS_SLOT_REPLACE`); optional viewport-biased retain (no geography).  
3. Soak compare: `a0e5d651` vs `c35496c3` — `linesPerFrame`, cap onset frame, replace count.

**Pass:** 15–30 min playable; human + tactically relevant AI stay visible; subjectively faster 2nd half; no WER.

## P1 — hardening

- `preview_safe_emit` replace @ cap  
- `LAYERS_SLOT_REPLACE_FAIL reason=all_priority`  
- Analyzer: uniform clamp + replace stats (drop `LAYERS_TRIM_BAND`)

## P2 — backlog

- E.2.60 MCV deploy (if repro)  
- MapGen / `GeneratedMaps/` (local, gitignored)

## Commands

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
.\Scripts\Analyze-AeloriaSoak.ps1 -DebugLog Logs\Aeloria-Debug_*_<session>.log -Profile NS
```

**Rollback:** `AELORIA_LAYERS_RESHUFFLE_CADENCE=0`, `AELORIA_LAYERS_SLOT_REPLACE=0`