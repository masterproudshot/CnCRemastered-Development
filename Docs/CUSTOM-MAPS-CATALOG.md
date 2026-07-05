# Red Alert custom maps (local)

Location: `Documents\CnCRemastered\Local_Custom_Maps\Red_Alert\`

## Your favorites (surveyed 2026-07-01)

### No shortage of money (family)

| Display name | Notes |
|--------------|--------|
| **No shortage of money.** | Multiple UGC copies (workshop + local variants); **126×126**, temperate, **8 waypoints** |
| **No shortage of money-beta** | Local edit copy (`UGC_0110000112A57151_no-shortage-of-money-beta`); same 8 spawn layout as theta (cells 2321…13933) |
| **No shortage of money-theta** | Local edit copy; **8 player starts**, 126×126 |

Workshop author on base map: **battes1983**. Economy is map ore/layout (house `Credits=0` in INI — not inflated start cash).

### Octagon (Open) lineage

| Version | File hint |
|---------|-----------|
| V1.0 (Closed) | `Octagon (Closed) V1.0` |
| V1.1 | Several UGC + `UGC_…D5F5C1DF` |
| V1.2 | `UGC_011000062246154_…R5CXD7` |
| V1.3 | `UGC_01100007936468_…EARTN0` |
| **V1.4** | `UGC_011000069632622_…M6FGG1` and `UGC_011000079375325_…E7RMN3` (author **DukeNukemRox** on E7RMN3) |

All surveyed Octagon / No-shortage locals: **126×126**, **`[Multi1]`–`[Multi8]`**, **8 waypoints**.

### Other maps in folder

| Name | Size |
|------|------|
| T4 (AI procedural) | 64×64, 4 waypoints (4p gen) |
| Spinos Octa-Quartet 2 (4v4 co-up 8v8) | 126 |
| Pockets50 | 126 |
| Sea of Gems V3 | 126 |
| Middle Road 2-6p | 126 |
| new money 4v4 no rush | 126 |
| Mega one Way & New Money 3vs3 | 126 |
| Kobe 24, Sirhc123 | 126 |

## MapGen recipe schema (B1)

JSON recipes (`GeneratedMaps/recipes/*.json`) and CLI flags share these fields:

| Field | CLI flag | Default | Notes |
|-------|----------|---------|-------|
| `terrainProfile` | `--terrain-profile` | `flat` | `flat` = clear fill (v1). `temperate-mixed` accepted in schema; non-flat terrain is **PR 10 (B2)**. |
| `spawnLayout` | `--spawn-layout` | `corners8` | See reference cells below. Unknown layouts are rejected at CLI/generator validation. |
| `players` | `--players` | `4` | Resolved waypoint count = `min(players, 8)`. |
| `mapSize` | `--size` | `64` | `octagonOpen` / `middleRoad` require **126**. |

Sidecar `.json` adds `TerrainProfile`, `SpawnLayout`, and `ResolvedWaypointCount` when generated via MapGen CLI.

### Spawn layouts (126×126, 8 waypoints)

All surveyed favorites use **126×126**, **`[Multi1]`–`[Multi8]`**, **8 player starts**. Reference **global cells** (128×128 grid, `cell = y×128 + x`):

| Layout | Source map | Waypoint cells (P0…P7) |
|--------|------------|--------------------------|
| **corners8** | Procedural (`AIGen_8p_01`, 64×64 @ 32,32) | `4902, 4953, 11430, 11481, 4928, 11456, 8230, 8281` — four corners + four edge midpoints on playable rect |
| **octagonOpen** | Octagon (Open) V1.4 (`UGC_…M6FGG1`, `UGC_…E7RMN3`) | `1967, 6031, 10255, 14383, 14416, 10352, 6128, 2000` |
| **middleRoad** | Middle Road 2-6p (`UGC_…9E894C45`) | `5289, 5334, 12174, 12192, 12224, 5311, 12255, 12273` |

**No-shortage lineage** (beta/theta; same 8p scale, distinct from Octagon Open):  
`2321, 2367, 2413, 8083, 8172, 13842, 13887, 13933` — catalog cross-reference for PR 11 (B3) spawn tuning.

B1 places **reference cells** for `octagonOpen` / `middleRoad` as placeholders; B3 refines layout fidelity and defaults for 126×8.

## AI-generated 8-player maps (B4 integration)

Script: `Scripts/Generate-RAMap.ps1` — **defaults `-Players 8`, `-MapSize 126`, `-Recipe octagon8`**.  
Batch: `Scripts/Generate-RAMap8p-Batch.ps1` (64×64 set).  
Sync: `Scripts/Sync-LocalMap.ps1` — verifies **`.mpr` + `.tga` + `.json`** triplet before copy.

### Recipe aliases (`-Recipe`)

| Alias | CLI `--spawn-layout` | Reference |
|-------|----------------------|-----------|
| **octagon8** | `octagonOpen` | Octagon (Open) V1.4 cells |
| **middle-road** | `middleRoad` | Middle Road 2-6p cells |
| **corners8** | `corners8` | Procedural corner + edge midpoints |

Example (126×8 Octagon-style):

```powershell
.\Scripts\Generate-RAMap.ps1 -Recipe octagon8 -Name AIGen_8p_Large02 -Seed 20260704 -Build
.\Scripts\Sync-LocalMap.ps1 -SourceDir ".\GeneratedMaps" -BaseName "AIGen_8p_Large02"
```

### Quality gate (B4)

Healthy generated maps: **`.mpr` ≥ 10 000 bytes**, **`.tga` ≥ 4096 bytes**, non-empty **`.json`** sidecar.  
Truncated **4096-byte `.mpr`** files cannot be repaired — rerun `Generate-RAMap.ps1`.

Generated set **`AIGen_8p_01` … `AIGen_8p_08`** (64×64) plus **`AIGen_8p_Large01`**, **`AIGen_8p_Large02`** (126×126 Octagon / No-shortage scale).

## Previews & ore (2026-07)

- Remastered needs **`.mpr` + `.tga` + `.json`** sidecars (same basename). Empty TGA/JSON = no minimap in browser.
- **Repair:** `Scripts\Repair-RAMapPreviews.ps1` (all maps in `Local_Custom_Maps\Red_Alert`).
- **Generate defaults:** ore **0.72**, gems **0.06**, **18** ore pockets (64–320 cells each), **10** gem pockets (`ResourcePlacement.cs`).
- Truncated **4096-byte `.mpr`** files cannot be repaired — rerun `Generate-RAMap8p-Batch.ps1` or `Generate-RAMap.ps1`.