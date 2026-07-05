# Aeloria Phase E.2.2 — VFX Implementation Plan

See session plan for full detail; this file mirrors the implementation DAG for the repo.

**Branch:** `experimental` for new work. **Stable:** promoted E.2.9/E.2.10 @ 2026-06-28 (submodule 9ad2ae4).

## DAG

PR0 instrumentation → PR1 Mig → PR2 Heli → PR3 Flame → PR4 playtest → PR5 soak → PR6 promote

## Acceptance

- G1: HIND/LONGBOW visible + rotors  
- G2: MIG no blink when moving  
- G3: Flame tower FBALL VFX visible  
- G4: 20+ min no abrupt crash  

## Evidence

Soak `d8ee4506-c453` (74 min PASS); log `Logs/Aeloria-Debug_20260627_165256_d8ee4506-c453.log`

## E.2.1 guards (keep)

- Fixed-wing intercept defer until MAIN cache  
- No rotor virtual layers when `bad_plus_8`  

## E.2.2 shipped (experimental)

- **PR1:** Skip `PRODUCED_AIRCRAFT_INTERCEPT_DEFER` when `shape_file_name` is set (explicit VIRTUAL emit); Mig uses guarded facing shape every frame.
- **PR2:** `bad_plus_8` rotors use emit+accessories; `PRODUCED_HELI_DRAW_PATH` logs.
- **PR3:** `Aeloria_TryVirtualCombatAnimExport` on normal LAYERS path; `EPHEMERAL_ANIM_EXPORT`; anim `AssetName` without `Class_Of` for FBALL types.

## E.2.4 (heli move crash)

- **Cause:** After `BAD_PLUS8_CLEARED` + MAIN cache, produced helis took `DrawProducedRotorVirtualLayers` → legacy `Techno_Draw_Object` / `Draw_Rotors` while `sustainRetired` still false.
- **Fix:** `Aeloria_ProducedRotorPrefersSafeEmit` — guarded emit until sustain handoff; block legacy fall-through.

## E.2.8 (spy plane) — LOCKED WIN

- Eternal bad+8 pin for fixed-wing produced aircraft.
- Evidence: soak `e8c9e63e-f505` 80min, zero `BAD_PLUS8_CLEARED` on type_enum=2.

## E.2.9 (rotor eternal pin) — PROMOTED STABLE

- Never clear `producedUnitBadPlus8` for rotors in Draw_It or MAIN cache notify.
- Evidence: soak `77c18c92-c862` 83min clean quit; `72db29b5-a2b7` P4 PASS.

## E.2.10 (perf logging/prune) — PROMOTED STABLE

- Placeholder logs gated verbose + once-per-object; aggressive stab prune when remain_stab > 400.
- Note: late-game FPS still unacceptable; E.2.11 graduation planned on experimental.

## E.2.11 (next, experimental only)

- Produced-unit graduation off eternal guarded draw; yellow marker removal. See `Docs/superpowers/plans/2026-06-29-e211-produced-unit-graduation.md`.

## E.2.22 (menu AV after match)

- **Symptom:** Crash in main menu after skirmish / quit (E.2.21 build).
- **Cause:** Produced-unit stab maps survived into menu `Get_Layer_State`; bulk/sustain touched freed pool slots.
- **Fix:** `GameActive` gate on bulk/foot sustain/force export; `SCENARIO_TRACKING_CLEARED` on `ProgEnd` + custom map entry.

## E.2.23 (menu AV — Select_Game / GameActive)

- **Symptom:** Menu crash browsing custom maps or after quit (non-debug sessions).
- **Cause:** `Select_Game()` sets `GameActive=true` in the main menu while E.2.22 only cleared tracking on `ProgEnd` (process exit). Stale stab maps + bulk/sustain could still run in menu `Get_Layer_State`.
- **Fix:** `g_AeloriaSkirmishMatchActive` — armed at first `Map.Render` after `CNC_Start_*`, cleared on `GameActive` off / `ProgEnd` / map start entry. `Aeloria_MatchLayerExportAllowed()` gates bulk, sustain, and force export.

## E.2.24 (menu AV — skirmish scope during map browse / setup)

