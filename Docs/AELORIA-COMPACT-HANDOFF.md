# Aeloria compact handoff (`/compact`)

**Full handoff:** `Docs/AELORIA-PROJECT-HANDOFF.md`

**Branch:** `experimental` @ `edc270e` · **DLL:** `improvements` @ `66637ad` (E.2.66)

## North star

4p+ Experimental skirmish: menus OK, units **visible / selectable / orderable** (human + AI), **20–30+ min** (`max_frame ≥ 7500`), full-zoom mods, **no WER**. **512 client cap** unchanged — not literal “every sim unit at once.”

## Last soak

| ID | Result |
|----|--------|
| `a0e5d651-bf48` | **G4 PASS** ~44m ~67kf; **G1 degrades 2nd half** (disappear); perf OK then slow |

## Landed

E.2.65 uniform cap · E.2.61b replace · E.2.66 perf cadence

## Next

E.2.67 guard/log tax · E.2.68 replace churn — `Docs/AELORIA-NEXT-ROUNDS.md`

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
```