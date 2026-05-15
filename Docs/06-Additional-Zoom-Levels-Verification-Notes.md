# 06 - Additional Zoom Levels Verification Notes

**Project:** Project Aeloria  
**Phase:** Moderate Cleanup  
**Date:** May 2026

---

## Purpose

This document covers verification of the **Additional Zoom Levels** feature, particularly the ability to zoom out significantly further than vanilla Red Alert Remastered.

This was one of your explicitly requested features from the beginning.

---

## Features Covered

- Extended zoom out levels (beyond vanilla maximum)
- Additional zoom steps for better map overview
- Usually implemented via `GameConstants_Mod.xml` → `CNCZoomFactors`

---

## Implementation Note

Most of this feature lives in the XML override file:

`GameConstants_Mod.xml` → `<CNCZoomFactors>`

This is **not** a DLL change in most cases — it’s a data override. However, some zoom behavior can be influenced by the DLL.

---

## Test Cases

### TC-101: Maximum Zoom Out

- Scroll the mouse wheel all the way out (or use zoom hotkeys).
- **Expected**: You can see a much larger portion of the map than in vanilla.
- **Pass Criteria**: At least 2–3 extra zoom levels beyond vanilla maximum.

### TC-102: Zoom Step Smoothness

- Zoom in and out repeatedly.
- **Expected**: The zoom steps feel even and useful (not too big jumps, not too many tiny ones).

### TC-103: Usability at Maximum Zoom Out

- Play at maximum zoom out.
- **Expected**:
  - You can still select units and buildings
  - Fog of war / shroud is still visible
  - Performance remains acceptable

### TC-104: Zoom + Rally Points

- Set rally points while zoomed far out.
- **Expected**: You can accurately click to set rally points even when zoomed out.

### TC-105: Zoom + Harvester Behavior

- Watch harvesters move while zoomed far out.
- **Expected**: No visual glitches or incorrect pathing display at high zoom levels.

### TC-106: Zoom During Combat

- Zoom out fully during a large battle.
- **Expected**: You can still issue commands and understand the battlefield.

---

## Recommended Maps for Testing

- Large maps (e.g. 120x120 or bigger)
- Maps with spread-out bases
- Maps with naval + land combat

---

## Sign-off Checklist

- [ ] Significantly more zoom out than vanilla is available
- [ ] Zoom levels feel well-spaced and usable
- [ ] No major visual or input bugs at extreme zoom levels
- [ ] Performance is still playable at max zoom out

---

**Last Updated:** May 2026

---

*Being able to see the whole battlefield is one of the biggest “modern” feels you can add to classic Red Alert.*
