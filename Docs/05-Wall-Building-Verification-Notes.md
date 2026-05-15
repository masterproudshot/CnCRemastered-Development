# 05 - Wall Building Verification Notes

**Project:** Project Aeloria  
**Phase:** Moderate Cleanup  
**Date:** May 2026

---

## Purpose

This document covers verification of the **Modern Wall Building** Quality of Life feature from Rampastring’s More QoL mod (originally from CFE Patch).

The goal is fast, chain-style wall building (similar to Tiberian Sun / Red Alert 2) while keeping balance through increased cost.

---

## Features Covered

- Chain wall building (click and drag to build long walls in one go)
- Increased wall cost to balance the speed (`MaxWallExtensionDistance`)
- Adjusted sell price to prevent money exploits (`WallSellPriceDivisor`)
- Works for Sandbags, Chain Link, Concrete, and Barbwire

---

## Key Settings (from [AeloriaWalls] section)

- `MaxWallExtensionDistance` — How far a single wall placement action can extend
- `WallSellPriceDivisor` — Makes selling chain-built walls less profitable
- Falls back to `[MoreQoL]` for compatibility

Note: These have been moved to the dedicated `[AeloriaWalls]` section as part of Project Aeloria's configuration cleanup.

---

## Test Cases

### TC-101: Basic Chain Wall Building

- Select a wall type (e.g. Concrete Wall).
- Click and drag across multiple cells.
- **Expected**: A continuous wall is built in one action.
- **Pass Criteria**: No need to click every single wall segment.

### TC-102: Wall Cost Increase

- Compare wall cost with and without the mod active.
- **Expected**: Walls are noticeably more expensive (usually 2x–3x vanilla) to offset the speed advantage.

### TC-103: Sell Price Adjustment

- Build a long wall chain.
- Sell the entire chain.
- **Expected**: You should **not** make profit from building and immediately selling walls.
- The `WallSellPriceDivisor` should make selling walls less profitable.

### TC-104: Different Wall Types

- Test Sandbags, Chain Link Fence, Concrete Wall, and Barbwire.
- **Expected**: All wall types support chain building.

### TC-105: Wall Building with Rally Points / Production

- Set a rally point on a War Factory near where you want walls.
- Produce an Engineer or a unit that can build walls.
- **Expected**: No conflicts between rally points and wall building.

### TC-106: Edge Cases

- Try building walls through cliffs, water, or buildings.
- Try very long wall chains (20+ segments).
- Build walls right next to existing structures.

**Expected**: Game prevents illegal placements. Long chains work but may have a maximum length.

---

## Known Interactions

- Interacts with the A* pathfinding improvements (units should navigate around walls better).
- Important for base defense in late-game skirmish.

---

## Recent Improvements (Project Aeloria Moderate Cleanup)

- Wall settings moved to dedicated `[AeloriaWalls]` INI section
- `Extend_Wall()` function received improved comments and slightly cleaner structure
- `MaxWallExtensionDistance` and `WallSellPriceDivisor` are now consistently loaded from the Aeloria section

## Sign-off Checklist

- [ ] Chain wall building works smoothly on all wall types
- [ ] Wall costs feel balanced (not too cheap, not punishing)
- [ ] Selling walls does not generate profit
- [ ] No pathfinding bugs around newly built walls
- [ ] `[AeloriaWalls]` section is being read correctly

---

**Last Updated:** May 2026
