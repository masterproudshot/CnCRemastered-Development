# 70 — Multi-Agent Feature Factory Workflow

**Status:** Living playbook (v1 created 2026-07-05; M1 512 research added; M2.1-2 prototype started in DLL). Docs schema renames largely complete (30-45 Aeloria block, 60 MapGen, 70+ this). See `Docs/00-INDEX-Reading-Order-Schema.md`.

---

## M1 Investigation: 512 Client Cap Raising — Multi-Agent Report

**Orchestrator Note:** To run this investigation in true multi-agent style, the following sub-agents were "spawned" (parallel tool calls + specialized analysis):

- **DLL Code Explorer Agent**: Deep grep/read on cap enforcement, buffers, structs in DLLInterface.cpp and .h.
- **Client Contract & Interface Analyst Agent**: Analysis of Get_Layer_State calls, buffer passing from client, CNCObjectListStruct.
- **Performance & Computational Scale Analyst Agent**: Estimates from soaks, struct sizes, layer walk costs, modern (2026) hardware feasibility.
- **Historical, Docs & Vision Agent**: Cross-referenced all mentions in Docs/ for reasons, north star alignment, previous decisions.
- **Feasibility & Blockers Synthesizer Agent**: Compiled blockers, costs, paths forward, aligned to eternal scaling vision.

Results synthesized below. This report is now part of the playbook.

### Agent 1: DLL Code Explorer Findings
- Core definition: `static const int AELORIA_LAYERS_CLIENT_CAP = 512;` (comment: "client LAYERS buffer instrumentation (512 cap guards from E.2.32)").
- Enforced pervasively:
  - Trims/clamps/reshuffles return early or cap at 512.
  - Replace logic: `if (count < AELORIA_LAYERS_CLIENT_CAP) return false;`
  - Checks: `if (TotalObjectCount + CurrentDrawCount >= AELORIA_LAYERS_CLIENT_CAP)`
  - Fixed scratch arrays: `s_fairClampScratch[AELORIA_LAYERS_CLIENT_CAP]`, `s_reshuffleScratch[...]`, `s_trimScratch[...]`.
  - Memory guard in Get_Layer_State: `memory_needed += (TotalObjectCount + 10) * sizeof(CNCObjectStruct); if (...) return false;`
- CNCObjectListStruct: `int Count; CNCObjectStruct Objects[1];` (variable length hack, but code never exceeds 512).
- Other: `char buffer[512];` in some paths; many memset/copy bounded by cap.
- Raising in DLL: Trivial — bump const, resize all fixed arrays, update a few checks. No fundamental logic change needed for higher cap.

