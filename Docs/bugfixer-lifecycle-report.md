# Bugfixer Lifecycle Report: Starting Units Invisible in Custom 4p Skirmish (Red Alert Remastered)

**Date:** 2026-06-07 (analysis on 3e53e4c + local patch)  
**Charter:** Object creation, Unlimbo, house/player assignment, early scenario init, drawing registration for Remastered interop (Westwood engine internals).  
**NORTH STAR:** Player's (and AI's) starting infantry/vehicles must appear as real, selectable objects on the tactical map within first 5-10s of skirmish load, support move/shoot/build for normal game duration, without guard layer destroying registration.  
**User symptoms:** "infantry units are still invisible", "none of my units were showing up", "no yellow box". Map loads but units do not.

All claims grounded in on-disk code reads (full files + targeted greps across Source/Rampastring-MoreQoL/REDALERT/). TIBERIANDAWN side has no equivalent guards/bandaids in this pin (grep for Is_Plausible_Class_Pointer/Aeloria returned 0 hits there). Analysis targets REDALERT (RA DLL + GlyphX interop).

## Verified Files Read (Key Excerpts + Paths)
- **OBJECT.H** (core guards, states, Is_Plausible_Class_Pointer, Is_Drawable template): lines 55-348 (ObjectClass flags: IsDown, IsInLimbo, IsToDisplay; Class_Is_Valid base; full Is_Plausible + bandaid comments; Is_Drawable calling Class_Is_Valid + Get_Image_Data).
- **INFANTRY.H/.CPP** (Class_Is_Valid +8 peek, ctor, Unlimbo, Draw_It, Read_INI creation): H:135-157 (Class_Is_Valid override with *(this+8) + Is_Plausible + OutputDebug reject); CPP:177-212 (ctor: `Class(InfantryTypes.Ptr(classid))`, Tracking_Add, IsInLimbo from base), 2398-2432 (Unlimbo calls Foot), 565-597 (Draw_It: `if(!Is_Drawable(this)) return; ... Techno_Draw_Object`), 3485-3583 (Read_INI: `new InfantryClass`, log "CREATED: ... Class.Raw=%ld", Unlimbo, human-mission special case), 3520 (Aeloria creation log).
- **UNIT.H/.CPP** (symmetric guards/Draw): analogous Class_Is_Valid +8, Draw_It at 2087- (guards + logs), creation logs at 4992.
- **TECHNO.CPP** (Unlimbo, Techno_Draw_Object, CC_Draw calls): 1243-1256 (Techno::Unlimbo: Radio:: + Enter_Idle_Mode + Commence), 4469-4573 (Techno_Draw_Object: for VISUAL_ calls `CC_Draw_Shape(this, shapefile, shapenum, ..., window, ...)`; VIRTUAL special for hidden), 4547/4684 etc (the two overload paths).
- **FOOT.CPP** (Unlimbo chain): 1085-1106 (Foot::Unlimbo: Techno:: + Revealed(House)).
- **OBJECT.CPP** (base Unlimbo, states): 1510-1540 (Object::Unlimbo: `if(GameActive && IsInLimbo && !IsDown){ if(ScenarioInit || Can_Enter_Cell){ IsInLimbo=false; ... if(Mark(MARK_DOWN)){ Map.Submit(this, In_Which_Layer()); if(sentient) Logic.Submit(); } } }`), ctor inits IsInLimbo(true).
- **HOUSE.CPP** (human detection, no draw guards): PlayerPtr usage, IsHuman/IsPlayerControl set in GlyphX path, no Is_Plausible/human exemption.
- **CONQUER.CPP** (CC_Draw_Shape guards + 16x16 + DLL calls, ScenarioInit kludge): 3434-3507 (two CC_Draw_Shape(Object*): always `at_plus_8 = *( (char*)object +8 )`; `if(!Is_Plausible(at_plus_8)){ Aeloria... REJECTED...; if(object) DLL_Draw_Intercept(shapenum,x,y,16,16,flags,object,...,(char)object->Owner()); return; }`; then `if(window==WINDOW_VIRTUAL){ DLL... full } else real CC_Draw`), 238 (ScenarioInit=0 kludge in Main_Game), 2729+ (DLL_Draw_Intercept decl), first-render related.
- **DLLInterface.cpp** (interop, draw registration, Convert_Type, GlyphX_Assign_Houses, creation paths, Aeloria log + offsets): 3444- (DLL_Draw_Intercept wrapper), 3464- (impl: `Convert_Type(object,new_object); if(UNKNOWN) return; ... CNCInternalObjectPointer=object; ... strncpy TypeName/AssetName from object->Class_Of().IniName/Graphic_Name(); ... Width/Height/ShapeIndex/IsSelectable=Class_Of().IsSelectable etc from full object;`), 4012-4072 (Convert_Type: switch on What_Am_I() -> sets INFANTRY/UNIT etc + ID from lists; no Class deref), 3861- (Get_Layer_State: `for layer { for obj in Map.Layer[layer] { if(IsActive && (Debug|| (IsDown && !IsInLimbo))) { CurrentDrawCount=0; object->Draw_It(x,y,WINDOW_VIRTUAL); ... TotalObjectCount += CurrentDrawCount; } } }`), 1093-1286 (GlyphX_Assign_Houses: sets IsHuman/IsPlayerControl/PlayerPtr for index0, houses MULTI1+, no unit creation here), 1471-1485 (FIRST RENDER log + `Map.Render()` + offsetof logs for Class in Infantry/Unit/etc), 7386 (ScenarioInit++ around some MP house logic), 8473 (debug spawn example: new+Unlimbo), 594 (Aeloria_Debug_Log impl, includes `[ScenarioInit] ` prefix + flush).
- **SCENARIO.CPP** (early init, Read, Create_Units, GlyphX path): 474 (Read_Scenario: ScenarioInit++ / Read_Scenario_INI / --), 2612-2615 (in Read_Scenario_INI: `save=ScenarioInit; ScenarioInit=0; Create_Units(...); ScenarioInit=save;` for !Debug), 2375 (GlyphX_Assign_Houses call for !normal), 2997+ (Create_Units for non-base MP: tables for E1/E2 etc + Unlimbo), 3485+ indirect via Read_INI.
- **Other supporting:** CELL.CPP:1286-1298 (cell draw prep prunes with Is_Drawable on all RTTI before Sort_Y/Draw), TECHNO.H/INFANTRY.H etc for Class: `CCPtr<InfantryTypeClass> Class;` (offset 42 in Infantry), House: `CCPtr<HouseClass> House;`, Abstract/RTTI, Map.Layer submit, etc. No g_HumanPlayerHouse, FORCED_STABLE, REAL_FIRST, HUMAN_EARLY, AeloriaObjectStability, post-render fixup, or PLAYER_EXEMPTION_FRAME_COUNT=18000 etc in checkout (grep returned nothing; user notes they were in later experimental forward pointer).