- **Symptom:** Menu crash when browsing custom maps (often after a prior skirmish load or without reaching gameplay).
- **Cause:** E.2.23 armed match at `first_render` inside `CNC_Start_*` while the Remastered client still shows menus/setup; `GameActive` stays true so bulk/sustain ran with stale tracking. `Aeloria_PruneStaleTracking` also dereferenced pool slots outside a live match.
- **Fix:** Arm match only on **first `CNC_Advance_Instance`**; `Aeloria_OnMainMenuPhase()` from `Select_Game()`; clear on init / game over / `GameActive` edges; gate prune on `g_AeloriaSkirmishMatchActive`; drop `GameActive` from `Aeloria_MatchLayerExportAllowed()`.

## E.2.25 (menu AV — lobby preview still armed match)

- **Symptom:** Menu crash when browsing custom maps after E.2.24 deploy (first Advance in skirmish lobby still enabled bulk/sustain).
- **Cause:** E.2.24 armed on first `CNC_Advance_Instance` while the client still runs setup/preview after `CNC_Start_Custom_Instance`; stale tracking + prune dereference after backing out of a map load.
- **Fix:** Arm match only when `Scen.MissionTimer` is active/started (`CNC_Start_Mission_Timer` or eligible Advance); disarm stale match in `Get_Layer_State` when timer not running; plausible-pointer guard in `Aeloria_PruneStaleTracking`.

## E.2.26 (menu AV — sticky `Was_Started()`)

- **Symptom:** Menu still crashes browsing custom maps after E.2.25.
- **Root cause:** `CDTimerClass::Stop()` does **not** clear `WasStarted`; `Aeloria_LiveMatchSimEligible()` treated `Was_Started()` like a live match, so bulk/foot-sustain/prune stayed enabled in lobby after a prior countdown or quit. Foot sustain and cap-prune also dereferenced raw tracking keys without `Aeloria_IsObjectTrackingKeyUsable`.
- **Fix:** `g_AeloriaExplicitLiveMatch` set only when `CNC_Start_Mission_Timer` runs after map load (`g_AeloriaCncStartCompleted && Frame > 0`) or `Advance` with `MissionTimer.Is_Active()`; `Aeloria_MatchLayerExportAllowed()` requires explicit live; `Aeloria_ResetLiveMatchScope()` on menu/game-over/map-entry; hardened foot sustain, bulk, sustain, prune, layer null-check, forced catchup.

## E.2.27 (menu AV — forced catchup on map preview)

- **Symptom:** Menu crash browsing custom maps; debug log ends immediately after `FORCED_CATCHUP_HASCREATION_AFTER_FIRST_RENDER` at frame 0 (`6748a5ed-052a`, 2026-07-01).
- **Cause:** `CNC_Start_Custom_Instance` ran `DLL_Draw_Intercept` catchup during lobby preview (`g_AeloriaLayerExportActive` false, no live match).
- **Fix:** Remove catchup from `CNC_Start_Custom_Instance`; run `Aeloria_RunForcedCatchupHasCreation` only from `CNC_Start_Mission_Timer` when live skirmish starts; drop `Advance`-based explicit-live arming.

## E.2.28 (skirmish t=1s AV — catchup + preview tracking wipe)

- **Symptom:** Crash ~1s after skirmish start (menu browse OK on E.2.27).
- **Cause:** Same unsafe `DLL_Draw_Intercept` catchup moved to `CNC_Start_Mission_Timer`; `Get_Layer_State` cleared all tracking every preview poll so live bulk had nothing / raced.
- **Fix:** Remove forced catchup entirely; rely on match-gated bulk on first live `Get_Layer_State`; stop `Aeloria_ClearScenarioTracking` on non-match layer exports.

## E.2.29 (skirmish t=0 bulk — stab cleared at first render)

- **Symptom:** Crash or empty client layer right after live skirmish start on E.2.28 builds (no `FORCED_CATCHUP` in log).
- **Cause:** `CNC_Start_Custom_Instance` clears `g_AeloriaObjectStability` at first render but keeps `g_AeloriaObjectCreationFrame`; live bulk skipped every creation key with no stab row (`sIt == end`).
- **Fix:** `Aeloria_EnsureStabilityForTrackedCreations` when arming live match and before match-gated bulk in `Get_Layer_State`.

