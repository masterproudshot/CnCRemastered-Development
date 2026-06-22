# Aeloria Phase E — Compact Handoff (2026-06-22)

## North stars
1. **Primary:** 4p Aeloria skirmish 20–30+ min, full zoom, no crash.
2. **Secondary:** Smooth play under unit load; gameplay parity (VFX, helis, HUD).

## Validated (session `c244e5d0-6cfa`, Experimental Phase D DLL)
- **PASS** P3 soak (~56.7k frames), clean victory exit.
- **HUD:** Ore truck health + ore pips — OK.
- **Heli:** Hind (`type_enum=6`) → `PRODUCED_AIRCRAFT_BAD_PLUS8` at unlimbo; no `FIRST_DRAW`/`MAIN_CACHE`; invisible but logic present. Migs (`type_enum=3`) clean path.
- **Flame tower:** No FBALL/stream VFX on LAYERS.
- **Perf:** `-D` → ~704k log lines; slowdown in big fights. `Aeloria_SyncVirtualSelectionHud` + `PopulateTechnoHudFields` (Logic_Switch_Player_Context loop) on every VIRTUAL draw for unit/inf/air.

## Git anchors
- Submodule `improvements`: Phase D `47a5fe4` → Phase E (rotor virtual emit, FBALL stages, selection HUD).
- Parent: `experimental` + `stable` compact doc `a43d764`; Phase E submodule commits after build.

## Multi-tier execution plan

### Tier 1 — Heli parity (P0)
- Stop helipad rotor aircraft from eternal `BAD_PLUS8` trap when runtime `+8` plausible (mirror m4 Mig clear).
- Ensure VIRTUAL emit: body `Aeloria_GuardedAircraftShapeNumber` + asset **HIND**/HELI + `RROTOR`/`LROTOR` intercepts.
- Seed `MAIN` cache from guarded MAIN pass even for rotor craft; bulk/sustain must not defer forever (`!hasCachedMainDraw`).

### Tier 2 — Flame / combat anims (P1)
- `AnimClass::Draw_It`: FBALL / flame stream exports on `WINDOW_VIRTUAL` (audit `render_legacy` vs `VirtualAnim` for `ANIM_FBALL_*`).
- Invisible flame bullets stay invisible; spawned `ANIM_FBALL_FADE` must reach client via LAYERS.

### Tier 3 — Performance (P1)
- Gate `Aeloria_SyncVirtualSelectionHud` to **selection only** (or once/frame/object), not every VIRTUAL intercept.
- Keep HUD populate on `Aeloria_PopulateEarlyBulkSlot` + selection sync.

### Tier 4 — Ship
- Build Release x86 → deploy Experimental → playtest without `-D` (smooth) + spot `-D` repro.
- Promote Stable after user sign-off.

## Key files
`AIRCRAFT.CPP`, `DLLInterface.cpp` (seed unlimbo, sustain, `TrySafeVirtualDraw`), `ANIM.CPP`, `UNIT.CPP`/`INFANTRY.CPP`, `OBJECT.H`.

## Launch
`.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -NC` (add `-B` after code changes; `-D` only for short repro).