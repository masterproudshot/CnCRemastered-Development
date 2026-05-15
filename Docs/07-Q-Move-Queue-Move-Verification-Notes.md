# 07 - Q-Move (Queue Move) Verification Notes

**Project:** Project Aeloria  
**Phase:** Moderate Cleanup  
**Date:** May 2026

---

## Purpose

This document covers verification of the **Q-Move / Queue Move** feature from Rampastring’s More QoL mod.

Q-Move allows you to queue multiple movement orders for units (similar to modern RTS games), making micro and long-distance travel much more convenient.

---

## Features Covered

- Basic Q-Move (queue movement waypoints)
- Air unit Q-Move support
- Q-Move loops (optional)
- Works on land, naval, and air units

---

## Key INI Settings

From `[MoreQoL]` section:
- `QmoveLoopsAllowed`
- `AirQMoveAllowed`
- `AirQRecallAllowed`

---

## Test Cases

### TC-101: Basic Q-Move on Ground Units

- Select a group of tanks.
- Hold **Q** and issue multiple move orders across the map.
- **Expected**: Units follow the entire path you queued.

### TC-102: Q-Move with Attack-Move

- Queue a combination of Move and Attack-Move orders.
- **Expected**: Units respect the different command types in sequence.

### TC-103: Q-Move on Harvesters

- Queue multiple harvest locations for a harvester.
- **Expected**: Harvester follows the queued path and harvests at each location (if ore is still there).

### TC-104: Air Unit Q-Move

- Select planes or helicopters.
- Queue multiple move orders.
- **Expected**: Aircraft follow the waypoints correctly.
- **Pass Criteria**: `AirQMoveAllowed` is functioning.

### TC-105: Q-Move Loop

- Enable `QmoveLoopsAllowed`.
- Queue a path that ends back near the starting point.
- **Expected**: Units can be made to patrol in a loop.

### TC-106: Canceling Q-Move

- Queue several orders, then issue a normal move or stop command.
- **Expected**: The queue is cleared and the new order takes precedence.

### TC-107: Q-Move + Rally Points

- Set a rally point on a War Factory.
- Queue additional orders on the produced units.
- **Expected**: Units go to the rally point first, then continue with any queued orders.

---

## Edge Cases

- Queueing orders while units are already moving
- Mixing Q-Move with Force-Fire or Force-Move
- Large groups of mixed unit types (tanks + infantry + air)
- Units being attacked while executing a long Q-Move path

---

## Sign-off Checklist

- [ ] Q-Move works reliably on ground, naval, and air units
- [ ] Air Q-Move is enabled and functional
- [ ] Queue loops work if enabled
- [ ] No units getting stuck or ignoring orders when using Q-Move
- [ ] Good synergy with Rally Points and Harvester logic

---

**Last Updated:** May 2026