## E.2.30 (menu AV — stale keys after E.2.28)

- **Symptom:** Menu crash browsing custom maps on E.2.28/E.2.29 (skirmish may be OK).
- **Cause:** E.2.28 stopped preview `SCENARIO_TRACKING_CLEARED`; freed unit pointers stayed in maps; lobby `Get_Layer_State` could still disarm match late or touch stale keys on map churn.
- **Fix:** On non-match layer exports: clear `g_AeloriaExplicitLiveMatch` when mission timer inactive; force-disarm match; `Aeloria_PruneDeadTrackingKeys` only (not full clear).

## E.2.31 (skirmish ~2min AV — foot sustain + disarm wipe)

- **Symptom:** Skirmish runs ~1–2 min then `ClientG.exe` c0000005; log shows heavy `PRODUCED_INFANTRY_*` then abrupt stop (`b25ab038-f99f`).
- **Cause:** `Aeloria_SustainMissingFootLayerObjects` walked **all** `g_AeloriaObjectCreationFrame` keys each LAYERS export (every produced infantry), inflating `Count`/tail slots; `Aeloria_SetSkirmishMatchActive(false)` from `Get_Layer_State` still called full `SCENARIO_TRACKING_CLEARED`; refinery harvester pool-reuse left stale export type on same pointer.
- **Fix:** Foot sustain only for hotlist + stab rows already `clientListInserted`; contiguous slot guard + invalid-pos skip; layer `Count` clamp 512; disarm from `Get_Layer_State*` uses dead-key prune only; `Aeloria_ResetProducedTechnoTracking` on harvester relocate when RTTI/type changes.

## E.2.32 (north star restore — menu + skirmish)

- **Symptom:** North star failures: menu browse AV, skirmish t=0 / ~2min `ClientG.exe` c0000005, unstable sessions blocking map work.
- **Cause:** `DLL_Draw_Intercept` wrote past 512 LAYERS slots under heavy draw/sub-object load; `GameActive_on_main_menu` rising edge called `Aeloria_ResetLiveMatchScope` and cleared `g_AeloriaCncStartCompleted` between custom instance load and `CNC_Start_Mission_Timer`; preview/menu stale tracking needed extra prune pass.
- **Fix:** 512 guards in intercept + layer walk `Draw_It`; remove `GameActive_on` scope reset (menu reset stays `Aeloria_OnMainMenuPhase` + `GameActive_off`); extra dead-key prune when menu idle; carries E.2.31 foot-sustain/disarm/harvester fixes.

## E.2.33 (menu AV — live bulk in lobby)

- **Symptom:** Crash browsing custom maps / menus on E.2.32 (`20052985-263e`, non-debug).
- **Cause:** `CNC_Advance_Instance` still called `Aeloria_TryArmSkirmishMatch`; `Aeloria_MatchLayerExportAllowed()` ignored `MissionTimer.Is_Active()` so lobby LAYERS could run bulk/sustain; creation-key repair in `DLL_Draw_Intercept` on preview exports.
- **Fix:** Remove Advance TryArm; require active mission timer for match export; always clear explicit live on non-match `Get_Layer_State`; `SCENARIO_TRACKING_CLEARED` when main menu (`!g_AeloriaCncStartCompleted`); `g_AeloriaLiveLayerEnhancements` gates intercept repair/seed to live match only.

## E.2.34 (skirmish ~30s AV — WINDOW_EXPIRED prune)

- **Symptom:** Skirmish ~30–40s crash (`d580f9cd-bc4d`); log ends at `WINDOW_EXPIRED` / `WINDOW_EXPIRED_PRUNE` frame ~600, no bulk logs.
- **Cause:** `Aeloria_ShouldRetainTrackingAfterWindowExpire` only kept `creation_frame > 10`, dropping scenario-start units (frame 0) while still on map; E.2.33 `MissionTimer.Is_Active()` gate could block live bulk before timer ticks.
- **Fix:** Retain all active `g_AeloriaObjectCreationFrame` rows + human-house units at window expire; match export gated on explicit live + skirmish only (timer Is_Active removed).

## E.2.35 (skirmish WINDOW_EXPIRED + live arm)

