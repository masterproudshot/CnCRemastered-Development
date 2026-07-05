# Aeloria compact handoff (`/compact`)

**Branch:** `experimental`  
**Parent:** see `git log -1` · **DLL submodule:** `improvements` @ **E.2.66** (perf: reshuffle cadence)

## North star

4p+ Experimental skirmish: menus OK, units **visible / selectable / orderable** (human + AI), **20–30+ min** (`max_frame ≥ 7500`), full-zoom mods, **no WER crash**. No frame-1 `LIVE_SKIRMISH_ARMED`. **512 client cap** unchanged.

## Last soaks

| ID | Result |
|----|--------|
| `c35496c3-7951` | **G1/G4 PASS** (user) — full map OK, ~**30 min**, no crash; **perf: slow** |
| `1f5f201c-7d98` | G1 partial (~bottom 10% blank); 61b; ~53k frames |
| `f6af36ce-05b0` | G1 fail + crash @ ~61k (pre-replace) |

## Landed (E.2.65)

Uniform cap: `Aeloria_LayersUniformCompactSlots`, tail LRU evict, no `y_third`. Infantry `InfantryLayersExportReady`, foot replace @ 512. Plan: `Docs/AELORIA-PLAN-E265-UNIFORM-CAP.md`.

## Next

**Soak E.2.66** — confirm faster feel + G1/G4 (`Docs/AELORIA-NEXT-ROUNDS.md`).

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
```

**Code:** `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp`