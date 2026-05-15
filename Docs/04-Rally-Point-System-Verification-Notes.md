# 04 - Rally Point System Verification Notes

**Project:** Project Aeloria  
**Phase:** Moderate Cleanup  
**Date:** May 2026

---

## Purpose

This document provides test cases and verification guidance for the **Rally Point** Quality of Life system originally introduced by Rampastring (based on cfehunter’s CFE Patch work), which we have been extending and cleaning up as part of Project Aeloria.

Rally points are one of the most loved features from the original "More QoL" mod, so preserving and verifying their behavior is critical.

---

## Features Covered

- Rally points on production buildings (Barracks/Tent, War Factory, Shipyard/Sub Pen, Helipad, Airfield)
- Rally points on Repair Bays
- Visual feedback (green line from exit to rally point)
- Automatic sending of newly produced / repaired units to the rally point
- Special harvester interaction (`InitHarvest = true` when unloading at a refinery with a rally point)
- Setting rally points by clicking the ground or a unit

---

## Key Code Areas (For Reference During Testing)

- `BuildingClass::Can_Have_Rally_Point()`
- `BuildingClass::Target_For_Rally_Point()`
- `BuildingClass::RallyPoint` member
- Logic in `Receive_Message(RADIO_UNLOADED)`
- Logic in `Active_Click_With` and `What_Action`
- Harvester-specific handling in `UNIT.CPP` (the `InitHarvest` flag we touched during harvester cleanup)

---

## Recommended Test Setup

- Use `Launch-Aeloria-Experimental.bat` for testing changes.
- Use `Launch-Aeloria-Stable.bat` to compare against the previous version.
- Small skirmish maps with multiple production buildings are ideal.

---

## Test Cases

### Test Group 1: Basic Rally Point Functionality

**TC-101: Production Building Rally Point (Land Units)**

- **Setup**: Select a War Factory → Right-click on the ground to set a rally point.
- **Expected**: Newly produced tanks drive to the rally point instead of idling at the exit.
- **Pass Criteria**: Units consistently move to the marked location.

**TC-102: Production Building Rally Point (Infantry)**

- **Setup**: Set a rally point from a Barracks/Tent.
- **Expected**: Infantry walk to the rally point.

**TC-103: Naval Rally Point**

- **Setup**: Set a rally point from a Shipyard or Sub Pen.
- **Expected**: Ships move to the rally point on water.

**TC-104: Air Rally Point**

- **Setup**: Set a rally point from a Helipad or Airfield.
- **Expected**: Aircraft move to the rally point after being built.

---

### Test Group 2: Repair Bay Rally Points

**TC-201: Repair Bay Rally Point**

- **Setup**: Set a rally point on a Repair Bay.
- **Expected**: Units that finish repairing drive away to the rally point instead of sitting on the pad.
- **Pass Criteria**: Repair pad becomes free faster, units move to rally point.

**TC-202: Repair Bay + Harvester**

- **Setup**: Set a rally point on a Repair Bay. Send a damaged harvester to repair.
- **Expected**: Harvester repairs then moves to the rally point.

---

### Test Group 3: Harvester + Refinery Rally Point Interaction (Critical)

This group is especially important because we modified harvester logic in the Moderate cleanup.

**TC-301: Refinery Rally Point Triggers InitHarvest**

- **Setup**: Set a rally point on a Refinery. Send a harvester to unload.
- **Expected**: After unloading, the harvester should be given a move order to the rally point, and `InitHarvest` should be set to `true`.
- **Pass Criteria**: Harvester moves to the rally point and then immediately starts looking for a new Tiberium field (instead of idling).

**TC-302: Refinery Rally Point + Smart Refinery Selection**

- **Setup**: Multiple refineries. Set a rally point on one of them. Have several harvesters unloading.
- **Expected**: Harvesters that unload at the rally-point refinery should respect both the rally point **and** our smart `FindBestRefinery()` logic on subsequent trips.

**TC-303: Destroyed Refinery with Rally Point**

- **Setup**: Set a rally point on a Refinery, then destroy it while harvesters are heading there.
- **Expected**: Harvesters should re-evaluate and find a new refinery (no getting stuck).

---

### Test Group 4: Visual Feedback

**TC-401: Rally Point Line Drawing**

- **Setup**: Select a building that has a rally point set.
- **Expected**: A green line is drawn from the building’s exit point to the rally point location.
- **Pass Criteria**: Line appears only when the building is selected by the player who owns it.

**TC-402: Rally Point Line Updates**

- **Setup**: Change the rally point while the building is selected.
- **Expected**: The line updates in real time.

---

### Test Group 5: Setting Rally Points

**TC-501: Set Rally Point on Ground**

- **Setup**: Select production building → Right-click on ground.
- **Expected**: Rally point is set to that cell.

**TC-502: Set Rally Point on Unit**

- **Setup**: Select production building → Hold ALT and right-click on a friendly unit.
- **Expected**: Produced units will move toward that unit’s current position (dynamic rally).

**TC-503: Rally Point on Enemy Unit (Should be blocked or handled gracefully)**

- **Expected**: Game should not allow setting rally points on enemy units in unintended ways.

---

### Test Group 6: Edge Cases & Regression

**TC-601: No Rally Point Set (Default Behavior)**

- **Expected**: Units behave exactly as in vanilla / original Rampastring mod (exit and stop or guard).

**TC-602: Building Sold / Destroyed While Units Are Moving to Rally Point**

- **Expected**: Units should not crash or get stuck. They should enter normal idle/guard behavior.

**TC-603: Multiple Buildings with Rally Points**

- **Setup**: Set rally points on War Factory, Barracks, and Repair Bay at the same time.
- **Expected**: Each building correctly sends its own units to their respective rally points.

**TC-604: Captured Building with Rally Point**

- **Setup**: Capture an enemy building that had a rally point set.
- **Expected**: The rally point should either be cleared or behave reasonably for the new owner.

**TC-605: Rally Points in Multiplayer**

- **Expected**: Rally points are local to each player (no desync or ownership issues).

---

## Known Interactions with Harvester Work

Because we made changes to `FindBestRefinery()` and the harvester state machine, these tests are particularly important:

- TC-301 and TC-302 (Harvester + Refinery Rally Point)
- Any test involving damaged harvesters going to repair then unloading

---

## Testing Procedure

1. Launch with `Launch-Aeloria-Experimental.bat`
2. Build several production buildings + at least one Repair Bay and Refinery.
3. Set rally points on different building types.
4. Produce units and observe their movement.
5. Specifically test harvesters with and without refinery rally points.
6. Compare behavior against `Aeloria-Stable` and `Vanilla-Plus` launchers when needed.

---

## Sign-off Checklist

- [ ] All TC-101 to TC-605 pass on Experimental
- [ ] Harvester + Refinery rally point interaction works as expected after our harvester changes
- [ ] No visual or functional regression compared to original Rampastring "More QoL"
- [ ] Behavior is consistent when promoting to Stable profile

---

**Document Owner:** Jackson  
**Last Updated:** May 2026

---

*Good rally points make base building feel modern. Bad ones make it feel broken.* — Project Aeloria
