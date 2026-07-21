# Asset provenance

`asset_register.csv` is the source of truth for production-owned, AI-assisted, and third-party source/runtime assets. Run `py -3 tools/validate_assets.py` on Windows or `python3 tools/validate_assets.py` elsewhere before release.

The validator resolves every registered file and document reference strictly after symlink expansion, enforces repository and boundary containment, and rejects canonical/case-insensitive duplicate asset targets. It also rejects missing files, duplicate IDs, unknown or missing licenses, license references outside `docs/assets/licenses/`, AI references outside `docs/assets/`, incomplete attribution/provenance, unregistered assets, and concept-art references from Godot resources.

Runtime PNG validation parses the complete chunk stream, verifies every CRC, requires ordered `IHDR`, `IDAT`, and `IEND`, validates zlib completion and exact decoded scanline size/filter bytes, and rejects dimensions above 2048×2048.

When adding an asset:

1. Put concepts under `source_art/concepts/` or runtime-ready content under `game/assets/runtime/`.
2. Add a unique register row and preserve its license notice.
3. For AI-assisted work, add the prompt or a faithful prompt record to `ai_prompts.md`.
4. Run the validator and Godot import checks.
