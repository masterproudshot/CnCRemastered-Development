# 10 - Development Process & Deployment Checklist

**Project:** Project Aeloria  
**Purpose:** Define a repeatable, high-quality process for feature development and mod delivery.

---

## Core Principles

- **Code Quality First**: All code must be solid, well-structured, and well-documented before being considered complete.
- **Configuration Discipline**: All Aeloria-specific settings live under dedicated `[Aeloria*]` sections.
- **End-to-End Verification**: A feature is not "done" until it has been built, packaged, loaded, and tested in-game.
- **Submodule Integrity**: All code changes must be properly committed inside the submodule before the parent repo is updated.
- **Clear Separation**: Development work (in `Development/`) is distinct from live mod folders (`Documents/CnCRemastered/Mods/`).

---

## Development Workflow

### Phase 1: Planning & Design
- Create or update a design note in `Docs/` when tackling a new feature area.
- Define which settings will live in which `[Aeloria*]` section.

### Phase 2: Implementation
- Make changes inside the `Rampastring-MoreQoL` submodule.
- Use clear, descriptive helper methods and consistent naming.
- Add or update comments explaining the "why" behind changes.

### Phase 3: Configuration
- Add or update the relevant `[Aeloria*]` section in `RULES.CPP` and `RULES.H`.
- Prefer the Aeloria section over legacy `[MoreQoL]`.

### Phase 4: Verification Notes
- Update or create the corresponding verification notes document (e.g., `04-Rally-Point-System-Verification-Notes.md`).
- Include test cases that cover both normal and edge-case behavior.

### Phase 5: Build & Package
- Build in **Release + x86** with **PlatformToolset=v145** (2017-era struct compatibility).
- Primary build tree (2026-06-20): `worktrees/bon-5k-5/CnCRemastered.sln` → `worktrees/bon-5k-5/bin/Win32/RedAlert.dll`.
- Legacy path: `Source/Rampastring-MoreQoL` submodule (may lag active worktree).
- Copy the resulting `RedAlert.dll` into the mod’s `Data/` folder.
- Ensure all required files exist:
  - `ccmod.json`
  - `Data/RedAlert.dll`
  - `GameConstants_Mod.xml` (when relevant)
  - Any other required XML/INI files

### Phase 6: In-Game Testing
- Use the appropriate launcher (Experimental / Stable).
- **Debug soaks:** `.\Scripts\Launch-Aeloria.ps1 -Profile Experimental -DebugMode -NoCleanup`
- **Post-session gate:** `.\Scripts\Analyze-AeloriaSoak.ps1 -Profile P4` (checks max frame, Windows AV, abrupt tail).
- P4 north-star gate: `max_frame ≥ 7500`, no `REDALERT.DLL` access violation in Windows Application log.
- Test using the verification notes as a checklist.
- Confirm the mod name appears and features behave as expected.

#### Soak ladder (north-star profiles)

Run sessions with `Launch-Aeloria.ps1`; pass `-LauncherLog` to the analyzer when correlating WER/quit vs crash.

| Step | Profile | Launcher | Analyzer | Gate |
|------|---------|----------|----------|------|
| P1 debug | P1 | `-Profile Experimental -DebugMode -NC` | `-Profile P1 -LauncherLog <launcher.log>` | max_frame ≥ 7500, no abrupt tail, no WER/AV |
| P4 perf | P4 | `-Profile Experimental -NC` (no `-D`; `AELORIA_QUIET=1` default) | `-Profile P4 -LauncherLog <launcher.log>` | max_frame ≥ 7500, lines/frame ≤ ~3, LAYERS summary clean |
| P3 long | P3 | `-Profile Experimental -DebugMode -NC` (20+ min) | `-Profile P3` | max_frame ≥ 27000, tank unlimbos ≥ 2 |
| NS north star | NS | `-Profile Experimental -NC` (20–30 min wall clock) | `-Profile NS -LauncherLog <launcher.log>` | max_frame ≥ 40000, wall clock ≥ 20 min |

**User gates (wave checklist — `Docs/AELORIA-STATUS-WAVES.md`):**
- **G-W7a:** After WAVE-5 — 5+ min post-Start skirmish (Fix-M1); P4 or P1 analyzer PASS with `Session end: GRACEFUL_QUIT` (not `LIKELY_CRASH`).
- **G-W7b:** After WAVE-6 — 20–30 min `Launch-Aeloria.ps1 -Profile Experimental -NC`, then `Analyze-AeloriaSoak.ps1 -Profile P4 -LauncherLog Logs\Launch-Aeloria_<session>.log`; all gates green, no WER snippet.

### Phase 7: Commit & Record
- Commit changes **inside the submodule first**.
- Then commit the parent repo (including updated submodule pointer and docs).
- Use clear, descriptive commit messages.

---

## Mod Packaging Requirements (Per Mod)

Every Aeloria mod folder must contain at minimum:

- `ccmod.json` (with correct name, description, `load_order`, and `game_type`)
- `Data/RedAlert.dll`
- `GameConstants_Mod.xml` (for zoom features)
- Any feature-specific files as defined in verification notes

---

## Deployment Checklist (Before Declaring "Ready to Play")

- [ ] All code changes committed inside the submodule (or documented worktree → submodule merge)
- [ ] Parent repo updated with new submodule pointer
- [ ] Git working tree is clean (no uncommitted line-ending noise; `.gitattributes` present in root and submodule; `git status` shows only intentional changes)
- [ ] `ccmod.json` is valid and present
- [ ] `RedAlert.dll` copied to `Data/` folder (verify byte size matches expected build — e.g. 1,295,360 for 5z-n2)
- [ ] `GameConstants_Mod.xml` present (if zoom features are expected)
- [ ] Mod launches via launcher without crashing
- [ ] **P4 soak PASS:** `Analyze-AeloriaSoak.ps1 -Profile P4` all gates green
- [ ] Custom 4p Aeloria skirmish: starting units visible + harvester production tested
- [ ] Core features from verification notes have been manually tested in a match
- [ ] No other mods are enabled (or only intended ones)
- [ ] `Docs/AELORIA-STATUS-*.md` and `SESSION-HANDOFF.md` updated
- [ ] Verification notes document has been updated

---

## Process Anti-Patterns to Avoid

- Making code changes without committing inside the submodule.
- Declaring a feature "done" based only on compilation success.
- Forgetting to copy the built DLL into the mod folder.
- Skipping the in-game smoke test.
- Leaving `GameConstants_Mod.xml` or other data files out of the mod package.
- Ignoring line-ending noise or dirty submodules (use `.gitattributes` + `git add --renormalize` to keep the tree clean across WSL + Windows).

---

**Document Owner:** Jackson  
**Last Updated:** June 2026  
**See also:** `Docs/AELORIA-STATUS-20260620.md`, `SESSION-HANDOFF.md`

---

*Good process is what turns ambition into reliable delivery.* — Project Aeloria