Grep strategies used: broad for Unlimbo/ScenarioInit/Draw_It/CC_Draw_Shape/DLL_Draw_Intercept/Is_Plausible/Class_Is_Valid/Is_Drawable/g_HumanPlayerHouse/human.*exempt/IsHuman + narrow per-file reads for call chains + creation logs. Multiple locations (REDALERT/ only for guards; SCENARIO/HOUSE/DLL for init/house).

## Object Lifecycle Timeline (Creation to First Visible Draw Registration)
Grounded in Unlimbo/ObjectClass flags + Read_INI + GlyphX + Get_Layer_State + Draw_It paths. Starting rifleman (typical E1 for human house in 4p skirmish/custom map) example; symmetric for vehicles (UNIT_C::ctor/Unlimbo/Draw_It) + buildings/AI/neutral.

1. **Early Scenario Init (ScenarioInit >=1):** `Read_Scenario(name)` (SCENARIO:474) -> `Read_Scenario_INI` (under ++). For placed units in custom map INI (or Create_Units for official MP): `InfantryClass::Read_INI` (INFANTRY:3518): `infantry = new InfantryClass(classid, inhouse);` (house = e.g. HOUSE_MULTI1 for player 0 in 4p).
   - Ctor (INFANTRY:178-212): `FootClass(RTTI_INFANTRY, ID, house)` (chains to Techno/Radio/Abstract: sets RTTI, IsActive, IsInLimbo=true from OBJECT:134 ctor init, House=CCPtr), `Class(InfantryTypes.Ptr(classid))` (CCPtr init to TypeClass*), `House->Tracking_Add(this);`, `Strength=Class->MaxStrength; Ammo=...; IsSecondShot=...`. **Aeloria log: "CREATED: Infantry classid=%d house=%d Class.Raw=%ld"** (often shows plausible Raw at this instant). IsInLimbo remains true.
   - Similar for UnitClass::Read_INI + new UnitClass.
   - For GlyphX MP 4p: GlyphX_Assign_Houses (DLL:1093+) runs pre-Read (sets IsHuman/IsPlayerControl/PlayerPtr for first, MULTI houses); then INI Read creates for all houses (human + AI).

