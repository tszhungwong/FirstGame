# Local GUT patches

GUT 9.6.0 is vendored unchanged except for three font `ext_resource` declarations in `gui/GutSceneTheme.tres`, `gui/NormalGui.tscn`, and `gui/MinGui.tscn`.

Their upstream UIDs belong to another Godot import cache and are invalid in a fresh Game Ghost checkout. The declarations retain the same upstream font paths and resource IDs but omit those stale UIDs, preventing Godot 4.6.3 from emitting fallback warnings. Recheck this patch when upgrading GUT.
