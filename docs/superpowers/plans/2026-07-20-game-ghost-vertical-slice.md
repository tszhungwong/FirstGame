# Game Ghost Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Follow test-driven development for gameplay behavior.

**Goal:** Deliver a complete offline Godot vertical slice with Ember Vanguard, room combat, upgrades, a boss, local saves, mobile controls, CI, and export presets.

**Architecture:** Use typed GDScript components and data-only Resources. Build runtime scenes from small reusable nodes, use typed signals for combat events, and keep only save, session, and audio services as autoloads.

**Tech Stack:** Godot 4.6.3 Standard, GDScript, GUT 9.6.0, Git LFS, GitHub Actions.

## Global Constraints

- Landscape mobile-first, offline only; no accounts, backend, ads, purchases, rankings, or cloud saves.
- Runtime values come from `.tres` definitions rather than scattered hard-coded configuration.
- All paths are lowercase ASCII snake_case; mock data files start with `mock_` and contain data only.
- Concept art stays under `source_art/`; runtime assets stay under `game/assets/runtime/`.
- Godot 4.6.3 remains pinned until the vertical slice is accepted.
- iOS may be configured but cannot be reported verified without macOS, Xcode, signing, and hardware.

### Task 1: Foundation and Data Contracts

Create the Godot project, GUT plugin, autoload services, input map, data Resource classes, baseline tests, asset registry, export presets, and project documentation. Verify the editor starts headlessly and GUT runs.

### Task 2: Combat Sandbox

Write failing tests for health, targeting, damage, dash cooldown, and projectile pool behavior. Implement Ember movement/auto-fire/dash, three enemy archetypes, bullets, pooling, programmatic graybox visuals, camera, HUD, and touch controls. Verify the combat sandbox runs headlessly.

### Task 3: Run Loop and Forest Rooms

Write failing tests for upgrade application, room completion, save migration/recovery, and run outcomes. Implement 5-7 room progression, reward choices, elite and boss encounters, grass/river/mud/tree mechanics, pause/resume, win/loss, and local save state.

### Task 4: Mobile Presentation and Delivery

Integrate the approved style through palettes, modular Ember layers, readable effects, responsive safe-area UI, performance overlay, audio placeholders, asset provenance checks, Android/iOS presets, and GitHub Actions. Add validation scripts and release documentation.

### Task 5: Verification and Review

Run GUT, Godot parse/import checks, resource validation, headless scene smoke tests, and available export checks. Review the entire branch for spec compliance, performance hazards, hard-coded content, missing licenses, and mobile lifecycle issues.