2. **Unlimbo (still under ScenarioInit >0 in most paths):** `if(infantry) { ... infantry->Unlimbo(coord, dir); ... }` (INFANTRY:3567; coord from INI cell + subspot or Create_Units scatter).
   - Infantry::Unlimbo (2398): `coord = Map[...].Closest_Free_Spot(..., ScenarioInit);` `if(FootClass::Unlimbo(coord,facing)) { House->IScan |= ...; if(Sight==0) IsDiscoveredByPlayer=false; Set_Occupy_Bit; return true; }`
   - Foot::Unlimbo (1085): `if(Techno::Unlimbo) { Revealed(House); Path[0]=...; return true; }`
   - Techno::Unlimbo (1243): `if(Radio::Unlimbo(coord,dir)) { PrimaryFacing=dir; Enter_Idle_Mode(true); Commence(); IsLocked=Map.In_Radar(...); return true; }`
   - Object::Unlimbo (1510, base of chain): `if(GameActive && IsInLimbo && !IsDown) { if(ScenarioInit || Can_Enter_Cell(Coord_Cell(coord))==MOVE_OK) { IsInLimbo = false; IsToDisplay=false; Coord=Class_Of().Coord_Fixup(coord); if(Mark(MARK_DOWN)) { if(In_Which_Layer()!=NONE) Map.Submit(this, In_Which_Layer()); if(Class_Of().IsSentient) Logic.Submit(this); return true; } } } return false;`
     - **State transition:** IsInLimbo=false, IsDown=true (via Mark), submitted to Map.Layer[LAYER_GROUND typically for infantry], visible to Logic. **Still under ScenarioInit in Read path (or temp=0 in the Create_Units block at SCENARIO:2613).** House assignment complete (Owner() via House ptr).
   - Post-Unlimbo (infantry Read_INI 3571): `if(Session==NORMAL || House->IsHuman) { Assign_Mission; Commence(); } else Enter_Idle_Mode();` (human special in MP, but creation/Unlimbo/draw path identical for AI).

3. **ScenarioInit winds to 0:** Read_Scenario does -- (499). In Read_Scenario_INI for MP non-debug: temp save/0/Create_Units/-- restore (2612). DLL CNC_Start_Instance_Variation (1330): calls Start_Scenario (which does the above), GlyphX assign, Calculate_Start_Pos, then explicit `Map.Render()` (1485) + "FIRST RENDER AFTER LOAD" Aeloria log + offsetof(Class) dumps (1476: InfantryClass::Class etc).

