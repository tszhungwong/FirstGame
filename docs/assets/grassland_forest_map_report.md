# Task 1 — Grassland and Forest Map Report

## Delivery

- Final file: `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\source_art\concepts\maps\grassland_forest_top_down.png`
- PNG size: 3,237,616 bytes
- Generation mode: built-in image generation tool (new-image generation; no CLI/API fallback)
- Reference handling: the supplied screenshot was used only to calibrate overall map density. Its characters, UI, layout, palette, and camera composition were explicitly excluded from the prompt.

## Final Prompt

```text
Use case: stylized-concept
Asset type: production-ready standalone top-down arena map for a 2D chibi fantasy game
Input image: Image 1 is density-only reference; do not copy its characters, objects, layout, palette, UI, or camera framing.
Primary request: Create a complete grassland-and-forest tactical arena seen from a strict true 90-degree vertical top-down camera, orthographic-looking, entire arena fully inside frame. Readable connected winding paths form several tactical spaces. A vivid clean blue river snakes vertically through the central third and visibly blocks movement; include exactly two compact functional crossings: one small curved carved-stone bridge and one shallow stepping-stone ford, each clearly usable. Arrange dense dark forest-green rounded bush clusters as distinct hiding zones around paths and open clearings. Include three irregular brown sticky mud pools with viscous shiny swirls, subdued ripples, and small footprints so they visibly read as slowing terrain. Include several large round-canopy trees with visibly substantial circular trunk bases, carefully placed as hard line-of-fire blockers without concealing nearby pathways.
Scene/backdrop: contained natural green grass arena with clean rounded boundary vegetation and an outer earth edge fully visible.
Style/medium: premium polished 2D chibi East-Asian fantasy game concept art; delicate dark-brown ink outlines, slightly heavier outer silhouettes and fine interior details; soft watercolor material texture plus tidy cel shading; rounded compact terrain shapes; detailed centers and controlled uncluttered edges.
East-Asian accents: restrained functional curved stone edging, a few cloud-motif carved stones, and tiny warm bronze fittings only; no architecture dominating the map.
Lighting/mood: evenly lit overhead map rendering only, no cast shadows that imply oblique perspective.
Color palette: natural grass green and deep forest green, vivid river blue, earth brown; saturated colors controlled outside focal details.
Composition/framing: full map visible with a broad open grassland clearing at upper-left, dense bush hiding zones at lower-left and upper-right, a forest pocket at lower-right, routes clearly connecting all regions around or across the river. True overhead plan view—not isometric, not tilted, not three-quarter.
Constraints: no characters, creatures, weapons, UI, text, labels, arrows, logos, watermarks, borders, title cards, pixel art, photorealism, horizon, sky, cutaway walls, vanishing point, or cropped important features. No visual perspective. No words anywhere.
```

## Visual Validation

Inspected the saved PNG at its final destination with the image viewer.

| Requirement | Result |
| --- | --- |
| True 90-degree top-down camera | Pass — all terrain is shown in direct overhead plan view. |
| Complete arena, connected routes, tactical spaces | Pass — winding routes connect clearings and flanking spaces across both riverbanks. |
| Dense rounded hiding bushes | Pass — multiple dark-green rounded bush clusters create distinct hiding zones. |
| River blocks movement with limited crossings | Pass — a central vivid-blue river separates the map; one carved-stone bridge and one stepping-stone ford provide crossings. |
| Sticky slowing mud | Pass — three brown mud pools have glossy viscous swirls, subdued ripples, and footprints. |
| Large tree blockers | Pass — several large, dense-canopy trees visibly include substantial circular trunk bases while paths remain clear. |
| Required visual style | Pass — polished 2D chibi rendering, dark ink outlines, watercolor texture, cel shading, rounded forms, and restrained East-Asian carved-cloud/bronze accents are visible. |
| Prohibited content and perspective | Pass — no characters, creatures, weapons, UI, text, labels, logos, watermarks, borders, sky, horizon, oblique/cutaway view, photorealism, or pixel art observed. |
| Edge safety | Pass — the arena boundary and gameplay features are fully visible; no required feature is cropped. |

## Files Changed

- Added `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\source_art\concepts\maps\grassland_forest_top_down.png`
- Added `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\docs\assets\grassland_forest_map_report.md`

## Concerns

None. The supplied density reference was not reproduced; the final arena has an original river-centered layout and contains no reference-image characters or UI.

## Fix / Revalidation

The first output was replaced after review identified non-plan-view rendering on the arched bridge and several tree trunks. A targeted built-in image edit preserved the accepted arena layout, terrain roles, palette, density, and no-text/no-character constraints while correcting those viewpoint cues.

- Replacement file: `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\source_art\concepts\maps\grassland_forest_top_down.png`
- Replacement PNG size: 3,313,500 bytes
- Generation mode: built-in image generation tool, targeted edit of the first map output

### Targeted Fix Prompt

