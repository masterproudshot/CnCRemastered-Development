# Aeloria compact handoff (`/compact`)

**Branch:** `experimental`  
**Parent:** `90f9c41` · **DLL submodule:** `f7a929e` (E.2.61 + E.2.59b + **E.2.61b** QE major fixes)

## North star

4p+ Experimental skirmish: menus OK, units **visible / selectable / orderable** (human + AI), **20–30+ min** (`max_frame ≥ 7500`), full-zoom mods, **no WER crash**. No frame-1 `LIVE_SKIRMISH_ARMED`. **512 client cap** unchanged.

## Last soak (pre-61b)

| ID | Result |
|----|--------|
| `f6af36ce-05b0` | **G1 FAIL** — south third blank ~frame **16459** (cap pinned 512); **crash ~61214** (family D); log storm `LAYERS_NEAR_CAP` / `LAYERS_CAP_DROP` |
| `d693a684-49e9` | Stable long run, south blank (anchor pre-59) |

## E.2.61b (landed)

QE bugs 1–3 (`Docs/AELORIA-REVIEW-E261-E259b-QE.md`):

1. **Preview strip** — `StripUnsafeDrawSlots` no-op on preview walk; retain populate/priority on live.
2. **Replace at cap** — `Draw_It` into evicted slot (`mode=draw_it`); `drawSlotBase` for factory/shadow; no `TotalObjectCount +=` on in-place replace.
3. **Stab map** — `OnLayersSlotReplaced` after bulk + draw-it replace.

**Rollback:** `AELORIA_LAYERS_SLOT_REPLACE=0`, `AELORIA_LAYERS_FAIL_CLOSED=0`, `AELORIA_LAYERS_FAIR_TRIM=0`

## Next

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
```

P0: 5 min preview MCV/buildings selectable; 15+ min south third; 30+ min no WER. Analyze with `.\Scripts\Analyze-AeloriaSoak.ps1`. Deferred: foot_sustain/preview_safe_emit replace, reshuffle cadence, E.2.60.

**Code:** `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`