4. **First client-visible registration opportunity (post-ScenarioInit=0, first render):** Client calls (via CNC_Get_Game_State) trigger Get_Layer_State (DLL:3861) or native render paths.
   - `for(layer) { ExportLayer=...; for(index in Map.Layer[layer]) { ObjectClass* object = ...; if(object->IsActive) { if( IsDown && !IsInLimbo ) { ... CurrentDrawCount=0; object->Draw_It(x,y, WINDOW_VIRTUAL); TotalObjectCount += CurrentDrawCount; } } } }`
   - **For our rifleman:** IsDown && !IsInLimbo is true (from Unlimbo), so Draw_It called. (Native Map.Render also hits layers/cells.)
   - **Infantry::Draw_It (565):** `asserts; if(!Is_Drawable(this)) return;` (no increment to CurrentDrawCount).
     - Is_Drawable<T> (OBJECT.H:333): `if(!obj) false; if(!obj->Class_Is_Valid()) false; if(Get_Image_Data()==NULL) false; return true;`
     - Infantry::Class_Is_Valid (135): `if(!Class.Is_Valid() || Class.Raw()<=0) return false; t=Class; if(!t || t->RTTI!=RTTI_INFANTRYTYPE || t->MaxStrength<=0) false; uintptr_t effective = *(uintptr_t*)((const char*)this + 8); if(!Is_Plausible_Class_Pointer(effective)) { sprintf REJECTED this=%p RTTI Class.Raw at+8=0x%08X; OutputDebugString; return false; } return true;`
   - If +8 bad: guard fires (Aeloria "REJECTED..." only in header via OutputDebug; no "guard passed" log), Draw_It aborts **with 0 DLL calls**. Same prune in CELL.CPP:1291 for native cell draws.
   - **If somehow passes Is_Drawable** (Class checks ok): Get_Image_Data (uses Class), Techno_Draw_Object (WINDOW_VIRTUAL path) -> `CC_Draw_Shape(this, shapefile, shapenum, x,y,window, flags..., rotation, scale);`
   - **CC_Draw_Shape(Object*, shapefile,...)** (CONQUER:3434): `if(object){ at_plus_8=*(obj+8); Aeloria "CC_Draw_Shape got ... at+8=0x%08lx"; if(!Is_Plausible(at_plus_8)){ Aeloria "REJECTED at CC_Draw_Shape (last-line...)"; if(object) DLL_Draw_Intercept(shapenum,x,y,16,16,(int)flags,object,rotation,virtualscale,NULL,(char)object->Owner()); return; } } if(window==VIRTUAL){ ... DLL_Draw_Intercept(shapenum,x,y,width,height,... full); return; } legacy CC_Draw;`
   - (Symmetric 2nd overload at 3472 for name-based.)
   - **DLL_Draw_Intercept (DLL:3464):** `new_object = ...; Convert_Type(object, new_object); if(UNKNOWN) return; ... [base matching for subobjs] new_object.CNCInternalObjectPointer = (void*)object; ... strncpy(TypeName, object->Class_Of().IniName ...); ... AssetName from Class_Of or override; Owner=...; ... IsSelectable=object->Class_Of().IsSelectable; ... Width=height= the passed (16 or full); ShapeIndex=shapenum; ... DimensionX from Class_Of().Dimensions; ...` (then more: Strength, CellX etc, action maps). Added to ObjectList; client sees it.

**Full timeline summary for visibility:** Creation+Unlimbo (IsInLimbo->false, layer submit) succeeds for human/AI houses. First post-0 render/export calls Draw_It only for IsDown+!Limbo. Guard in Is_Drawable/Class_Is_Valid (or CC_Draw) aborts registration -> no entry. Units never "promoted" to client-visible.