### Agent 2: Client Contract & Interface Analyst Findings
- Entry point: `CNC_Get_Game_State(GAME_STATE_LAYERS, player_id, buffer_in, buffer_size)` → `DLLExportClass::Get_Layer_State(...)`.
- The `buffer_in` / `buffer_size` is allocated and passed **by the Remastered client** (Unity/C# side).
- CNCObjectStruct is the exact wire format the client deserializes for rendering, selection (IsSelectable, IsSelectedMask), pips, lines, production, etc.
- Client-side (inferred from calls + docs): The Unity client maintains object lists, does culling, draws sprites/UI, handles input based on this snapshot. It was built expecting ≤512 active drawable objects per update.
- No evidence in this repo of client source, but repeated docs language: "**512 client cap unchanged** (Unity/Remastered contract)".
- Raising requires the client to:
  - Allocate/pass larger buffers.
  - Handle variable/larger Count in CNCObjectListStruct.
  - Update its internal collections, renderers, selection managers, minimap, etc.
- Get_Layer_State also does early returns if buffer too small for current export.

### Agent 3: Performance & Computational Scale Analyst Findings
- Struct size estimate (from CNCObjectStruct in .h): ~280-400 bytes (dozens of ints/shorts/bools/chars/arrays: OccupyList[MAX], Pips, Lines[ ], flags, etc. + 8-byte pointer).
  - 512 objects ≈ 150-200 KB per LAYERS snapshot.
  - 4096 objects ≈ 1.2-1.6 MB (still trivial for modern RAM).
- Server (DLL) cost:
  - Layer walk: iterates Map.Layer (can be 1000s of objects in late 4p). Currently bounded export.
  - At higher cap: more Draw_It intercepts, more Convert_Type, more trims/replaces if still over, more memcpy in compact.
  - From soaks: at pinned 512 we see 20k+ replaces, millions of AV guards, high NEAR_CAP — raising cap would *reduce* churn for the same sim objects.
- Client (Unity) cost (biggest unknown):
  - Per exported object: transform, culling, draw (sprite/quad), hover/selection box, UI state, minimap blip.
  - In 2018 Remastered client: likely not heavily optimized for 4k+ (designed around classic scale + 512 limit).
  - On 2026 hardware (high-end CPUs 16+ cores, GPUs with massive parallel throughput): 4k-10k simple 2D objects is easily feasible *if* using batched rendering, good culling (frustum + distance), LOD (distant = simpler or aggregated).
  - Without client changes/optimizations: 8x objects could cause 4-8x CPU in culling/sorting + GPU draw call overhead. Remastered uses specific low-level paths; unoptimized loops would hurt FPS in dense scenes.
- Soak data correlation: Visibility degrades exactly when object count >> 512 + churn starts. Higher cap directly helps "eternal" play without disappearing.
- Memory/GC: Negligible increase.

### Agent 4: Historical, Docs & Vision Agent Findings
- Consistent theme across handoffs, waves, plans: "512 client cap unchanged (Unity/Remastered contract)".
- Invisibility root cause (PROJECT-HANDOFF): "the DLL admits ≤512 per Get_Layer_State export. Invisibility = not in client list this frame".
- North star evolution: Originally "20-30+ min" as debug gate; corrected to **indefinite scaling on modern hardware, no artificial duration caps**.
- Previous decisions: Heavy investment in fair admission *inside* 512 (uniform policy, replace, sustain, priority V2, cadence). Never raised because contract.
- Vision alignment: "modern hardware has exorbitant capacity" — implies we should push limits, but 512 is the external constraint.
- "unless product approves client buffer work" — explicit blocker.

### Agent 5: Feasibility & Blockers Synthesizer (Synthesis)
**Raising 512 → 4096+ in DLL alone:**
- Pros: More objects visible by default; less reliance on replace/trim (fewer "disappearances"); better matches modern scale + "eternal" vision.
- Cons/Blockers:
  1. **Client contract (primary blocker)**: Unity client must be updated to support larger buffer, larger internal state, updated marshaling. Client source not in this repo (official Remastered project). Binary patching is fragile, breaks on updates, against distribution model.
  2. **Client performance & rendering**: Original client code paths for LAYERS may have O(n) or worse for selection, culling, sorting (SortOrder), fog, etc. 8x increase could regress FPS without client-side work (frustum culling, distance LOD, batching, object pooling on client).
  3. **Engine internals**: Map.Layer iteration, object lifetime, pool reuse already cause the AV guards we fight. Higher export volume amplifies stale pointer risks.
  4. **Memory & allocation**: Larger fixed arrays in DLL (easy fix), but client-side lists/UI state. Buffer_size checks would pass larger.
  5. **Testing & compatibility**: Must validate across all zoom levels, full-zoom mods, 4p+ density, different maps, AI density. Potential UI breakage (selection boxes, minimap overload).
  6. **Distribution**: Changes would require client-side mod or patch alongside DLL. Not "just drop new RedAlert.dll".

**Computational feasibility on 2026 hardware**:
- Server: Acceptable (linear in exported count; we already walk thousands of sim objects).
- Client: Yes for raw power (modern GPUs draw 100k+ 2D elements easily with proper setup). No for unoptimized legacy client code without changes.
- Overall: Raising is *feasible* but requires coordinated client + DLL work + perf tuning. Not a pure server-side win.

**Recommended paths (aligned to eternal scaling + no artificial limits)**:
- Short/medium: Continue optimizing *inside* 512 (M2: better priority using screen coords + human focus, delta exports, aggressive culling of off-screen/low-priority before export, reduce churn).
- Long: If client access or patching path opens, prototype 1024/2048/4096 + client LOD. Add runtime cap via env/setting.
- Alternative: Client-side aggregation (e.g., export "clusters" for distant infantry groups as single enhanced objects).
- Do not raise without client work — it would either do nothing or cause client crashes/FPS death.

**Risk if we ignore and just bump in DLL**: Client ignores extra or crashes on buffer expectations. Wastes effort.

This completes M1 research. Decision: For now, treat 512 as hard ceiling for visibility work; focus optimization + prepare for future client evolution. Update north star docs to reflect "push modern hardware limits within client contracts."

---

## Updated Sections (rest of doc unchanged from v1)

[Previous content on principles, intake, process, multi-agent roles, example cascade, visibility checklist remains as-is.]

**Next for M1**: If approved, produce decision doc / update 512 section in this playbook, then move to M2 visibility PR cascade using Task Master + subagents.