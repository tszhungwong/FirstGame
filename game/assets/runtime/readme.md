# Runtime assets

Only runtime-ready assets belong here. The current vertical slice uses programmatic shapes and procedurally synthesized audio, so it has no external runtime media files. Concept art belongs at repository-level `source_art/concepts/` and is never inside Godot's `res://` boundary.

Every runtime media file added here must have a separate entry in `docs/assets/asset_register.csv`; runtime images larger than 2048×2048 are rejected by validation.