- **Symptom:** Repeated skirmish crash ~40s (`WINDOW_EXPIRED` at frame 600); no `LIVE_SKIRMISH_ARMED` in log.
- **Cause:** `WINDOW_EXPIRED_PRUNE` still ran on loaded maps at frame 600; preview `Get_Layer_State` cleared `g_AeloriaExplicitLiveMatch` even when mission timer running; match never armed if timer started without log flush.
- **Fix:** Skip `WINDOW_EXPIRED` tracking prune when `GameActive && g_AeloriaCncStartCompleted`; re-arm via `Advance` only when `MissionTimer.Is_Active()`; only clear explicit live on preview when timer inactive.

## E.2.37 (skirmish ~1 min — preview burned exemption window)

- **Symptom:** Crash ~40s–1 min with `WINDOW_EXPIRED` at frame 600; often no `LIVE_SKIRMISH_ARMED` (d580f9cd).
- **Cause:** `g_PlayerExemptionFrames` started at `CNC_Start_Custom_Instance` and decremented during lobby/preview sim for hundreds of frames before `CNC_Start_Mission_Timer`.
- **Fix:** `g_AeloriaPlayerExemptionCountdownActive` — hold countdown until mission timer; refresh to `AELORIA_LIVE_MATCH_EXEMPTION_FRAME_COUNT` (18000) on `CNC_Start_Mission_Timer`.

## E.2.38 (skirmish Start ~1s — frame 2426 AV)

- **Symptom:** Crash ~1s after **Start** on custom skirmish (`ce97236b`); abrupt log tail at frame **2425–2426**; `CLIENT_DRAW_INTERCEPT` / `CONVERT_TYPE` storm on **RTTI_BUILDING** (`stab=0`, `has_creation=1`). E.2.37 OK (no `WINDOW_EXPIRED` @600).
- **Cause:** `g_AeloriaExplicitLiveMatch` only set in `CNC_Start_Mission_Timer` (often missing in log); preview `DLL_Draw_Intercept` still populated client slots; unsafe `OverrideDisplayName` / HUD fields on under-construction buildings.
- **Fix:** E.2.38 Advance fallback when `MissionTimer.Is_Active()` (set explicit live + TryArm + exemption refresh); preview intercept early return when `!Aeloria_MatchLayerExportAllowed()`; `Aeloria_PopulateTechnoHudFields` + safe display name; `LIVE_MATCH_ARM_ATTEMPT` / `PREVIEW_LAYER_EXPORT` logs.

## E.2.49 (LAYERS 512 cap instrumentation)

- **Symptom:** North star needs visibility into client LAYERS buffer pressure; E.2.32 guards silently dropped/skipped slots with no soak metrics.
- **Cause:** 512-cap guards in `DLL_Draw_Intercept`, layer-walk trim, foot sustain, bulk/sustain idx, and final `Count` clamp had no structured logging.
- **Fix:** `LAYERS_NEAR_CAP` when count ≥ 480; `LAYERS_CAP_DROP` at each E.2.32 guard site (intercept guard/inc, layer-walk skip/trim, foot sustain, bulk/sustain idx, total clamp). Layer-walk trim prefers retaining tracked starting units and human-deployed buildings. `Analyze-AeloriaSoak.ps1` P4/NS summary counts `LAYERS_*` events.

## E.2.50 (non-debug performance — quiet critical path)

- **Symptom:** Normal (`-NC`) skirmish sessions felt sluggish in the first 1–2 minutes; debug logs showed high-volume `CONSTRUCTION_SEED`, `PRODUCED_UNIT_FIRST_DRAW`, `BUILDING_STAB_REFRESH`, and `HARVESTER_*` critical lines every frame.
- **Cause:** Critical log families were not rate-limited when `AELORIA_ENABLE_VERBOSE_DRAW_LOGS=0`; preview `Get_Layer_State` also ran prune/ensure every export before live match.
- **Fix:** `AELORIA_QUIET=1` set by `Launch-Aeloria.ps1` for non-`-DebugMode` sessions; `g_AeloriaQuietMode` gates noisy critical prefixes in `DLLInterface.cpp` / `OBJECT.H`; preview prune/ensure throttled to every N frames until explicit live match. Milestone prefixes (`LIVE_SKIRMISH_ARMED`, `SCENARIO_TRACKING_CLEARED`, etc.) remain unthrottled.