## Why Legit Game-Created Objects Have 0x80xxxx Garbage at +8 During First Render
- **Ctor/Unlimbo timing vs render:** Objects created (new + Class=Ptr(type)) + Unlimbo'd while ScenarioInit>0 (suppresses some checks/animations per Westwood pattern). Class.Raw() often good at creation log (3520). ScenarioInit-- then *immediate* Map.Render() (DLL:1485) + Get_Layer_State for client state. "Packing/CCPtr corruption" (per OBJECT.H:276-299 bandaid comments, Stable-v1 notes implied) hits after set-to-0: CCPtr internals or object layout fields get overwritten/transient garbage (0x00/0x80/0x81 high bytes observed in crashes/logs).
- **+8 peek vs actual layout:** Hardcoded in *every* Class_Is_Valid override (INFANTRY.H:146, UNIT.H symmetric, BUILDING.H:303, AIRCRAFT.H:104, etc + TERRAIN/ANIM/BULLET/VESSEL): `effective = *( (char*)this + 8 );` (not `offsetof` or `&Class` or `Class.Raw()`). This is "the runtime offset the drawing code actually dereferences". But:
  - Class member declared early in derived (INFANTRY.H:42: after Foot/Techno bases which have vptrs + many fields like House at TECHNO.H:193).
  - DLL logs explicit `offsetof(InfantryClass, Class)`, `UnitClass::Class` etc (1476) precisely to diagnose declared vs +8.
  - MI/virtuals (Abstract -> Radio -> Techno -> Foot -> Infantry + multiple mixins like Stage/Cargo) + packing changes ("2026 packing/ODR fix") shift data offsets. +8 may read vptr high bytes, House, Coord bits, or padding that transiently holds 0x80xxxx garbage during early post-init render (before full construction or after list compaction).
  - Class.Is_Valid()/Raw() can pass (internal CCPtr storage "plausible") while +8 (deref site) is bad -- exactly the symptom described in bandaid comments. Legit factory-created objects (new via Read_INI/Create_One_Of during house setup for 4p) hit this because creation is bulk/early for many houses (player + AI + neutrals/buildings).
- **4p skirmish exacerbates:** "creates many objects very early for all houses (starting forces + buildings + perhaps neutral)". Custom map places via INI Read_INI (more than official Create_Units). First render window is narrow; no "promote" or fixup between Unlimbo and render.
- No evidence of vtable corruption per se; Class* (TypeClass) target is constructed (One_Time inits before), but *in-object reference* (CCPtr storage or layout) is the victim of packing.

## The 16x16 DLL_Draw_Intercept Feed Does *Not* Result in Client-Visible/Selectable Unit
- **Rarely reached for infantry/vehicles:** Infantry/Unit Draw_It (and Cell prep) call `if(!Is_Drawable(this)) return;` *before* Techno_Draw_Object/CC_Draw. +8 bad in Class_Is_Valid -> prune, CurrentDrawCount unchanged (0), no call to DLL_Draw at all. (CC_Draw guards are "belt-and-suspenders" per comments 3443/3480.)
- **When 16x16 *is* fed (e.g. other paths/direct calls or if Is_Drawable passed but CC +8 failed):** 
  - DLL_Draw_Intercept: Convert_Type succeeds (uses only What_Am_I() + list ID; no Class deref) -> Type=INFANTRY/UNIT.
  - Then *still executes* `object->Class_Of().IniName` (3493), Dimensions etc (later), Owner via object->Owner().
  - Passes width=16,height=16, original shapenum, flags, object ptr, owner override.
  - CNCInternalObjectPointer set to the raw object* (stable across frames if no delete).
  - But: tiny rect -> client (inferred from export: Position/Width/Height/ShapeIndex/IsSelectable from Class_Of, DimensionX/Y) likely renders as 16px dot or skips (not "real unit" sprite). No proper hitbox for "yellow box" selection (relies on full dims + IsSelectable + selection mask). SortOrder/ExportLayer may deprioritize. Sub-object logic (shadows/turrets) skipped.
  - "Feed ... minimal safe entry anyway so the unit can be visible/registered" (comments 3453/3490) is aspirational/incomplete: doesn't produce full-size correct-shapenum entry, and prune prevents for the exact classes (infantry/vehicles) reported broken.
