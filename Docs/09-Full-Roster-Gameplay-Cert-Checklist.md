# Full RA Roster — Gameplay Cert Checklist

Use after `Scripts/Audit-AeloriaCoverage.ps1` reports matrix PASS (UNIT/AIRCRAFT/VESSEL Layer-2 = FULL).

## Soak Prerequisites

- [ ] Deploy latest `RedAlert.dll` to `Aeloria-Experimental` via `.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -BuildFirst -AutoDeployDll -NC`
- [ ] DLL size logged in launcher output (expect ~1.3 MB post n9+n10)
- [ ] 4-player Aeloria skirmish, full zoom, human player active

## Minimum Soak Gate

| Check | Pass criterion |
|-------|----------------|
| Duration | max_frame >= 7500 (~25 min at 5 fps logic) |
| Exit | Clean launcher exit, no AV in Windows Event / crash dump |
| Log tail | No `SEVERE` corruption burst in final 500 lines of Aeloria_Debug.log |
| Spy plane | Build Airfield + Spy Plane; fly/reveal — no crash (n9) |
| Harvester | WF harvester mines invalid gem cells — `HARVEST_ORDER_REJECTED` only, no AV (n8d) |

## Full RA Roster — Production Paths

Mark each after intentional build + 30s visibility/command test in skirmish or naval test map.

### Infantry (barracks)

- [ ] E1 (rifle)
- [ ] E2 (grenadier)
- [ ] E3 (rocket)
- [ ] E4 (flamethrower)
- [ ] Engineer
- [ ] Tanya / Commando (faction)
- [ ] Spy
- [ ] Medic
- [ ] Dog

### Vehicles (war factory)

- [ ] Ore truck / harvester (refinery spawn + WF build)
- [ ] MCV deploy
- [ ] Light tank (faction)
- [ ] Medium / heavy tank
- [ ] APC
- [ ] Artillery
- [ ] V2
- [ ] Ore truck gem rejection at depleted cells

### Aircraft (helipad / airfield)

- [ ] Transport helicopter
- [ ] Attack heli (Longbow/Hind)
- [ ] Yak/Mig
- [ ] **Spy plane (U2)** — priority regression (n9)
- [ ] Badger (if available)

### Naval (shipyard) — **n10 priority**

- [ ] Transport LST
- [ ] Gunboat (PT)
- [ ] Destroyer (DD)
- [ ] Cruiser (CA)
- [ ] Submarine (SS)

### Buildings (MCV sidebar)

- [ ] Power plant
- [ ] Refinery + harvester dock
- [ ] Barracks
- [ ] War factory
- [ ] Helipad / Airfield
- [ ] Shipyard (naval maps)
- [ ] SAM / Tesla / turrets

## Aeloria Edge Cases

- [ ] t=0 all 4 player starting units visible
- [ ] Mid-game WF unit (#5+) draws on MAIN without placeholder stick
- [ ] Human building deploy at frame 35+ (power → barracks chain)
- [ ] Full map zoom pan during combat
- [ ] Quit mid-combat — acceptable; do not fail cert on `no_abrupt_tail` alone

## Cert Commands

```powershell
# Launch soak (debug logging recommended)
.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -DebugMode -NC

# Lightweight cert (stream — do not load full log in agent)
python agent-tools\launch_soak.py --log-dir <session-logs-folder>
```

## Sign-off

| Field | Value |
|-------|-------|
| Session ID | |
| max_frame | |
| DLL bytes | |
| n9 aircraft | pass / fail |
| n10 vessel | pass / fail |
| Cert date | |
| Promote to Stable? | blocked until all above PASS |