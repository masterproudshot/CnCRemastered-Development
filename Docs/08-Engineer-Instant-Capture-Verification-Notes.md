# 08 - Engineer Instant Capture Verification Notes

**Project:** Project Aeloria  
**Phase:** Moderate Cleanup  
**Date:** May 2026

---

## Purpose

This document covers **Engineer Instant Capture**, a very popular and well-known mod feature in the Red Alert Remastered community.

This feature allows a single Engineer to instantly capture enemy buildings without needing to damage them first (unlike vanilla behavior).

---

## Background

In vanilla Red Alert:
- Engineers must damage a building before they can capture it.
- Multiple engineers are often needed for high-health structures.

With **Engineer Instant Capture** enabled:
- One Engineer can capture any capturable building instantly.
- This dramatically changes the pace of the game and makes Engineers much more threatening (especially in mid/late game).

This was featured in many popular mods, including various AI Boost packs and CFE-based mods.

---

## Key Setting

From the INI (commonly found in `aiboost.ini` or rules overrides):

```ini
EngineerInstantCapture=1   ; or 2 for SP+MP
```

- `0` = Disabled (vanilla)
- `1` = Enabled in Multiplayer only
- `2` = Enabled in both Singleplayer and Multiplayer

---

## Test Cases

### TC-101: Basic Instant Capture

- Send one Engineer to an enemy building (Power Plant, War Factory, etc.).
- **Expected**: The building is captured instantly upon the Engineer reaching it.

### TC-102: High Health Buildings

- Try capturing a full-health Construction Yard or high-health structure.
- **Expected**: Still captured with a single Engineer (no damage required).

### TC-103: Multiple Engineers

- Send 3 Engineers to the same building at once.
- **Expected**: Only one Engineer is consumed. The others should not disappear or behave strangely.

### TC-104: Capturing Different Building Types

Test capturing:
- Power Plants
- War Factories / Barracks
- Refineries
- Repair Bays
- Superweapons (Iron Curtain, Chronosphere, Nuclear Silo)
- Construction Yards (very high value target)

**Expected**: All should be instantly capturable.

### TC-105: Naval Buildings

- Capture a Shipyard or Sub Pen with an Engineer (if possible via transport or proximity).
- **Expected**: Works as expected.

### TC-106: Defensive Buildings

- Try capturing Pillboxes, Turrets, Tesla Coils, etc.
- **Expected**: These are usually **not** capturable even with instant capture (confirm behavior).

---

## Balance & Strategic Implications

Because this is a significant gameplay change, it should be tested with awareness of its power level:

- Makes sneak attacks and Engineer rushes much stronger.
- Changes how you defend your base (more emphasis on walls and anti-infantry).
- Makes late-game Engineer drops extremely powerful.

---

## Interaction with Other Aeloria Features

- **Rally Points**: Can you set a rally point on a building you plan to capture with Engineers?
- **Q-Move**: Can you queue an Engineer to capture multiple buildings in sequence?
- **Harvester Logic**: No direct interaction, but base disruption from instant captures will affect harvester safety.

---

## Sign-off Checklist

- [ ] Single Engineer instantly captures all normal buildings
- [ ] No bugs with multiple Engineers arriving at once
- [ ] Construction Yards and Superweapons are capturable
- [ ] Defensive structures behave as expected (usually not capturable)
- [ ] Feature feels powerful but not completely broken when balanced properly

---

## Recommendation for Project Aeloria

Engineer Instant Capture is a **high-impact** feature. If we include it, we should consider:

- Making it **optional** via INI (strongly recommended)
- Possibly adding a small delay or visual warning
- Clear documentation for players

---

**Last Updated:** May 2026