- Ptr remains valid for matching (CNCInternal... compares), but without full registration in first frames, client never sees/selects it. Later frames may "promote" if +8 heals (but doesn't for these).

## Special Casing for Human Player House vs AI/Neutral
- **None in guards or draw paths.** Class_Is_Valid/Is_Drawable/Is_Plausible/CC_Draw checks are uniform (no House/IsHuman/PlayerPtr tests). Is_Drawable called on all Layer objects regardless of owner.
- Human detection exists elsewhere: GlyphX_Assign_Houses sets IsHuman/IsPlayerControl/PlayerPtr (index 0); HOUSE: IsHuman used for mission assignment (INFANTRY:3571 `if(... || House->IsHuman)`), sight, control, sidebar, etc; SCENARIO:2377 `PlayerPtr->IsHuman=true`; CONQUER/HOUSE many IsHuman branches.
- In 4p: human house units (and AI) created identically via same Read_INI path under same ScenarioInit window. "Player never sees their own" explained by lack of exemption + uniform rejection (not AI-only visibility).
- One minor human path: MP humans get mission/Commence vs AI Enter_Idle, but irrelevant to draw registration.

## "Exemption Window" / Grace Implementation: Aspirational, Not Wired
- **No implementation found.** Grep for PLAYER_EXEMPTION_FRAME_COUNT/18000/HUMAN_EARLY/FORCED_STABLE/REAL_FIRST/Is_Player_Exempt/exemption window/grace.*frame/human.*exempt/early.*draw (case-insens) returned 0 relevant hits in REDALERT/ (only unrelated "gracefully" comments in NETDLG/QUEUE/STARTUP).
- Comments in guards (e.g. OBJECT.H:276 "TEMPORARY BAND-AID", Draw_It:571 "Early-out if Class pointer not yet valid (can happen very early during scenario load)", CC_Draw:3442) *claim* the need for visibility mitigations and reference a "long human exemption window" per user notes, but:
  - No code wires any frame counter (Frame global?), ScenarioInit check (beyond creation), or human bypass into Class_Is_Valid/Is_Drawable/Is_Plausible/CC_Draw.
  - Is_Drawable/guards always active post-0.
  - "one-frame grace" etc. not present.
- This matches user: "only 'visibility' mitigations are (a) long human exemption window *mentioned in comments*, (b) the 16x16 ... (c) diagnostic logs." The advanced symbols were "developed later on experimental's forward submodule pointer" -- absent here.
- Result: early objects (exactly the starting forces in custom 4p) are permanently filtered on first render(s), with no recovery path.

## Why Current Guard + 16x16 Results in No Selectable Units (Explains Symptoms)
- Guard layer (added for packing/CCPtr survival post-ScenarioInit=0 + first Map.Render per Stable-v1) over-aggressively prunes *legit* early-created starting units (human + AI) via fragile +8 peek + Is_Drawable in Draw_It/Get_Layer_State.
- 16x16 feed (last-line in CC_Draw only) is unreachable for Infantry/Unit (pruned earlier) and insufficient even when hit (tiny rects, incomplete registration, no yellow box from full Class dims/IsSelectable).
- No human/AI distinction or exemption to let "real" units through to full DLL path.
- Map loads (cells/terrain ok; some objects like buildings may have different offsets/timing), but techno foot units from early bulk creation in 4p never populate ObjectList with valid full entries -> invisible, unselectable, no CNCInternalObjectPointer for input.
- Crash-prevention goal achieved at cost of NORTH STAR (units never visible/selectable/movable).

## Proposed Smallest Change (Lets Real Units Reach Full-Size/Correct-Shapenum DLL Path; Keeps Crash Prevention)
Grounded in the two sites that must be touched for infantry/vehicles to export fully: (1) Is_Drawable/Class_Is_Valid (to avoid prune), (2) CC_Draw_Shape reject (to avoid 16x16 on fallback).

**Minimal diff (prefer Class evidence + full feed for VIRTUAL/remaster path; native blitter still guarded):**

In OBJECT.H (Is_Drawable) + per Class_Is_Valid (e.g. INFANTRY.H:135, copy pattern to UNIT etc):

```cpp
// In Class_Is_Valid (after basic Class.Is_Valid + t checks, before/around +8):
uintptr_t effective = *(uintptr_t*)((const char*)this + 8);
if (!Is_Plausible_Class_Pointer(effective)) {
    // ... existing OutputDebug REJECTED log ...
    // Smallest relaxation: if Class member itself provides plausible evidence, trust it
    // (bypasses fragile +8 layout artifact from packing/MI for early objects).
    // This lets Unlimbo'd starting units (human house or AI) reach Draw_It -> full Techno/CC_Draw.
    // +8 bad is exactly "plausible declared Class.Raw() but garbage at runtime offset" per bandaid comments.
    if (Class.Is_Valid() && Is_Plausible_Class_Pointer((uintptr_t)Class.Raw())) {
        return true;  // proceed to Get_Image_Data / full DLL registration
    }
    return false;
}
return true;
```

In CONQUER.CPP (both CC_Draw_Shape(Object*) ~3450 and ~3487; keep 16x16 only for native safety):

```cpp
if (!Is_Plausible_Class_Pointer(at_plus_8)) {
    Aeloria... REJECTED...
    if (object) {
        if (window == WINDOW_VIRTUAL) {
            // Full size + correct shapenum for client (remaster interop), even on !plausible.
            // Compute dims here or fall to existing VIRTUAL block (restructure to always hit full DLL for VIRTUAL).
            int w = (width > 0 ? width : (shapefile ? Get_Build_Frame_Width(shapefile) : 16));
            int h = (height > 0 ? height : (shapefile ? Get_Build_Frame_Height(shapefile) : 16));
            DLL_Draw_Intercept(shapenum, x, y, w, h, (int)flags, object, rotation, virtualscale, shape_file_name, (char)object->Owner());
        } else {
            DLL_Draw_Intercept(shapenum, x, y, 16, 16, ...);  // tiny only for native blitter protection
        }
    }
    return;
}
```

**Why smallest + safe?**
- Targets only the reject paths (no new flags/members/Frame counters).
- Uses existing Class.Raw() evidence (already validated in Class_Is_Valid; logged at creation) to override fragile +8 when they disagree -- directly addresses "plausible Class.Raw but garbage at +8".
- For VIRTUAL (remaster Get_Layer_State path): full w/h/shapenum/DLL call -> proper CNCObject (dims, selectable, ShapeIndex, CNCInternalObjectPointer) -> visible + yellow box + selection.
- Native path (real blitter) still rejects on !plausible (or uses 16) -> preserves crash-prevention for packing corruption case.
- Applies to *all* starting units (player + AI in 4p) without human-specific (no IsHuman needed; consistent with no such casing today).
- Alternative even smaller (if Class member always sufficient for DLL path): delete the +8 blocks from the 8 Class_Is_Valid overrides entirely (keep only in CC_Draw as last defense before legacy blit); + update 16x16 to full-size on VIRTUAL as above. (Is_Drawable will pass basic Class checks.)
- No impact on ScenarioInit paths or later game (guards remain for transient cases).
- Can be guarded by `#ifdef` or runtime (e.g. `if(Session.Type == GAME_GLYPHX_MULTIPLAYER)`), but unnecessary.

**Test vector:** Custom 4p skirmish map with placed starting infantry/vehicles for human + AI houses; verify within 5-10s: full-size sprites, selectable (yellow box), move/shoot, persist, no new crashes in Aeloria logs or native render.

This restores NORTH STAR while respecting the guard's original purpose. Root cause is over-broad fragile guard on early-lifecycle objects whose only "corruption" is a transient +8/layout mismatch in the first render window after bulk creation under ScenarioInit.

(Report generated from exhaustive tool-assisted reads/greps; absolute paths used in analysis.)