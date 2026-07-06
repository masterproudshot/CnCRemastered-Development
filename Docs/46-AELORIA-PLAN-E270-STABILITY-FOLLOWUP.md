# AELORIA-PLAN-E270-STABILITY-FOLLOWUP

**Date:** 2026-07-05  
**Branch:** experimental @ be13539 (post aeloria-stability-67487 tag)  
**Context:** ~67k frame 4p Experimental soak (win, no crash). MiGs 85% visible (spotty late flying), south ~10% bottom only at end, flame VFX 0, heavy late cap pressure (35k NEAR_CAP / 15k CAP_DROP).

## North Star Reminder
4p+ Experimental skirmish: units **visible / selectable / orderable indefinitely**, no WER, no artificial time limits, 512 cap unchanged, full-zoom mods OK. "Decades of headroom" via light export.

## Current State (Post E.2.70 Stability Milestone)
**Successes (from soak + fixes):**
- Duration/stability: Long playable session + win (big step from 45min crashes).
- Aircraft (MiGs) flight: 85% visibility (force block for !IsDown + priority heap query).
- South/bottom map: Major improvement — only late ~10% (priority query over cell-order bias + index clear).
- Core mechanics: WorldIndex (spatial + priority + dirty), candidate selection (~600), early skips, index clear per export, targeted forces (air/flame turret), uniform cap.

**Gaps (late-game cap churn still dominant):**
- MiGs: Spotty at end when flying (near 512, stale/unsafe objects, drops).
- Flame tower animations: None seen (turret force + log added; jet effect not exported).
- Map coverage: Still degrades at extreme end.
- Perf/logs: Mild late slowdown; 671MB log from guard/skip spam; EXPORT_METRIC not reliably surfaced.
- Overall: "Mostly works until very late" — not yet "indefinite / lightning fast forever".

**Key Data:**
- Max frame ~67k.
- 35k+ NEAR_CAP, 15k+ CAP_DROP.
- No FLAME_TURRET_FIRING_EXPORT hits in tail.
- Late aircraft draws present but guarded.

## Next Priorities (Ranked by Impact on North Star)
1. **Flame VFX / jet export** (highest user-visible gap).
2. **Aircraft late-game robustness** (MiGs spotty at end).
3. **Spatial / south coverage under pressure** (ensure full map even at cap).
4. **Guard / spam cost reduction + reliable metrics** (perf + debuggability at scale).

Cross-cutting: Better late-game object health in index, more aggressive/accurate sustain, view-aware culling.

## Detailed Implementation Plan

### Milestone M2.71: Flame Jet Export (1-2 soaks)
**Goal:** Flame towers produce visible attack animations (jet/stream) when firing, without regressing other visibility.

**Files to Change:**
- `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp` (main Get_Layer_State / Force / Draw paths + new helper).
- `Source/Rampastring-MoreQoL/REDALERT/ANIM.CPP` (extend Phase E.2 logic for flame tower jets; force render_virtual or export for relevant types).
- Possibly `REDALERT/ANIM.H` or BDATA for flame anim types (ANIM_FLAME_* family from ADATA).

**Steps:**
1. Identify exact anim types used by STRUCT_FLAME_TURRET firing (search ADATA.CPP / weapon logic for flame jet; common: FLAME-N/NE etc or dedicated stream).
2. In `Aeloria_ForceLayerExport` / per-object processing: special case for flame turret when firing → force export of associated flame anim if present (or synthesize a virtual flame object entry with correct asset/pos/owner).
3. In `ANIM.CPP` Draw: extend the WINDOW_VIRTUAL / !IsInvisible switch (current FBALL special case) to include flame tower jet types:
   - Set render_legacy + render_virtual appropriately so LAYERS (VIRTUAL) captures the jet as ephemeral or main object.
   - Add logging: `FLAME_JET_EXPORT this=... frame=...`
4. In Get_Layer_State: after layer walk + air force, add a pass or hook to walk active flame-related Anims (if not already in layers) and call export logic.
5. Update `Aeloria_LayersSlotRetainPriorityV2` or prio calc to boost active flame effects.
6. Test: Maps with flame towers + long fights. Verify jet visible in flight + on ground, selectable? (effects may be non-selectable), no AV.
7. Soak: 4p with heavy defense use; check logs for new jet exports + no regression on turret itself.

**Success Criteria:** Flame jets visible when towers fire (user confirmation + log hits); no new crashes; metrics show added objects stay under cap.

**Risks / Guards:** Effects can be high-volume; use existing ephemeral anim patterns + cap guards.

### Milestone M2.72: Aircraft Late Sustain + Always-Visible (1 soak)
**Goal:** MiGs remain reliably visible/selectable even at cap / end-game.

**Files:**
- `DLLInterface.cpp` (sustain logic, aircraft force, Get_Layer_State).
- Possibly sustain helpers.

