# Draw & Registration Pipeline Diagnosis Report
**Project:** Aeloria (Rampastring-MoreQoL fork of CnC Remastered Red Alert)  
**Date of analysis:** 2026-06-07 (on-disk ground truth)  
**Charter:** Draw & registration pipeline diagnosis for "units invisible" (infantry + vehicles, player + AI) in 4p custom skirmish.  
**NORTH STAR:** User must achieve reliable "YOU launch, I play" via simple .bat: visible sprites, selectable/orderable within seconds, 5+ min stable play, mods (correct DLL + GameConstants_Mod.xml) activate.

## 1. Ground Truth Established On Disk (Verified via list_dir, read_file with offsets, grep -B/-A, .git reflog reads)

- **Outer repo:** On `stable` branch (from `.git/HEAD`: `ref: refs/heads/stable`). Working tree dirty (Launchers/*.bat, Scripts/Launch-Aeloria.ps1 modified per user spec + observed baks in live).
- **Submodule (Source/Rampastring-MoreQoL):** Pinned at milestone `3e53e4c` (full per user: 3e53e4cb31b9c5ac99c2c76aa76bb893bc7ff275; commit msg per user + outer reflog: "packing hygiene + granular early Class pointer diagnosis + +8 guard band-aid"; "the recorded 'first non-crashing skirmish load' baseline"). Reflog confirms pin in outer commit `6cd627acebd6d75d001859bbbc2da551ed9c634c` ("stable: pin submodule to milestone commit 3e53e4c ...").
  - Inside submodule dir: uncommitted change **ONLY** in `REDALERT/CONQUER.CPP` (the 16x16 feed + Aeloria_Debug_Log + guard; matches "local M").
  - No `modules/` visible in top `.git/` (list_dir), submodule .git read denied (expected for gitlink); source files on disk reflect the pinned commit + local edit.
- **Deployed artifacts (workspace Dev + "live" sibling):**
  - Workspace: `Development/Mods/Red_Alert/Aeloria-Stable/Data/RedAlert.dll` (1250816 bytes, Jun 7 post-build), `Aeloria-Experimental/Data/RedAlert.dll` (1270272 bytes), `Vanilla-Plus/Data/RedAlert.dll` (1256448 bytes, May).
  - Live (via list_dir `../Mods/Red_Alert` + ps1 logs): `C:\Users\jacks\Documents\CnCRemastered\Mods\Red_Alert\Aeloria-Stable/` (and many `.bak_*` from NoCleanup runs), same DLL sizes/timestamps propagated by deploys. `Vanilla-Plus/`, `Aeloria-Experimental/` present. NoCleanup left state (live folders persist for .bat/Steam `MOD=`).
  - Scripts/RedAlert.dll present (pollution vector).
- **Recent runs (read_file on Logs/Launch-Aeloria_*.log + Aeloria-Debug_*.log):**
  - 2026-06-07 13:20 run (ps1 with -BuildFirst/-A/-NC implied): Detected "Newest profile: Stable" (timestamps: Stable 13:17, Experimental 12:22, Vanilla May). Built (MSBuild forced v145, recompiled CONQUER.CPP), Auto-copied 1250816-byte DLL to Aeloria-Stable dev, deployed to live sibling `...\Mods\Red_Alert\Aeloria-Stable`, launch `REDALERT MOD=Aeloria-Stable -FastLaunch`. Window ~20s, ~46s visible runtime, processes exit (no crash zip this log). NoCleanup left live as-is.
  - 2026-06-07 13:23 run (similar): Same Stable selection/deploy (1250816), ~46s runtime, captured `CrashReports/Crash_20260607_132431.zip`.
  - Earlier 12:20 Aeloria-Debug log (from pre-13:20 Experimental DLL?): Shows "EARLY LOAD GRACE: enabled...", "HUMAN PLAYER HOUSE CAPTURED FOR EXEMPTION", "GRACE FRAME FINAL", creation logs (RTTI=28=INFANTRY?), "Terrain guard passed", CC_Draw "at+8=0x00080000", but **no equivalent grace strings in current source**.
  - User-described 13:28 crash zip + "announced Stable but finalized on Vanilla-Plus".
  - Symptoms repeated: skirmish starts (map sometimes visible), NO UNITS VISIBLE (infantry especially, player+AI), runs 0.5-60s then crash/terminate ("nothing to play"). "Even vanilla / Vanilla-Plus baseline exhibits map yes + no units." "I launched aeloria stable ... but no mods were working!" DLL size/timestamp pollution.
- **v1 Release Notes confirmation** (Docs/10-Aeloria-Stable-v1-Release-Notes.md:80):
  > **Invisible units**: Infantry and other units (including enemy AI) may fail to render properly in some situations. This is more common during the early phase of a game or when many objects are created simultaneously.
  > ...
  > The current implementation uses a long human exemption window and safe placeholder rendering as a mitigation strategy rather than solving the root cause at the object creation level.
- **No advanced features in current on-disk source** (grep -i for grace|successfulRealDraws|per-object|early promotion|HUMAN_EARLY|post.?render|fixup.*draw|exemption|stability_tracked returned only unrelated legacy "Coord_Fixup"/"Fixup_Path" etc.; see §4).
- **Other paths:** `Launchers/Launch-Aeloria-Stable.bat` (and siblings) do **direct** `steam -applaunch 1213210 REDALERT MOD=Aeloria-Stable -FastLaunch` (no ps1). README.txt and QUICKSTART confirm .bat as "simple path". Scripts/Launch-Aeloria.ps1 is for dev (Get-MSBuildPath prefers 2017 15.0, always `/p:PlatformToolset=v145`, newest-DLL auto, -NoCleanup/-NC finally guard, deploy to live, log/crash capture).

**Critical files read (with offsets for large .cpp; absolute paths):**
- `Source/Rampastring-MoreQoL/REDALERT/OBJECT.H:304` (Is_Plausible + Is_Drawable)
- `Source/Rampastring-MoreQoL/REDALERT/CONQUER.CPP:3434-3507` (two CC_Draw_Shape(ObjectClass*) overloads, +8, 16x16, Aeloria_Debug_Log, REJECTED, WINDOW_VIRTUAL path)
- `Source/Rampastring-MoreQoL/REDALERT/DLLInterface.cpp:3447-3811` (DLL_Draw_Intercept + full population), `:4012-4072` (Convert_Type)
- `Source/Rampastring-MoreQoL/REDALERT/CELL.CPP:1286-1299` (pruning), `1351-1365` (Draw_It calls)
- `Source/Rampastring-MoreQoL/REDALERT/INFANTRY.H:135-157` (Class_Is_Valid + +8 guard; similar in UNIT.H:156+, BUILDING.H:291+, AIRCRAFT.H:92+, etc. for all 8)
- `Source/Rampastring-MoreQoL/REDALERT/INFANTRY.CPP:2398` (Unlimbo), `565` (Draw_It guard + logs + Techno_Draw_Object)
- `Source/Rampastring-MoreQoL/REDALERT/FOOT.CPP:1085`, `TECHNO.CPP:1243`, `OBJECT.CPP:1510` (Unlimbo chain, IsInLimbo=false, Map.Submit)
- `Source/Rampastring-MoreQoL/REDALERT/RedAlert.vcxproj:35,41,99,130` (v145 + 1Byte alignment /Zp1)
- `Scripts/Launch-Aeloria.ps1:226-250` (Get-NewestProfile), `421-441` (selection + $list[0] default), `269-310` (Deploy-Profile), `533-536` (backup/deploy), `574-588` (NoCleanup)
- `Launchers/Launch-Aeloria-Stable.bat:27` (direct steam MOD=)
- `Docs/10-Aeloria-Stable-v1-Release-Notes.md:80` (known limitation)
- Multiple Aeloria-Debug_*.log + Launch-Aeloria_*.log (concrete "at+8", "REJECTED", grace in old DLLs only, runtimes, deploys)
- `../Mods/Red_Alert/*` (live structure + baks via list_dir)

## 2. Ruthless Code Review: Exact Trace for Fresh Starting Rifle Infantry (RTTI_INFANTRY) or Light Tank (RTTI_UNIT) in 4p Skirmish

**Creation path (scenario load, custom 4p map, player + AI houses):**
- Placement code (e.g. INFANTRY.CPP:3567 `infantry->Unlimbo(coord, dir)` or UNIT.CPP equivalent, often inside `ScenarioInit++` blocks or Read_INI loops for houses 0-3).
- `ObjectClass::Unlimbo` (OBJECT.CPP:1514): `if (GameActive && IsInLimbo && !IsDown) { if (ScenarioInit || Can_Enter_Cell...) { IsInLimbo = false; ... Map.Submit(this, In_Which_Layer()); } }` (OBJECT.CPP:1516).
- Techno/Foot chain (TECHNO.CPP:1249 `Enter_Idle_Mode(true);`, FOOT.CPP:1092) adds to tracking but **Class member (CCPtr) may not be fully valid yet** due to construction order + bulk new + legacy init.
- `IsInLimbo` cleared; object in map layer; first Draw_It possible in same/next frame or first `Map.Render()` (DLLInterface.cpp:1485 "FIRST RENDER AFTER LOAD").

**Draw/registration path (every frame via CellClass::Draw_It -> object layers):**
1. `CellClass::Draw_It` (CELL.CPP:1261) walks occupiers/overlapper -> temp `optr` list. Sets `IsToDisplay`.
2. **Prune loop** (CELL.CPP:1286):
   ```cpp
   case RTTI_INFANTRY: if (!Is_Drawable((InfantryClass*)o)) optr.Delete(i); break;
   // same for UNIT, BUILDING, etc.
   ```
3. Sort remaining by Sort_Y.
4. For survivors: `if (...) object->Draw_It(xx, yy, WINDOW_PARTIAL);` (or TACTICAL) (CELL.CPP:1356).
5. In `InfantryClass::Draw_It` (INFANTRY.CPP:565) / `UnitClass::Draw_It` (UNIT.CPP:2096):
   ```cpp
   if (!Is_Drawable(this)) return;
   Aeloria_Debug_Log("Infantry guard passed this=%p Class.Raw=%ld ...", ...);
   ... Get_Image_Data() ...
   Techno_Draw_Object(...)  // or direct CC_Draw_Shape
   ```
6. `Is_Drawable<T>` (OBJECT.H:333): `if (!obj->Class_Is_Valid()) return false; if (Get_Image_Data()==NULL) return false;`
7. `Class_Is_Valid` override (e.g. INFANTRY.H:135):
   ```cpp
   if (!Class.Is_Valid() || Class.Raw() <= 0) return false;
   ...
   uintptr_t effective = *(uintptr_t*)((const char*)this + 8);
   if (!Is_Plausible_Class_Pointer(effective)) {
       sprintf(..., "REJECTED Class_Is_Valid ... at+8=0x%08X", effective);
       OutputDebugStringA(_buf);
       return false;
   }
   return true;
   ```
   (Identical +8 + OutputDebugString in UNIT.H:156, BUILDING.H:291, AIRCRAFT.H:92, VESSEL.H:87, TERRAIN.H:77, ANIM.H:92, BULLET.H:97.)
8. `Is_Plausible_Class_Pointer` (OBJECT.H:304):
   ```cpp
   if (ptr == 0) return false;
   unsigned char high = (unsigned char)((ptr >> 24) & 0xFF);
   if (high == 0x00 || high == 0x80 || high == 0x81) return false;
   if ((ptr & 0x3) != 0) return false;
   return true;
   ```
   (High-byte 00/80/81 + alignment filter; comments: "TEMPORARY BAND-AID", "after the 2026 packing/ODR fix", "garbage at the runtime offset the drawing code actually dereferences (+8 ... 0x00210000, 0x80738000...)".)
9. If all pass: `CC_Draw_Shape(this, ...)` (the ObjectClass* overloads, CONQUER.CPP:3434 and :3472).
10. In CC_Draw_Shape (CONQUER.CPP:3438):
    ```cpp
    uintptr_t at_plus_8 = *(uintptr_t*)((const char*)object + 8);
    Aeloria_Debug_Log("CC_Draw_Shape got Object this=%p RTTI=%d at+8=0x%08lx", ...);
    if (!Is_Plausible_Class_Pointer(at_plus_8)) {
        Aeloria_Debug_Log("REJECTED at CC_Draw_Shape (last-line defense) ...");
        if (object) {
            DLL_Draw_Intercept(shapenum, x, y, 16, 16, (int)flags, object, rotation, virtualscale, NULL, (char)object->Owner());
        }
        return;  // <--- skips real blitter + WINDOW_VIRTUAL full path
    }
    if (window == WINDOW_VIRTUAL) {
        ... DLL_Draw_Intercept(shapenum, x, y, width, height, ... real dims ...);
        return;
    }
    CC_Draw_Shape(shapefile... legacy);
    ```
    (Belt-and-suspenders comment: "Even if Class_Is_Valid() let something through... last line of defense before Buffer_Frame_To_Page / the C# interop path.")
11. `DLL_Draw_Intercept` (free) -> `DLLExportClass::DLL_Draw_Intercept` (DLLInterface.cpp:3464):
    ```cpp
    CNCObjectStruct& new_object = ObjectList->Objects[TotalObjectCount + CurrentDrawCount];
    memset(&new_object, 0, sizeof(new_object));
    Convert_Type(object, new_object);
    if (new_object.Type == UNKNOWN) { return; }  // <--- DROP
    ... subobject search ...
    new_object.CNCInternalObjectPointer = (void*)object;
    ... strncpy TypeName/AssetName from object->Class_Of().IniName / Graphic_Name() ...
    ... full population: PositionX/Y, Width=passed (16 or real), Height, IsSelectable=object->Class_Of().IsSelectable, Strength, ID from container, etc. ...
    CurrentDrawCount++;
    ```
12. `Convert_Type` (DLLInterface.cpp:4012):
    ```cpp
    object_out.Type = UNKNOWN; object_out.ID = -1;
    if (object == NULL) return;
    RTTIType type = object->What_Am_I();
    switch (type) {
        case RTTI_INFANTRY: object_out.Type = INFANTRY; object_out.ID = Infantry.ID(...); break;
        case RTTI_UNIT: ... UNIT ...
        // no default set for others; bullets/terrain etc. have cases
    }
    ```
    (What_Am_I() is virtual on ObjectClass base, usually works even early; sets ID from global containers like Infantry/Units.)

**Client interop:** The populated `ObjectList` (CNCObjectStruct array) is consumed by C# side (GlyphX remaster bridge) for tactical map sprites (using Width/Height/ShapeIndex/AssetName/Scale/Rotation), selection boxes (IsSelectable/IsSelectedMask), ordering, health bars, etc. Fresh list per render frame (TotalObjectCount += CurrentDrawCount; ObjectList->Count = ...). No units in list = invisible + unselectable.

**For a starting Rifle Infantry / Light Tank:** Unlimbo during init (ScenarioInit often true) -> submitted -> first Cell.Draw_It (or Render) hits +8 garbage (observed 0x00080000, 0x0021xxxx, 0x80/81xxxx in logs) -> Is_Drawable/Class_Is_Valid fails -> **pruned from optr** (never reaches Draw_It or CC_Draw) -> **never calls DLL_Draw_Intercept** -> **never appears in ObjectList** -> client has no sprite/selection for it (or AI equivalents). If somehow reaches CC guard (rare, e.g. direct calls or timing where Class_Is_Valid passed but +8 flipped), gets 16x16 placeholder registration (Type set correctly via What_Am_I, but Width/Height=16, may still draw tiny/wrong or be ignored by client blitter).

## 3. Every Place a Legitimate Early Object Is Turned Into 16x16 / UNKNOWN / Skipped Registration

1. **Cell::Draw_It prune** (CELL.CPP:1289-1296): `if (!Is_Drawable(...)) optr.Delete(i);` for all 8 drawable RTTIs. (Temp list only; object stays in occupiers but skips this frame's draw + registration.)
2. **Per-class Draw_It** (INFANTRY.CPP:574, UNIT.CPP:2096, BUILDING.CPP:492, AIRCRAFT.CPP:412, etc.): `if (!Is_Drawable(this)) return;` (prevents CC_Draw + DLL call).
3. **Is_Drawable** (OBJECT.H:340): delegates to `Class_Is_Valid()`.
4. **Class_Is_Valid overrides** (8x .H files): the +8 `Is_Plausible_Class_Pointer(effective)` -> OutputDebugString REJECT + return false. (Also Class.Raw() <=0 / !Is_Valid / !t checks.)
5. **Is_Plausible_Class_Pointer** (OBJECT.H:304): high-byte 00/80/81 or misalign -> false. (Heuristic from "live debug data" post-packing.)
6. **CC_Draw_Shape(Object*) belt** (CONQUER.CPP:3450,3487): if reached, `if (!Is_Plausible...) { DLL_Draw_Intercept(..., 16, 16, ...); return; }` (16x16 feed; skips WINDOW_VIRTUAL real-size path + legacy blitter).
7. **DLL_Draw_Intercept** (DLLInterface.cpp:3469): `Convert_Type(...); if (new_object.Type == UNKNOWN) { return; }` (then populates; 16x16 still reaches here and usually gets Type=INFANTRY/UNIT since What_Am_I succeeds).
8. **Other drops:** NULL object in Convert; some RTTI without switch case stay UNKNOWN; sub-object logic; !IsActive early-outs; ScenarioInit-path Closest_Free_Spot etc.; IsToDisplay/Visual_Character filters before Draw_It call.
9. **No re-registration or retry:** Prune/delete is per-frame; if +8 stays "bad" (or heuristic over-rejects), unit invisible across frames. No "once seen good, trust forever".

**UNKNOWN drops legitimate?** Rare for infantry/unit (What_Am_I + cases exist), but if Class_Of() later in population derefs bad memory it could corrupt before client sees it.

## 4. Absence/Presence of "Per-Object Stability", "Human Early Promotion", "Grace Active", etc.

- **Absent in current on-disk source (the pinned + local M state):** No "grace", "successfulRealDraws", "post render fixup", "per-object stability", "HUMAN_EARLY", "exemption window", "stability_tracked", "EARLY LOAD GRACE", long human exemption, or promotion logic. (Confirmed by broad grep; only legacy fixups.)
- **Present in some deployed DLLs (Aeloria-Debug logs from ~12:20 runs):** "EARLY LOAD GRACE: enabled for first Map.Render() (Custom path)", "HUMAN PLAYER HOUSE: 12 ... CAPTURED FOR EXEMPTION", "GRACE FRAME FINAL", "FIRST_RENDER_SNAPSHOT custom_map stability_tracked=0 with_creation=16", plus creation logs with "early=1". These produced "guard passed" + CC_Draw for terrain at least.
- **Conclusion:** The 3e53e4c pin (and thus Stable baseline after 13:20 rebuild) is the "packing hygiene + ... +8 guard band-aid" state **without** the experimental grace/exemption/promotion layers added in later experimental commits (e.g. "stability promotion + HUMAN_EARLY_STILL_UNKNOWN", "Phase 2 client draw/registration diagnostics"). Release notes (written for "Stable-v1") describe a richer mitigation that the pinned source does not contain. Rebuilds via ps1 -B overwrite Stable dev/live DLLs with guard-only bits -> immediate regression to "no units".
- **"16x16 feed" is the only "safe placeholder" in current code:** Explicitly in the two CONQUER overloads (lines 3456, 3493). Comments claim "so the unit can be visible/registered" but it is belt-and-suspenders (rarely hit due to prior prunes) and uses fixed tiny dims.

## 5. Launcher Profile Selection/Deploy Logic Bug ("launched stable but got vanilla")

- **Get-NewestProfile** (ps1:226): Scans workspace `Mods\Red_Alert\*\Data\RedAlert.dll` timestamps -> picks "newest" as $recommended. Prints "Newest profile detected: Stable".
- **Interactive/omitted $Profile** (ps1:423): If no -P, builds $list from $Profiles.Keys enum order (insertion: Experimental, Stable, Vanilla-Plus), prompts, defaults on bad input to `$list[0]` (Experimental). Even if "announced Stable", a non-numeric/empty Read-Host or order quirk can finalize on Vanilla-Plus.
- **Provided -P:** Respected (`if(-not $Profiles.ContainsKey($Profile))` error else use it), but many runs omit or use wrapper that triggers auto.
- **Deploy always profile-specific** (ps1:536): `Deploy-Profile $script:SelectedProfile.DevPath $...LivePath` (e.g. always Aeloria-Stable live for that profile). Copies **entire folder** (including whatever DLL is sitting in that dev profile's Data/).
- **AutoDeploy** (ps1:137,523): `-A` copies *build output* into the *selected* profile's dev Data/RedAlert.dll (then deploy propagates). `-A -B` builds then deploys.
- **Pollution vectors:**
  - Different profile DLLs have different sizes/timestamps (Stable post-13:20: 1250816; Exp larger with "advanced" bits; Vanilla May).
  - Rebuilds + -A target only selected; but if selection flips (newest changes, interactive default), wrong profile gets fresh DLL or stale one deployed.
  - NoCleanup + sibling live: .bat relies on pre-existing live `Aeloria-Stable/` contents (from prior ps1 deploy). A "stable" .bat after a ps1 that finalized Vanilla leaves live Stable with old/polluted bits (or user sees "no mods" if ccmod/GameConstants mismatch or Steam cached wrong folder).
  - Scripts/ has RedAlert.dll; build outputs in bin/Win32/; multiple baks.
  - Direct .bat never invokes ps1 (good for "simple"), but depends on prior correct deploy. User "launched stable but got vanilla" + "no mods were working" matches deploying/copying the wrong profile's folder/DLL (size/timestamp) into the Aeloria-Stable live path that MOD=Aeloria-Stable consumes.
- **v145 forcing:** Always in ps1 (Get-MSBuildPath + /p:PlatformToolset=v145) and vcxproj; matches "for struct/ODR/early-object compatibility".

## 6. Compiler/ABI Hazard Root vs. Guard Symptom (Precise)

**Root cause (ABI/packing hazard):** 
- Legacy C++ classes (InfantryClass : public FootClass : ... ObjectClass : AbstractClass) use multiple inheritance + virtuals (vptr at 0) + CCPtr<Class> member declared first in derived (INFANTRY.H:42 `CCPtr<InfantryTypeClass> Class;`).
- vcxproj forces `<PlatformToolset>v145</PlatformToolset>` + `<StructMemberAlignment>1Byte</StructMemberAlignment>` (/Zp1) "for packing hygiene" post-ODR issues.
- But: construction order (new InfantryClass(...) in bulk during Read_INI / house setup while ScenarioInit), member init, vtable layout, and exact offset of `Class` (intended at ~+8 for the peek) **still produce transient garbage at the runtime +8 offset** for freshly Unlimbo'd objects on first Draw_It / Map.Render frames. (Evidence: Aeloria_Debug_Log "at+8=0x00080000" / 0x80xxxx in every session; offsetof diagnostics in DLLInterface.cpp:1476; comments in OBJECT.H:278 "some objects ... still reaching the first Map.Render() with a plausible declared Class.Raw() but garbage at the runtime offset"; "the drawing pipeline ... still assumes a legacy memory layout for the Class pointer inside instance objects during the narrow 'objects placed but not fully initialized' window after CNC_Start_Instance_Variation".)
- This is **not** random corruption; it's deterministic early-lifecycle layout/ctor timing hazard exacerbated (or exposed) by the 2026 packing changes. Affects starting units most (bulk create + immediate render) + custom maps/4p/AI houses.

**Guard (symptom treatment, not root fix):**
- Prevents crash X: The +8 peek + Is_Plausible in Class_Is_Valid / Cell prune / CC_Draw "last-line defense" stops deref of garbage Class* (or effective pointer) into Get_Image_Data / VirtualScale / IsTheater / Techno_Draw_Object / Buffer_Frame_To_Page / C# interop blitter (which would AV or corrupt). OutputDebugString + early return + (in CC) 16x16 feed keeps game alive. Matches "packing hygiene + granular early Class pointer diagnosis + +8 guard band-aid".
- **Also destroys visibility for starting units Y:** Legit early objects (Rifle Infantry, Light Tank, AI equivalents) hit the heuristic during the "narrow window", get pruned (Cell/Draw_It), never reach DLL_Draw_Intercept/registration. Even 16x16 path (when hit) feeds `width=16, height=16` instead of real sprite dims + full Class_Of data; client sees no (or broken) entry in ObjectList. Result: map loads, but "NO UNITS VISIBLE", unselectable, "nothing to play", eventual user kill or secondary crash. (Matches v1 notes "known limitation of the guard approach"; "pragmatic layer, not root fix".)
- 16x16 is **insufficient for playability**: (a) rarely reached (prunes earlier), (b) wrong size breaks client sprite rendering/selection rects, (c) no guarantee of correct AssetName/ShapeIndex/IsSelectable/etc. in all paths, (d) no "successful real draw" promotion to bypass later. Interop bridge assumes objects provide valid data on first Draw; guard violates that for early objects.
- Distinction: Guard == crash mitigation (necessary short-term); visibility destruction == side-effect of blanket early rejection without stability/epoch/grace. Root requires ctor/layout fix (e.g. ensure Class set before Submit/Unlimbo, or move effective ptr read, or epoch flag in objects, or relax guard for known-good RTTI during init frames).

## 7. Why Current State Fails NORTH STAR + Recommendations (Non-Handwavy)

- **Fails play:** Starting units (infantry+vehicles, player+AI) invisible on custom 4p skirmish. "THE GAME DOES NOT CURRENTLY PLAY". Even Vanilla-Plus (May DLL) + post-rebuild Stable show it. 0.5-60s runs match early-phase guard triggers.
- **Launcher exacerbates:** Newest logic + interactive default + profile-specific deploys + NoCleanup + direct .bat dependency on live state = "launched stable but got vanilla" + DLL pollution. "Simple .bat just works" only if live Aeloria-Stable was last populated from correct dev bits.
- **Evidence-based:** Every rejection path traced to +8/Is_Plausible/Is_Drawable (OBJECT.H:304, INFANTRY.H:147, CELL.CPP:1291, CONQUER.CPP:3450, DLLInterface.cpp:3469). Logs show at+8 garbage + guard passed only for non-units or post-grace DLLs. Submodule pin + rebuilds confirm source/DLL mismatch for "advanced" features.
- **Immediate risks:** Rebuilds (ps1 -B) or ps1 runs regress Stable to pure band-aid. Crashes still occur (zips captured).

**For lead synthesizer / human takeover:**
- The guard (and 16x16) must be **temporary**; root is ABI ctor/layout (not "more guards").
- Restore/ port the missing grace/exemption/per-object logic from experimental history (or reimplement: e.g. frame counter or ScenarioInit grace that trusts What_Am_I + ID + Class.Raw() >0 even on bad +8 for first N renders; promote on first successful full-size DLL_Draw; special-case human houses).
- Consider ctor changes: ensure Class= initialized before Unlimbo in placement code; or defer Submit until post-init.
- Launcher: Make -P required or robust default; always verify deployed DLL size/timestamp matches expected profile; separate "dev build" from "stable deploy" artifacts; add explicit "force this profile's DLL" without newest scan.
- Test: 4p skirmish with infantry+vehicles+AI; watch Aeloria_Debug.log for "guard passed" + real (non-16) CC_Draw on starting units + client-visible entries; 5+ min no-crash.
- After fix: delete band-aid (as OBJECT.H:298 comments), update release notes.

**Files/lines cited (absolute in workspace):**
- OBJECT.H:304-318 (Is_Plausible), 333-346 (Is_Drawable)
- CONQUER.CPP:3434-3469, 3472-3507 (CC_Draw overloads +16x16)
- DLLInterface.cpp:3464-3811 (DLL_Draw_Intercept), 4012-4072 (Convert_Type), 1472-1485 (first-render diagnostics)
- CELL.CPP:1286-1299 (prune), 1356 (Draw_It)
- INFANTRY.H:135-157, UNIT.H:156-174, etc. (Class_Is_Valid +8)
- INFANTRY.CPP:565-597 (Draw_It), 2398-2432 (Unlimbo)
- OBJECT.CPP:1510-1530 (base Unlimbo + IsInLimbo=false + Submit)
- RedAlert.vcxproj:35/99 (v145 + /Zp1)
- Scripts/Launch-Aeloria.ps1:226 (Get-Newest), 432 (default list[0]), 536 (Deploy)
- Logs/Launch-Aeloria_20260607_132019_589.log (newest Stable + build + 46s + NoCleanup)
- Docs/10-Aeloria-Stable-v1-Release-Notes.md:80 (known invisible limitation)

This is the complete, evidence-backed diagnosis. The 16x16 + guard is the visible symptom of an unaddressed ABI window; without root or compensating stability, "YOU launch, I play" is impossible on current stable pin + rebuilds.

(End of report. Ready for synthesis + fix implementation.)