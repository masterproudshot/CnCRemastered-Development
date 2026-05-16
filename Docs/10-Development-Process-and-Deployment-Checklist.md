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
- Build in **Release + Win32** (or x86).
- Copy the resulting `RedAlert.dll` into the mod’s `Data/` folder.
- Ensure all required files exist:
  - `ccmod.json`
  - `Data/RedAlert.dll`
  - `GameConstants_Mod.xml` (when relevant)
  - Any other required XML/INI files

### Phase 6: In-Game Testing
- Use the appropriate launcher (Experimental / Stable).
- Test using the verification notes as a checklist.
- Confirm the mod name appears and features behave as expected.

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

- [ ] All code changes committed inside the submodule
- [ ] Parent repo updated with new submodule pointer
- [ ] `ccmod.json` is valid and present
- [ ] `RedAlert.dll` copied to `Data/` folder
- [ ] `GameConstants_Mod.xml` present (if zoom features are expected)
- [ ] Mod launches via launcher without crashing
- [ ] Core features from verification notes have been manually tested in a match
- [ ] No other mods are enabled (or only intended ones)
- [ ] Verification notes document has been updated

---

## Process Anti-Patterns to Avoid

- Making code changes without committing inside the submodule.
- Declaring a feature "done" based only on compilation success.
- Forgetting to copy the built DLL into the mod folder.
- Skipping the in-game smoke test.
- Leaving `GameConstants_Mod.xml` or other data files out of the mod package.

---

**Document Owner:** Jackson  
**Last Updated:** May 2026

---

*Good process is what turns ambition into reliable delivery.* — Project Aeloria