**Steps:**
1. Enhance the post-layer aircraft force block: always add flying aircraft to candidateSet + dirtyThisFrame, regardless of query result.
2. Strengthen sustain path for RTTI_AIRCRAFT:
   - In `Aeloria_ShouldSustainProducedUnit` / bulk / foot sustain: special case aircraft to remain "unretired" longer or use index query only.
   - Add "air sustain" pass similar to foot layer sustain.
3. In index: when updating air objects, mark with higher "sustain weight" or never prune air from priority unless explicitly dead.
4. In candidate query: guarantee a small % of slots for air (or top-N air separately).
5. Update `Aeloria_TechnoClassRawIsHealthy` or guards to be more lenient for air.
6. Test: Heavy air production + long games; fly MiGs late; check visibility when near 512.
7. Soak: Reproduce prior long 4p; verify >95% air visibility even at end.

**Success:** MiGs no longer spotty at end; sustained via index + force even under drops.

### Milestone M2.73: Spatial Coverage + South Guarantee (1-2 soaks)
**Goal:** No more than 1-2% map invisible even at extreme cap; eliminate "10% bottom at end".

**Files:**
- `DLLInterface.cpp` (QueryBestCandidates, spatial buckets, Get_Layer_State collect/process).

**Steps:**
1. Improve `QueryBestCandidates`:
   - Sample across buckets (not just sequential map iteration): divide map into regions (e.g. 4-8 quadrants), pick top-prio from each + overall top.
   - Or: after priority top-N, add a "coverage pass" that pulls at least 1-2 from high-cell / south buckets.
2. Enhance spatialBuckets: consider coarser bucketing (e.g. cell >> 4 or 2D grid) for faster region queries.
3. Optional: integrate real view (player camera / Map view rect) to boost candidates inside view + high prio outside.
4. In trim / compact at cap: bias slightly toward spatial spread (or use existing uniform compact more aggressively for map objects).
5. In update: slight prio tie-break by cell Y (higher Y / south gets tiny boost for equal-prio objects).
6. Test: Maps with action spread north-south; long soaks hitting 512+; measure % visible by region (via logs or in-game).
7. Soak: Validate <5% south loss even at 67k+ frames.

**Success:** South stays visible until much later (or never drops below small %).

### Milestone M2.74: Guard Cost + Metrics Polish (parallel with above)
**Goal:** Flat costs at cap; reliable EXPORT_METRIC; less log bloat.

**Files:**
- `DLLInterface.cpp` (guards, logging budgets, metric emission, perhaps prune logic).

**Steps:**
1. Reduce `LATE_GAME_AV_GUARD` spam:
   - Make budgets dynamic or per-type (air/flame get more tolerance).
   - Only log on first N per object or when state changes (use index to track "last guarded").
   - Consider fail-open for some late checks if index says "known good".
2. Make `LAYERS_EXPORT_METRIC` always emitted (remove any quiet path); add fields like air_count, flame_count, south_objects, candidate_hit_rate.
3. Add cheap headroom metrics (e.g. avg candidates, prune rate).
4. In index: faster stale pruning (e.g. on update, evict old low-prio if bucket full).
5. Test: Measure log size growth + frame time in long soaks; verify metrics useful for analysis.
6. Soak: Confirm no perf regression + better debuggability.

### Cross-Cutting / Validation
- **Testing:** 
  - Unit: build + targeted maps (air heavy, flame towers, spread-out action).
  - Soak protocol: Launch-Aeloria -Profile Experimental -NC; 4p long games; use Analyze-AeloriaSoak.ps1; capture max_frame, near-cap counts, specific logs (air/flame/south).
  - Compare vs this 67k baseline.
- **Docs:** Update 30-handoff, 31-plan, 33-compact, 70-workflow after each M. Add this plan as 46-.
- **Multi-agent:** Use the 70- workflow for parallel work on flame vs spatial if desired.
- **Risks:** Over-forcing can bloat candidates; keep caps + priority. Test for new AVs (guards stay).
- **Metrics of Success (for next soak):**
  - Max frame >80k with <5% visibility loss anywhere.
  - Flame jets visible in logs + game.
  - Log size growth < previous rate.
  - EXPORT_METRIC shows candidate efficiency improving.
  - No new crash types.

## Timeline / Order
- M2.71 (flame) first (user-visible gap).
- M2.72 + M2.73 in parallel or sequential.
- M2.74 ongoing.
- After M2.74: full validation soak + promote to next wave or Stable profile update.

## References
- This run log + user feedback.
- Prior: 33-compact, 42-uniform-cap, 70-workflow, DLLInterface.cpp recent diffs.
- ANIM.CPP for flame anim notes.

Next action after this plan: implement M2.71 flame export, test locally, then soak.

Tag for this plan state: after commit, `git tag -a aeloria-plan-E270-followup ...` (if desired).