```text
Use case: precise-object-edit
Asset type: production-ready 2D chibi fantasy arena-map PNG
Input image: Image 1 is the current approved-layout map and is the edit target.
Primary request: Preserve the full current arena composition, central vertical vivid-blue river, two crossing locations, connected pale routes, bush hiding zones, three sticky brown mud pools, palette, dense polished style, map boundary, and all no-text/no-character constraints. Correct ONLY the camera/viewpoint rendering defect.
Mandatory camera correction: redraw the entire image as a strict 90-degree vertical, orthographic, flat plan-view map. Every visible object—bridge, stepping stones, trees, shrubs, riverbanks, rocks, carved cloud stones, flowers, mud pools, grass and props—must be shown from directly overhead as flat top-down silhouettes and top surfaces only. No element may show a vertical side face, façade, wall, arch opening, underside, front-facing trunk, or foreshortening.
Bridge correction: replace the upper-center arched bridge with a flat rectangular-ish curved-edge stone deck seen from directly above, a simple top-surface footprint spanning the river. Its paving seams must remain flat, two-dimensional plan-view marks. Do not draw an arch, rails, parapet side walls, bridge underside, vertical fascia, or visible front edge.
Tree correction: preserve all large trees at their existing locations and scale, but render each as a round canopy seen straight from above. If a trunk is visible, it must only be a small centered circular top-down trunk disk/opening, never a front-facing or vertical trunk wall. Do not create cast shadows that imply height or an oblique view.
Riverbank and prop correction: show rock edges, stones, and bank features only as flat overhead shapes; avoid any depth faces, horizon, vertical height cues, or perspective shadows.
Style: retain premium polished 2D chibi East-Asian fantasy game concept art, delicate dark-brown ink outlines, watercolor texture, tidy cel shading, rounded compact shapes, functional restrained East-Asian accents. Keep the existing natural grass/deep green/blue/brown palette and fine map density.
Constraints: preserve layout and gameplay affordances. No characters, creatures, weapons, UI, text, labels, arrows, logos, watermarks, borders, title cards, pixel art, photorealism, sky, horizon, cutaway walls, vanishing point, tilt, isometric view, three-quarter view, or oblique lighting.
```

### Revalidation Evidence

The replacement was inspected at original detail from its final project path. The river, connected routes, two limited crossings, distinct dark-green bush zones, three viscous footprint-marked mud pools, large tree blockers, polished 2D chibi finish, and no-text/no-character constraints remain present. The bridge is now a flat top-surface paving footprint with no arch façade or underside; large trees are overhead canopies with small centered circular trunk disks only. Riverbanks, stepping stones, rocks, carved stones, and other props appear as plan-view shapes, with no horizon, vertical side walls, front-facing trunks, foreshortening, or oblique cast shadows observed.

## Second Fix / Revalidation

A second, tightly scoped built-in image edit replaced the first revalidated PNG to remove the few remaining lower-edge depth cues. The edit retained the accepted full-map layout, river, crossings, routes, bushes, mud, tree locations, palette, watercolor/cel style, and prohibited-content constraints.

- Replacement file: `C:\Users\user\OneDrive\Documents\Project\Game_Ghost\source_art\concepts\maps\grassland_forest_top_down.png`
- Replacement PNG size: 3,235,662 bytes
- Generation mode: built-in image generation tool, targeted edit of the first revalidated output

### Exact Second-Fix Prompt

```text
Use case: precise-object-edit
Asset type: production-ready 2D chibi East-Asian fantasy top-down arena-map PNG
Input image: Image 1 is the edit target. Preserve it exactly except for the four localized flat-plan-view corrections below.
Preserve exactly: the square full-map layout, all map-edge vegetation, central vertical vivid-blue river, its two existing crossing locations, all connected tan routes, every bush hiding-zone location, all three mud-pool locations, every tree location and canopy size, palette, polished watercolor/cel-shaded style, density, functional carved-stone accents, and no-text/no-character constraints.
1) Upper-center bridge: replace its entire lower dark band, fascia, underside, thickness and all lower-facing thickness on its round corner fixtures. It must be ONLY a flat stone deck footprint across the river, seen at 90 degrees from above: a single 2D polygon with one uniformly weighted outline on all four sides, flat paving-seam marks, and flat round corner ornaments. No bottom edge, no shadow, no extrusion, no sidewall, no arch, no visible depth.
2) Trees: remove every asymmetric brown trunk/root wall that protrudes below or outside a canopy. In particular repair the large tree left of center below the bridge and the large tree in the lower-right central area. Keep only circular overhead canopy silhouettes and, if visible, a very small centered circular brown trunk disk fully enclosed within the canopy. No trunk wall, roots, lower protrusion, or directional shading.
3) Stepping stones and riverbank rocks: redraw all as flat overhead pebble shapes with one uniform full-perimeter outline and gently centered top-surface texture only. Remove every dark lower rim, cylindrical sidewall, lower-edge band, directional shade, extrusion, or thickness cue.
4) Global enforcement: eliminate every asymmetric bottom-edge dark band, lower-facing face, vertical surface, depth extrusion, or downward protrusion anywhere in the map. Every natural feature, prop, bridge, stone, fixture, and bank must be a purely flat orthographic plan-view silhouette/top surface.
Do not otherwise alter or add objects. No characters, creatures, weapons, UI, text, labels, arrows, logos, watermarks, borders, title cards, sky, horizon, photorealism, pixel art, isometric/tilted/three-quarter view, perspective, foreshortening, or cast shadows.
```

### Second Revalidation Evidence

The final replacement was inspected at original detail from its final project path. The upper-center bridge is a single uniformly outlined, flat paving deck with flat circular corner ornaments; it has no lower band, façade, underside, extrusion, or directional shadow. All large trees are overhead round canopies with centered enclosed trunk disks only; no brown root/trunk walls project beneath their canopies. The stepping-stone ford, riverbank rocks, and perimeter stones render as flat full-perimeter plan-view pebble shapes with no cylindrical sidewalls or dark lower rims. Across the map, no asymmetric bottom-edge band or lower-facing vertical surface was observed. The river, two crossings, routes, bush hiding zones, three mud pools, original palette, polished 2D chibi style, and no-text/no-character prohibitions remain intact.