## E.2.51 (late-game REDALERT.DLL AV — `000b7fdf`)

- **Symptom:** Skirmish crash ~frame 58 659 (`1c4c2d18-c1be`); WER `REDALERT.DLL+0x000b7fdf`.
- **Cause:** `Get_Layer_State` layer walk → `Draw_It` → `Techno_Draw_Object` on pool-reused techno with stale `Class`/`+8` after `TRACKING_PRUNE` at scale; object still exported in bulk/sustain slots.
- **Fix:** Budgeted `LATE_GAME_AV_GUARD` logging; `Aeloria_GuardExportObjectPtr` on intercept/bulk/sustain/factory/shadow export paths; `Aeloria_TechnoClassRawIsHealthy` gate before `Draw_It` in layer walk. Symbolized to `TechnoClass::Techno_Draw_Object` (+0x2f). See `Docs/AELORIA-RCA-SKIRMISH-CRASH-20260702.md`.

<!-- E.2.52 (Start transition hardening) skipped — no repro after E.2.49–51; conditional per unified plan PR 4. -->

## E.2.53 (preview skirmish layer visibility)

- **Symptom:** Soak `f7058a36-7de9` — long stable session but spotty invisibility (war-factory MCVs, some defenses/APWR/silos/Tesla); no `LIVE_SKIRMISH_*` (preview export path).
- **Cause:** `Get_Layer_State` gated on `IsDown` without preview force-export; E.2.51 `techno_unhealthy_pre_draw` / `unsafe_layer_obj` skipped with no client slot; WEAP-tethered queue units skipped; factory `ProductionAssetName` merge failed silently; preview bulk skipped human-deployed buildings.
- **Fix:** `Aeloria_ForcePreviewSkirmishLayerExport` + relaxed `Aeloria_IsPreviewLayerWalkObjectPtr`; `PREVIEW_SAFE_LAYER_EMIT` via `Aeloria_TryAppendPreviewSafeLayerSlot`; preview WEAP tether export; `Aeloria_FactoryProductionAssetFallback`; preview bulk pass + `LAYER_EXPORT_SKIP` diag budget separate from `LATE_GAME_AV_GUARD`.

## E.2.45 (preview tracking prune — 56d04f08)

- **Symptom:** `DEAD_TRACKING_PRUNED creation=11` @ frame 0 on `Get_Layer_State_preview` → `Unit guard passed` @ frame 18.
- **Cause:** `Aeloria_IsObjectTrackingKeyUsable` dropped active starting units during preview prune (creation map wiped).
- **Fix:** `Aeloria_PreviewSkirmishTrackingRetain`; `EnsureStabilityForTrackedCreations` after preview prune; PR0 instrumentation; analyzer gates `no_preview_mass_creation_prune`, `no_unit_guard_before_live_arm`.

## E.2.43 (PREVIEW legacy MAIN — E.2.42 insufficient)

- **Symptom:** `5f1f8c7f` abrupt tail @ frame **26**; `PREVIEW_LAYER_EXPORT` only; `Unit guard passed` on 2TNK `0D3A4203` with `Class.Raw=2`, `at+8=0x78417800`.
- **Cause:** Starting units graduated off MAIN guard when intercept set `HasSaneMainDrawCache` during lobby PREVIEW; `TechnoClassRawIsHealthy` true while legacy `Techno_Draw_Object` still AV.
- **Fix:** `Aeloria_IsExplicitLiveSkirmishMatch()`; tracked starting units stay guarded until live arm + sane cache + healthy raw + plausible +8 (`UNIT.CPP`, `VESSEL.CPP`, `IsEarlyStartingUnitMainGuarded`).

## E.2.42 (launch AV frame ~48 — premature MAIN graduation)

- **Symptom:** `b7e7105c` abrupt tail @ frame **48** after `Unit guard passed` on starting 1TNK (`0DCE435E`); had `UNIT_MAIN_GUARD` @ frame 0.
- **Cause:** `Aeloria_IsEarlyStartingUnitMainGuarded` dropped guard when `Aeloria_HasValidMainDrawCache` alone; +8 plausible while `TechnoClass` still corrupt.
- **Fix:** Graduate starting-unit MAIN guard only when `Aeloria_HasSaneMainDrawCache` **and** `Aeloria_TechnoClassRawIsHealthy`. See `Docs/AELORIA-RCA-SKIRMISH-CRASH-20260702.md`.

