# Game Ghost 2D Top-Down Roguelite Vertical Slice Design

## Product

Game Ghost is a landscape, offline, mobile-first room-based action roguelite. The first playable slice stars Ember Vanguard in a forest biome. The player moves with a virtual joystick, automatically attacks the nearest valid target, and manually activates dash and one active skill.

A run lasts 8-12 minutes across 5-7 rooms. Combat rooms lead to a three-choice upgrade reward, with an elite encounter and a telegraphed boss ending the run. The initial build excludes accounts, networking, ads, purchases, leaderboards, and cloud saves.

## Gameplay

- Ember uses automatic rifle fire, dash invulnerability, and a short active burst skill.
- Enemy archetypes are melee chaser, ranged shooter, and telegraphed charger. The boss combines readable aimed shots and charges.
- Upgrade paths emphasize fire rate and multishot, piercing and ricochet, burn damage, and dash cooldown.
- Forest rooms include concealing grass, blocking rivers with bridges, slowing mud, and trees that block movement and projectiles.
- The run is won by defeating the boss and lost when Ember reaches zero health.

## Architecture

Godot 4.6.3 Standard with typed GDScript is the only runtime. Data-only `.tres` resources define characters, weapons, enemies, upgrades, and rooms. Focused components own health, targeting, weapons, and movement; typed signals report lifecycle events. `RunController` owns room progression. Autoloads are limited to session state, local save, and audio.

Source art and runtime assets are separated. Concept images are references, not sprites. Runtime visuals use a modular four-direction body, independent weapon, ribbons, and effects; the graybox uses programmatic shapes until the layered source art exists.

## Quality

GUT covers deterministic gameplay logic and save recovery. Scene smoke tests cover combat and room progression. CI runs headless tests and resource validation. Android export is configured on Windows; iOS export remains an unverified preset until macOS, Xcode, signing credentials, and an iPhone are available.

