# Custom Red Alert Maps — Local Iteration (No Workshop)

Play custom skirmish maps from disk without Steam publish/subscribe.

## Output location

The remaster client and map editor use:

`%UserProfile%\Documents\CnCRemastered\Local_Custom_Maps\Red_Alert\`

Workshop subscriptions extract here as `UGC_*_MAPDATA.mpr`. Locally authored maps use the **same folder** with any base name.

## File triplet

| File | Purpose |
|------|---------|
| `YourMap.mpr` | Scenario INI + compressed `MapPack` / `OverlayPack` |
| `YourMap.tga` | Preview thumbnail in the map list |
| `YourMap.json` | Bounds, theater, player-start cells for the UI |

Keep the **same base name** for all three.

## DLL load rule

`CNC_Start_Custom_Instance` loads:

`{directory_path}{scenario_name}.mpr`

Example: directory `...\Red_Alert\` and scenario `AIGen_Test` → `...\Red_Alert\AIGen_Test.mpr`.

## Skirmish checklist

- `Basic`: **not** solo (`SoloMission` = false / `0`).
- **≥ 2** player start waypoints (`P0`–`P7`) with cells set.
- Theater matches tiles (Temperate / Snow for outdoor RA).
- Stay within editor limits (`CnCTDRAMapEditor/RedAlert/Constants.cs`).

## Rapid workflows

### A. Map editor (manual)

1. Run `CnCTDRAMapEditor` with **current directory** = Steam `CnCRemastered` (so `DATA\*.MEG` loads).
2. Save to `Local_Custom_Maps\Red_Alert\`.
3. Skirmish → Custom → pick the map.

### B. Generator CLI (automated, B4 defaults)

From repo (after building the map editor). **B4 defaults:** `-Players 8`, `-MapSize 126`, `-Recipe octagon8`.

```powershell
# 126×8 Octagon-style (reference cells from catalog)
.\Scripts\Generate-RAMap.ps1 -Recipe octagon8 -Name "AIGen_8p_Large02" -Seed 20260704 -Build

# Middle Road layout
.\Scripts\Generate-RAMap.ps1 -Recipe middle-road -Name "AIGen_MiddleRoad01" -Seed 99

# Legacy 4p 64×64
.\Scripts\Generate-RAMap.ps1 -Recipe corners8 -Name "AIGen_Test" -Seed 42 -Players 4 -Size 64
```

Recipe aliases: `octagon8` → `octagonOpen`, `middle-road` → `middleRoad`, `corners8` → procedural spawns.

Requires `-DataPath` to the game install if not default Steam path (`C:\Program Files (x86)\Steam\steamapps\common\CnCRemastered`).

**Quality gate:** `.mpr` ≥ 10 000 bytes, `.tga` ≥ 4096 bytes, matching `.json`. `Generate-RAMap.ps1` and `Sync-LocalMap.ps1` both enforce this.

### C. Sync from repo folder

```powershell
.\Scripts\Sync-LocalMap.ps1 -SourceDir ".\GeneratedMaps" -BaseName "AIGen_8p_Large02"
```

Verifies and copies the **triplet** (`.mpr`, `.tga`, `.json`) into `Local_Custom_Maps\Red_Alert\`.

## Workshop fallback

If a loose `.mpr` does not appear in the client list:

1. Export **MEG/PGM** from the editor (`MAPDATA.PGM`).
2. Place under `steamapps\workshop\content\1213210\<dev_folder>\` (local-only folder id).

## Ore / gem density (generator)

Runtime ore value scales with **adjacent ore cells** (`REDALERT/CELL.CPP`). The generator clusters ore to maximize yield; gems and `mine` terrain objects are placed separately.

## Related source

- `CnCTDRAMapEditor/RedAlert/GamePlugin.cs` — save/load
- `CnCTDRAMapEditor/MapGen/` — CLI generator
- Generative map strategy plan in session `plan.md`