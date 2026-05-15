# 03 - Harvester & Refinery System Verification Notes

**Project:** Project Aeloria  
**Phase:** Moderate Cleanup (Stable Profile)  
**Date:** May 2026  
**Status:** Initial Test Plan

---

## Purpose

This document contains structured test cases and verification notes for the harvester refinery selection and queue jumping improvements made during the Moderate cleanup phase.

Because CnC Remastered does not have a traditional unit testing framework, we rely on **manual but systematic skirmish testing** using our fast launchers.

---

## Changes Made (What Needs Verification)

### 1. New Helper: `FindBestRefinery(bool friendly = false)`

- Centralized smart refinery selection logic.
- Uses `LastDockingBayCoord` preference + `MaxFreeRefineryDistanceBias`.
- Supports the `friendly` parameter for `Mission_Repair` path.

### 2. New Helper: `HarvesterCanQueueJump()`

- Extracted queue jumping decision from refinery `RADIO_HELLO` handler.
- Uses `MinHarvesterQueueJumpDistance`.

### 3. Damaged Harvester Path Updated

- When a harvester is at yellow health and carrying ore, it now uses `FindBestRefinery()` instead of raw `Find_Docking_Bay()`.

### 4. `Mission_Repair` Path Updated

- Harvesters in repair mode now also benefit from smart refinery selection via `FindBestRefinery(true)`.

### 5. General Unification

- Most "harvester needs to go home" decisions now flow through the smart helper.

---

## Recommended Test Setup

### Tools
- Use `Launch-Aeloria-Experimental.bat` for testing new changes.
- Use `Launch-Aeloria-Stable.bat` for baseline comparison.
- Use `Launch-Vanilla-Plus.bat` if you want to compare against minimal changes.

### Recommended Skirmish Maps
- Small maps with 2–4 refineries (easy to observe behavior).
- Maps with separated ore fields.
- Maps with choke points between ore and refineries.
- Maps with multiple players (to test queue jumping under pressure).

**Good test maps ideas:**
- Any 1v1 or 2v2 map with spread-out Tiberium.
- Custom small test maps with 3 refineries and ore in different directions.

---

## Test Cases

### Test Group 1: Basic Smart Refinery Selection (FindBestRefinery)

**TC-101: Normal Harvesting - LastDockingBayCoord Preference**

- **Setup**: Build 2 refineries. Send harvester to one, let it unload, then force it to harvest from a distant field.
- **Expected**: After unloading, the harvester should strongly prefer returning to the refinery it last used (`LastDockingBayCoord`), even if another refinery is slightly closer on paper.
- **Pass Criteria**: Harvester consistently returns to its "home" refinery.

**TC-102: Free vs Occupied Refinery Bias**

- **Setup**: Two refineries close to each other. Send 3–4 harvesters to the same ore field.
- **Expected**: Harvesters should prefer a free refinery over an occupied one, even if the occupied one is a bit closer (within `MaxFreeRefineryDistanceBias`).
- **Pass Criteria**: Reduced traffic jams at a single refinery.

---

### Test Group 2: Queue Jumping

**TC-201: Basic Queue Jump**

- **Setup**: One harvester is docking at a refinery. Send a second harvester from much closer.
- **Expected**: If the new harvester is significantly closer (by `MinHarvesterQueueJumpDistance`), it should bump the current harvester (`RADIO_OVER_OUT`).
- **Pass Criteria**: Closer harvester successfully takes priority.

**TC-202: Queue Jump Threshold**

- **Setup**: Test with different values of `MinHarvesterQueueJumpDistance` (via rules or future INI).
- **Expected**: Only jump when the distance difference is meaningful.

**TC-203: No False Queue Jumps**

- **Setup**: Two harvesters at similar distances.
- **Expected**: No bumping occurs.

---

### Test Group 3: Damaged Harvester Behavior (New Path)

**TC-301: Damaged Harvester with Ore**

- **Setup**: Damage a harvester to yellow health while it has a full load of ore.
- **Expected**: It should use smart refinery selection (`FindBestRefinery()`) instead of dumb closest refinery.
- **Pass Criteria**: Prefers last used refinery + applies free refinery bias.

**TC-302: Damaged Harvester + Rally Point**

- **Setup**: Set a rally point on a refinery. Damage a harvester carrying ore.
- **Expected**: After unloading, it should respect the rally point + `InitHarvest` flag.

---

### Test Group 4: Repair Mode Harvesters

**TC-401: Repair Mode Uses Smart Selection**

- **Setup**: Send a damaged harvester into `Mission_Repair` while it has ore.
- **Expected**: It should prefer its last docking bay refinery when looking for a place to go (via `FindBestRefinery(true)`).

**TC-402: Repair Mode Queue Jumping**

- **Setup**: Multiple damaged harvesters trying to repair/unload.
- **Expected**: Queue jumping logic still applies correctly.

---

### Test Group 5: Regression / Edge Cases

**TC-501: No Refineries**

- Harvester should go idle (existing behavior must be preserved).

**TC-502: Only One Refinery**

- All logic should gracefully fall back to the single refinery.

**TC-503: Refinery Destroyed While Harvester Heading Home**

- Harvester should re-evaluate and find a new best refinery.

**TC-504: Captured Refinery**

- Behavior should remain sane when a refinery changes ownership.

**TC-505: Multiple Players / Skirmish AI**

- AI harvesters should not be negatively affected by player changes.

**TC-506: Rally Point + Harvester Interaction**

- Setting a rally point on a refinery should still trigger `InitHarvest = true` after unloading.

---

## Testing Procedure

1. Build the DLL in **Release Win32**.
2. Copy `RedAlert.dll` into:
   - `Development/Mods/Red_Alert/Aeloria-Experimental/Data/`
3. Launch using `Launch-Aeloria-Experimental.bat`
4. Start skirmish with desired map and settings.
5. Use the in-game speed controls + pause to observe harvester behavior.
6. Take notes on failures or unexpected behavior.

---

## Known Risks / Things to Watch

- The `ScenarioInit++` trick inside `FindBestRefinery()` is still present (necessary for now). Make sure it doesn't cause side effects in edge cases.
- `LastDockingBayCoord` is now used in more code paths — verify it doesn't cause harvesters to get stuck going to a destroyed refinery.
- Queue jumping must not cause harvesters to oscillate between two refineries.

---

## Future Improvements (Experimental Track)

These are noted here but **not** part of the Moderate cleanup:

- Full extraction of a `FindBestUnloadLocation()` that can decide between refinery vs repair bay intelligently.
- Visual feedback (e.g. harvesters showing which refinery they are assigned to).
- Persistent "home refinery" concept stronger than current `LastDockingBayCoord`.
- Configurable bias values per player or difficulty.

---

## Sign-off Checklist

- [ ] TC-101 to TC-506 all pass on Experimental
- [ ] No regressions compared to previous Rampastring behavior
- [ ] Behavior matches between Experimental and Stable after promotion
- [ ] Notes added for any remaining quirks

---

**Document Owner:** Jackson  
**Last Updated:** May 2026

---

*“If it’s not tested, it’s not shipped.”* — Project Aeloria testing philosophy
