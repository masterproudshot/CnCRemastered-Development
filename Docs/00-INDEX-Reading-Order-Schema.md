# Project Aeloria — Documentation Reading Order & Filename Schema (v1)

**Goal:** Filenames + a single INDEX should let anyone reconstruct project history and priority at a glance.

## Recommended Filename Schema

`NN-Short-Descriptive-Name.md`

- `NN` = historical introduction order (two digits).
- Use blocks so related work stays together.
- Never reuse numbers.

### Block Allocation (current proposal)

- **00-09**: Vision, Getting Started, Philosophy
- **10-19**: Process, Releases, Configuration, Checklists
- **20-29**: Core QoL Features (Harvesters, Rally, Zoom, Walls, Movement, Capture, etc.)
- **30-59**: Aeloria — Visibility, Stability, LAYERS, and related engineering (the long multi-year arc)
- **60-69**: MapGen, Procedural Maps, Custom Content
- **70+**: Future work, VFX, one-offs, Archives

**Example desired names after cleanup:**
- 00-Project-Vision.md (keep)
- 01-Getting-Started-Building.md (keep)
- 20-Harvester-Rally-System-Modernization.md
- 21-Harvester-Refinery-Verification-Notes.md
- 30-AELORIA-PROJECT-HANDOFF.md
- 31-AELORIA-NORTHSTAR-UNIFIED-PLAN.md
- 32-AELORIA-STATUS-WAVES.md
- 33-AELORIA-COMPACT-HANDOFF.md
- 34-AELORIA-COMPACT-20260627.md
- 35-AELORIA-NEXT-ROUNDS.md
- 36-AELORIA-PHASE-E-COMPACT.md
- 37-AELORIA-PHASE-E22-PLAN.md
- 38-AELORIA-PHASE-E2-VFX-PLAN.md
- 39-AELORIA-PLAN-E245-NORTHSTAR-PATH.md
- 40-AELORIA-PLAN-E259-REGIONAL-VISIBILITY.md
- 41-AELORIA-PLAN-E262-SOUTH-REMAINDER.md
- 42-AELORIA-PLAN-E265-UNIFORM-CAP.md
- 43-AELORIA-RCA-SKIRMISH-CRASH-20260702.md
- 44-AELORIA-REVIEW-E261-E259b-QE.md
- 45-AELORIA-CRASH-TRACE-20260703-PLAN-BRIEF.md
- 60-CUSTOM-MAPS-CATALOG.md

## Current Reading Order (as of this schema introduction)

1. README.md + QUICKSTART.txt (orientation)
2. 00-Project-Vision.md (the "why" and what we refuse to do)
3. 01-Getting-Started-Building.md (how to build/test)
4. 20-series (Core QoL ambitions outside the visibility war)
5. 30-series Aeloria docs (33-45 range) in roughly the order the E.2. waves and phases were introduced
6. 35-AELORIA-NEXT-ROUNDS.md + 30-AELORIA-PROJECT-HANDOFF.md (where we stand)
7. 60-series for MapGen work
8. archive/ for historical one-off agent reports

## Action Taken

- This INDEX created as the canonical schema document.
- Key Aeloria handoff and north-star docs updated with corrected language (no hard 20-30 min duration caps; eternal scaling on modern hardware is the intent).
- Full renumbering of remaining files can be done with `git mv` in a follow-up pass (to avoid breaking many cross-references at once).

**Rule going forward:** When a new major area of work begins, allocate the next block of NN numbers and document it here.

This gives the project a clean, history-following document namespace.