# 09 - Project Aeloria Configuration Guide

**Project:** Project Aeloria  
**Phase:** Moderate Cleanup (Stable)  
**Date:** May 2026

---

## Overview

Project Aeloria uses a clean, dedicated configuration system under sections prefixed with `[Aeloria...]`.

This replaces the scattered use of the original `[MoreQoL]` section from Rampastring’s mod. The goal is:

- Better organization
- Clear ownership of settings
- Easier maintenance and future expansion (especially on the Experimental branch)

---

## Configuration Sections

### `[AeloriaHarvesters]`

Controls smart harvester behavior.

**Current Settings:**
- `MaxFreeRefineryDistanceBias`
- `MinHarvesterQueueJumpDistance`
- `AIHarvesterMemoryValue` (if present in your rules)

**Recommended Values (Stable):**
- Use the values you liked from the original MoreQoL / AI Boost mods.
- These are the most impactful settings for daily play.

---

### `[AeloriaRallyPoints]`

Controls rally point functionality.

**Current Settings:**
- `RallyPointsEnabled` (0 = off, 1 = on)

**Future Potential Settings:**
- Rally point visual style
- Whether rally points persist after capture/sale

---

### `[AeloriaWalls]`

Controls modern chain wall building.

**Current Settings:**
- `MaxWallExtensionDistance`
- `WallSellPriceDivisor`

**Notes:**
- Higher `MaxWallExtensionDistance` = faster base walling.
- `WallSellPriceDivisor` prevents easy money exploits when selling walls.

---

### `[AeloriaQMove]`

Controls Q-Move (queued movement) behavior.

**Current Settings:**
- `QmoveLoopsAllowed`
- `AirQMoveAllowed`
- `AirQRecallAllowed`

**Notes:**
- These were carried over from the original MoreQoL mod.
- `AirQMoveAllowed` is especially useful for helicopter micro.

---

### `[AeloriaEngineers]`

Controls engineer behavior.

**Current Settings:**
- `EngineerInstantCapture`
  - `0` = Disabled (vanilla)
  - `1` = Enabled in Multiplayer only
  - `2` = Enabled in Singleplayer & Multiplayer

**Recommendation:**
- Many players prefer `1` (MP only) for balance reasons.
- Use `2` if you want the full modern experience in skirmish.

---

### `[AeloriaZoom]`

Controls camera zoom behavior.

**Current Settings:**
- `MaxZoomLevel`
- `ZoomSpeed` (future use)

**Notes:**
- Most zoom control still comes from `GameConstants_Mod.xml` (`<CNCZoomFactors>`).
- This section exists for future tunables and consistency.

---

## Recommended Approach for Stable

For the **Aeloria-Stable** profile, we recommend:

1. Create a file called `Aeloria.ini` (or put everything in your main `rules.ini`).
2. Use the `[Aeloria*]` sections exclusively.
3. Only fall back to `[MoreQoL]` temporarily while transitioning old mods.

Example structure:

```ini
[AeloriaHarvesters]
MaxFreeRefineryDistanceBias=20
MinHarvesterQueueJumpDistance=7

[AeloriaRallyPoints]
RallyPointsEnabled=1

[AeloriaWalls]
MaxWallExtensionDistance=10
WallSellPriceDivisor=3

[AeloriaQMove]
QmoveLoopsAllowed=1
AirQMoveAllowed=1
AirQRecallAllowed=1

[AeloriaEngineers]
EngineerInstantCapture=1

[AeloriaZoom]
MaxZoomLevel=35
```

---

## Transition from [MoreQoL]

During the Moderate phase, all Aeloria sections fall back to `[MoreQoL]` if the setting is not found. This allows old mods to continue working while you migrate.

**Long-term recommendation:** Move everything to the `[Aeloria...]` sections for cleanliness.

---

## Future Sections (Experimental)

These may appear in the Experimental branch:

- `[AeloriaHarvestersAdvanced]`
- `[AeloriaPathfinding]`
- `[AeloriaUI]`
- `[AeloriaBalance]`

---

## Philosophy

Project Aeloria’s configuration system follows these principles:

- One clear section per major feature area
- Settings should have good default values for the "ideal modernized" experience
- Everything should be toggleable and well-documented
- The Stable version stays conservative and polished
- The Experimental version is where we go crazy

---

**Document Owner:** Jackson  
**Last Updated:** May 2026

---

*Configuration should feel intentional, not accidental.* — Project Aeloria