## E.2.41 (skirmish launch crash — E.2.40 early live arm)

- **Symptom:** Crash when launching skirmish after E.2.40; pattern matches ~2426 building intercept / bulk at Start transition.
- **Cause:** `Advance_glyphx_skirmish_sim` armed live match at **frame 1** in lobby, enabling full techno HUD/bulk for entire preview sim until Start (~2400+ frames).
- **Fix:** Remove frame-1 auto-arm; `g_AeloriaUserRequestedLiveStart` only from `CNC_Start_Mission_Timer`; live arm on `Advance_user_skirmish_start` / pending timer apply; `Aeloria_SafeForFullTechnoLayerFill` skips HUD on under-construction buildings with `stab<1`. Keep `Aeloria_ClientLayerPopulateAllowed()` for visibility.

## E.2.40 (total invisibility — E.2.39 intercept gate)

- **Symptom:** After E.2.39 deploy (`1f09e75e`), all units/buildings invisible on custom skirmish map; log still `PREVIEW_LAYER_EXPORT` only, no mission timer API.
- **Cause:** Top-of-`DLL_Draw_Intercept` return when `!Aeloria_MatchLayerExportAllowed()` blocked **all** LAYERS client slots; GlyphX skirmish does not always call `CNC_Start_Mission_Timer`.
- **Fix:** `Aeloria_ClientLayerPopulateAllowed()` — vanilla populate during `Get_Layer_State` on loaded map; keep bulk/repair on `Aeloria_MatchLayerExportAllowed()`; defer `Aeloria_PopulateTechnoHudFields` / `OverrideDisplayName` to live match; `Advance_glyphx_skirmish_sim` live arm fallback.

## E.2.39 (skirmish Start — mission timer before GameActive)

- **Symptom:** Post–E.2.38 soak (`fa46d5de`) still dies at frame **2426**; log has `PREVIEW_LAYER_EXPORT` only; no `LIVE_MATCH_ARM_ATTEMPT` / `LIVE_SKIRMISH_ARMED`; verbose `CLIENT_DRAW_INTERCEPT` on preview path.
- **Cause:** Vanilla `CNC_Start_Mission_Timer` no-ops when `!GameActive`; Unity may call it on skirmish **Start** before sim is active. E.2.38 intercept throttle ran after verbose/repair paths.
- **Fix:** Queue `PENDING_MISSION_TIMER_*` when timer API runs with map loaded but `!GameActive`; apply + `Aeloria_BeginLiveSkirmishMatch` on next `CNC_Advance_Instance`; move preview intercept return to top of `DLL_Draw_Intercept`; entry log on `CNC_Start_Mission_Timer`.

## E.2.36 (skirmish ~1 min — Is_Player_Exempt cliff)

- **Symptom:** Skirmish still dies ~40s–1 min after E.2.35; log `WINDOW_EXPIRED` at frame 600; human starting units lose placeholder guards.
- **Cause:** `Is_Player_Exempt` returned false for all objects when `g_PlayerExemptionFrames` hit 0, before the human-house owner check — even on a loaded live map.
- **Fix:** `Aeloria_IsLiveSkirmishMapLoaded()` (`GameActive && g_AeloriaCncStartCompleted`); human-house objects keep exemption until per-object MAIN graduation (stability level 2 + valid MAIN cache).

## E.2.21 (WF phantom mammoth)

- **Symptom:** Invisible HTANK, area-selectable, won't move — sim unit exists, client never registered.
- **Cause:** E.2.15 lite-seed called `Aeloria_GraduateTrackedObject` on MAIN cache at Unlimbo → erased `g_AeloriaObjectStability` + `sustainRetired` before `clientListInserted`; plausible +8 also set `earlySafeClientRegistered=false`.
- **Fix:** Defer graduate/erase until `clientListInserted`; UNIT `Is_Drawable` bypass + legacy `Get_Image_Data` fallback; human WF `earlySafeClientRegistered` after lite seed.