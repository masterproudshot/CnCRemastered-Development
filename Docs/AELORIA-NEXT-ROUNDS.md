# Aeloria — next rounds (post E.2.65)

**Branch:** `experimental` · **DLL:** `Source/Rampastring-MoreQoL` @ `improvements` (E.2.65 `7047646`)

## Closed this cycle

| Item | Evidence |
|------|----------|
| Uniform 512 LAYERS (no Y-third) | E.2.65 landed |
| G1 full-map visibility (user) | Soak `c35496c3-7951` — **no issues**, ~30 min wall |
| G4 clean exit | Same soak, no WER zip |

## P0 next — performance (user: “rather slow”)

Investigate **before** new gameplay features:

1. **E.2.66 reshuffle cadence** — `Aeloria_ReshuffleLayersListAtCap` on every export when `count ≥ 480`; gate to `count==512` or every N frames (QE Issue 4).
2. **Cap-pressure hot paths** — `TryReplace` + `Draw_It` replace at 512; profile replace count vs `1f5f201c` (26k events).
3. **Sustain / foot passes** — full scan of `g_AeloriaObjectStability` per `Get_Layer_State`; budget or early-out when `sustainRetired` dominant.
4. **Debug log I/O** — `-NC` uses `AELORIA_QUIET=1`; confirm lines/frame vs `f6af36ce`; extend E.2.61 throttle to 480→512 ramp if needed.
5. **Analyzer baseline** — `Analyze-AeloriaSoak.ps1` on `Aeloria-Debug_*_c35496c3-7951.log` for `max_frame`, replace rate, cap-onset frame.

**Pass bar:** Subjectively “fast as `d693a684`” or within ~10% wall clock for 15 min skirmish; no G1/G4 regression.

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