# 02 - Harvester & Rally Point System Modernization

**Project:** Project Aeloria  
**Status:** Design Phase  
**Target Profile:** Aeloria-Stable (Moderate) + Aeloria-Experimental (Ambitious)  
**Date:** May 2026  
**Author:** Jackson + Grok

---

## 1. Executive Summary

This document outlines the plan to clean up, modernize, and improve the harvester intelligence and rally point systems originally introduced by Rampastring’s “More QoL Improvements” (with significant contributions from cfehunter / CFE Patch).

**Core Philosophy for Project Aeloria:**
- Make Red Alert Remastered feel significantly more pleasant and modern to play.
- Focus on **smart, intuitive logistics** (especially harvesters and production flow) rather than making the AI harder.
- Maintain excellent compatibility and predictability for players.

We will use a two-track approach:
- **Aeloria-Stable**: Moderate, careful modernization (current priority).
- **Aeloria-Experimental**: Ambitious new features and larger architectural improvements.

---

## 2. Current State Analysis

### 2.1 Rally Point System

**Key Files:**
- `REDALERT/BUILDING.H` (RallyPoint member)
- `REDALERT/BUILDING.CPP` (most logic)

**What Exists Today (Rampastring + CFE):**
- Rally points on production buildings (Barracks/Tent, War Factory, Shipyard/Sub Pen, Helipad, Airfield).
- Rally points on Repair Bays.
- Visual feedback (green line drawn from building exit to rally point when selected).
- When a unit finishes production or is repaired, it is sent to the rally point.
- Special harvester handling: when a harvester unloads at a refinery, `InitHarvest = true` is set so it immediately looks for more ore.

**Strengths:**
- Very popular and well-liked feature.
- Feels natural (similar to Red Alert 2 / Tiberian Sun).

**Weaknesses / Technical Debt:**
- Not properly networked for multiplayer (explicit TODO comment in code).
- `Can_Have_Rally_Point()` is implemented as a hardcoded switch statement.
- No concept of “harvest area” rally points on refineries.
- Rally point behavior when the target building is destroyed/captured is inconsistent.
- Logic is scattered across several methods (`Active_Click_With`, `Receive_Message`, `Unlimbo`, `ExitObject`, `Draw_It`, etc.).

### 2.2 Harvester Intelligence

**Key Files:**
- `REDALERT/UNIT.CPP` — primarily `Mission_Harvest()`
- `REDALERT/BUILDING.CPP` — refinery docking / queue jumping logic
- `REDALERT/RULES.CPP` + `RULES.H` — QoL tunables under `[MoreQoL]`

**Major QoL Features Added by Rampastring/CFE:**
- **ArchiveTarget memory**: Harvesters remember the last cell they harvested from.
- **Smarter refinery selection** using `MaxFreeRefineryDistanceBias`.
- **Queue jumping** at refineries using `MinHarvesterQueueJumpDistance`.
- `InitHarvest` flag (forces harvester to immediately search for ore after unloading).
- Improved behavior when a refinery is lost or when fields are depleted.

**Current Code Problems:**
- `Mission_Harvest()` is a large, old Westwood state machine (LOOKING / HARVESTING / FINDHOME / HEADINGHOME / GOINGTOIDLE) with 2020-era patches bolted on.
- Refinery finding logic is duplicated in multiple places and uses ugly `ScenarioInit++` tricks.
- Many important behaviors are poorly commented or use confusing variable names (`InitHarvest`, `IsUseless`, `ArchiveTarget`, `LastDockingBayCoord`).
- The interaction between refinery rally points and harvester “go harvest again” behavior is underdeveloped.
- Hard to extend or reason about without deep familiarity with the original code.

---

## 3. Goals

### 3.1 Moderate Goals (Aeloria-Stable)

These changes are allowed to land in the daily driver:

- Significantly improve code readability and maintainability.
- Add high-quality documentation explaining the *why* behind each QoL feature.
- Extract reusable helper methods.
- Clean up the harvester state machine without changing observable behavior.
- Make refinery selection and queue-jumping logic clearer and more centralized.
- Fix small inconsistencies (especially around destroyed refineries and rally points).
- Improve the interaction between refinery rally points and harvesters.
- Make existing tunables more effective and better documented.
- Prepare the codebase for future ambitious work.

**Non-goals for Moderate/Stable:**
- No large behavioral changes that would feel different to players familiar with Rampastring’s mod.
- No new major features.
- No risky architectural overhauls.

### 3.2 Ambitious Goals (Aeloria-Experimental)

