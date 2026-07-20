# Asset provenance

`asset-register.csv` is the source of truth for production-owned, AI-assisted, and third-party source/runtime assets. Run `py -3 tools/validate_assets.py` on Windows or `python3 tools/validate_assets.py` elsewhere before release.

The validator rejects missing files, duplicate IDs or paths, unknown or missing licenses, incomplete attribution, incomplete AI provenance, unregistered assets, source/runtime boundary errors, concept-art references from Godot resources, unreadable runtime PNGs, and runtime PNG dimensions above 2048×2048.

When adding an asset:

1. Put concepts under `source_art/concepts/` or runtime-ready content under `game/assets/runtime/`.
2. Add a unique register row and preserve its license notice.
3. For AI-assisted work, add the prompt or a faithful prompt record to `ai-prompts.md`.
4. Run the validator and Godot import checks.
