# E.2.65 — Uniform LAYERS cap (no map geography)

**Replaces:** geographic Y-third / south-decile plans (`E.2.59` band quotas, `E.2.62` south PR stack).

## Principle

The **512 client slots** use one policy everywhere on the map:

1. **Retain** — starting units, human deployed buildings, active human-house technos (`RetainPriorityV2`).
2. **Everyone else** — stable **list order** (walk / export order), no north/south scoring.
3. **At cap** — **slot replace** evicts the **last** non-retained slot (LRU tail), then admit incoming object (`draw_it` or bulk).
4. **Trim / clamp / reshuffle** — single `Aeloria_LayersUniformCompactSlots` (priority block + FIFO tail).

No `y_third`, no `LAYERS_TRIM_BAND`, no histogram skip at cap.

## Infantry (minimal guards, early exit)

- **`Aeloria_InfantryLayersExportReady`** — healthy techno + (`MAIN` cache **or** client slot + resolvable LAYERS pixel coords).
- Tracking maps drop when LAYERS-safe; **MAIN / AV guards unchanged** until MAIN cache where still required.
- **Foot sustain** — replace @ cap before drop; infantry uses same export-ready gate as vehicles use MAIN cache.

## Rollback

| Env | Effect |
|-----|--------|
| `AELORIA_LAYERS_FAIR_TRIM=0` | E.2.49 legacy trim (still no geography) |
| `AELORIA_LAYERS_SLOT_REPLACE=0` | cap drops only |

## Acceptance

- G1: full map visibility @ 15+ min (no regional band tuning).
- G4: no WER @ 30+ min.
- Logs: `LAYERS_SLOT_REPLACE idx=…` / `mode=draw_it`; `total_clamp_uniform` if overflow trim.

## Soak

| ID | Result |
|----|--------|
| `c35496c3-7951` | User: no visibility/crash issues ~30 min; **wall clock felt slow** |

## Verify

```powershell
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC
```