These are explicitly deferred to the Experimental profile:

- True selectable harvest rally points (player can click a refinery then click an ore field to tell harvesters “go harvest here after unloading”).
- Multiple harvest zones per refinery.
- Priority / preferred refinery system.
- Better long-term memory and adaptive behavior.
- Possible deeper integration with production rally points.
- Significant performance or pathfinding improvements for harvesters.
- New configuration options and UI feedback.

---

## 4. Technical Approach (Moderate Phase)

### 4.1 Refactoring Strategy

We will follow these principles:

1. **Behavior Preservation First**
   - Every change must be tested against the current “Rampastring-like” behavior.
   - We will use `Aeloria-Stable` as the reference and only move to Experimental for experiments.

2. **Incremental, Reviewable Changes**
   - Small, focused commits.
   - Good commit messages that explain the *intent*.

3. **Documentation-Driven**
   - Every significant piece of logic should have a clear comment block explaining:
     - What it does
     - Why it exists (QoL motivation)
     - Any known limitations

4. **Helper Method Extraction**
   Target methods to create/extract:
   - `FindBestAvailableRefinery()`
   - `ShouldQueueJumpAtRefinery(...)`
   - `RememberLastHarvestLocation()`
   - `GetPreferredHarvestDestination()`
   - `HandleRallyPointAfterUnloading()`

5. **Rally Point Improvements (Moderate Scope)**
   - Make `Can_Have_Rally_Point()` cleaner (possibly move toward data-driven in the future).
   - Improve behavior when a rally point target becomes invalid.
   - Better integration between refinery rally points and the `InitHarvest` flow.

### 4.2 Files Expected to Be Modified

- `REDALERT/BUILDING.CPP`
- `REDALERT/BUILDING.H`
- `REDALERT/UNIT.CPP`
- `REDALERT/RULES.CPP`
- `REDALERT/RULES.H`
- Possibly minor changes in `HOUSE.CPP` or `FOOT.CPP`

New documentation will live in this design document and inline code comments.

---

## 5. Safety & Workflow

- All development happens in the **Development/** folder.
- We maintain three mod profiles:
  - `Aeloria-Stable` (daily driver — moderate changes only)
  - `Aeloria-Experimental` (playground)
  - `Vanilla-Plus` (baseline for comparison)
- Fast direct launchers (`Launch-*.bat`) will be used for rapid iteration.
- Every significant change should be tested in a skirmish before being considered stable.
- We will keep the ability to easily revert to pure Rampastring behavior if needed.

---

## 6. Proposed Work Breakdown (Moderate Phase)

### Phase 1: Documentation & Understanding (Current)
- [x] Analyze existing code
- [ ] Write this design document
- [ ] Add high-quality header comments to key functions

### Phase 2: Structural Cleanup
- Rename confusing variables where safe (`ArchiveTarget` → `LastHarvestCell`, etc.)
- Extract helper methods listed in section 4.1
- Clean up `Mission_Harvest()` state machine structure
- Centralize refinery selection logic

### Phase 3: Polish & Small Improvements
- Improve destroyed/captured refinery + rally point handling
- Strengthen refinery rally point → harvester “search again” interaction
- Improve documentation of all `[MoreQoL]` tunables
- Add comments explaining queue jumping logic

### Phase 4: Stabilization
- Extensive testing using fast launchers
- Move approved changes into `Aeloria-Stable`
- Update this document with final decisions

---

## 7. Open Questions & Future Ideas

### For Experimental (Ambitious)
- Should refinery rally points be able to specify a harvest *area* instead of just a cell?
- How should multiple harvesters coordinate when many refineries exist?
- Do we want a visual indicator showing which harvesters are assigned to which refinery?
- Should we allow “smart” auto-assignment of harvesters to the best refinery?

### Potential Long-term Ideas
- Harvester “home refinery” concept (more persistent than current behavior)
- Production buildings remembering multiple rally points (cycles)
- Integration with future base-building QoL features

---

## 8. Approval & Next Steps

**Current Status:** Awaiting final review of this document.

Once approved, the plan is:
1. Create a git branch for the moderate harvester/rally cleanup work.
2. Begin Phase 1 → Phase 2 work with small, reviewable commits.
3. Regularly test using the fast launchers in the Experimental profile first.
4. Promote stable improvements to the Stable profile.

---

**Document Version:** 1.0  
**Next Review:** After initial code cleanup begins

---

*“Make the logistics feel invisible and delightful.”* — Project Aeloria guiding principle
