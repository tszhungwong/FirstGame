# Game Ghost Top-Down Map Samples Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and save two polished 90-degree top-down game map samples whose gameplay terrain is visually understandable without labels.

**Architecture:** Use the built-in image generation tool once per distinct map, with the supplied screenshot treated only as a composition-density reference and `style.md` as the primary art-direction source. Save each selected PNG under `assets/maps/`, then visually inspect both images against the approved design and regenerate only the image that misses a requirement.

**Tech Stack:** Built-in `imagegen`, local PNG assets, Codex image inspection.

## Global Constraints

- Both maps use a true 90-degree top-down camera; no isometric, oblique, or three-quarter viewpoint.
- Use polished 2D chibi game concept art, delicate dark-brown or dark-gray ink outlines, soft watercolor texture, and clean cel shading.
- Use rounded, compact, readable terrain silhouettes with ornate East-Asian fantasy details and restrained light sci-fi accents.
- Do not include characters, UI, text, labels, logos, or watermarks.
- Keep both maps similar in dimensions, detail density, line work, and rendering quality.
- Final deliverables are independent PNG files saved under `assets/maps/`.

---

### Task 1: Grassland and Forest Map

**Files:**
- Create: `assets/maps/grassland-forest-top-down.png`

**Interfaces:**
- Consumes: `style.md`, the approved design spec, and the user screenshot as a loose density reference.
- Produces: a standalone PNG containing visually distinct hiding bushes, blocking river, slowing mud, and attack-blocking trees.

- [ ] **Step 1: Generate the grassland/forest map**

Use built-in image generation with a structured prompt specifying a complete 90-degree top-down arena, distinct grass/bush/river/mud/tree materials, readable routes, and all global constraints.

- [ ] **Step 2: Save the selected PNG**

Copy the generated image into `assets/maps/grassland-forest-top-down.png` without overwriting any unrelated asset.

- [ ] **Step 3: Visually validate the image**

Inspect the saved PNG and verify: exact overhead camera; bushes form identifiable hiding zones; the river interrupts movement; mud reads as a slowing surface; trunks and dense tree canopies read as attack blockers; no characters, UI, text, logo, watermark, or cropped arena edge.

- [ ] **Step 4: Apply one targeted regeneration if required**

If validation fails, regenerate with only the failed constraint strengthened, replace the unaccepted draft, and repeat Step 3.

### Task 2: Abandoned Warehouse Map

**Files:**
- Create: `assets/maps/abandoned-warehouse-top-down.png`

**Interfaces:**
- Consumes: `style.md`, the approved design spec, and the accepted grassland/forest image as the target for dimensions and finish.
- Produces: a standalone PNG containing visually distinct hiding fog, attack-blocking crates, and accelerating conveyor belts.

- [ ] **Step 1: Generate the abandoned warehouse map**

Use built-in image generation with a structured prompt specifying a complete 90-degree top-down warehouse arena, rusted floors, readable fog pockets, solid crate cover, directional conveyor belts, and all global constraints.

- [ ] **Step 2: Save the selected PNG**

Copy the generated image into `assets/maps/abandoned-warehouse-top-down.png` without overwriting any unrelated asset.

- [ ] **Step 3: Visually validate the image**

Inspect the saved PNG and verify: exact overhead camera; pale cyan-gray fog forms identifiable hiding zones; wooden and metal crates read as attack blockers; conveyor direction and speed affordance are visible without text; no characters, UI, labels, logo, watermark, or cropped arena edge.

- [ ] **Step 4: Apply one targeted regeneration if required**

If validation fails, regenerate with only the failed constraint strengthened, replace the unaccepted draft, and repeat Step 3.

### Task 3: Cross-Map Consistency Check

**Files:**
- Verify: `assets/maps/grassland-forest-top-down.png`
- Verify: `assets/maps/abandoned-warehouse-top-down.png`

**Interfaces:**
- Consumes: both accepted map PNGs.
- Produces: two final project-ready map samples with consistent visual direction.

- [ ] **Step 1: Compare the images side by side**

Verify that camera angle, canvas orientation, line weight, watercolor/cel-shaded finish, visual density, and gameplay readability are consistent.

- [ ] **Step 2: Confirm final files**

Run `Get-Item assets/maps/grassland-forest-top-down.png, assets/maps/abandoned-warehouse-top-down.png | Select-Object FullName, Length` and expect both paths with non-zero byte lengths.

- [ ] **Step 3: Report deliverables**

Display both images and report their absolute project paths, the final prompt set, and that the built-in image generation mode was used.
