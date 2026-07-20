#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS export not attempted: macOS is required." >&2
  exit 2
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "iOS export not attempted: Xcode command-line tools are unavailable." >&2
  exit 2
fi

godot_bin="${GODOT_BIN:-godot}"
if ! command -v "${godot_bin}" >/dev/null 2>&1; then
  echo "iOS export not attempted: Godot is unavailable at '${godot_bin}'." >&2
  exit 2
fi

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
game_root="${repository_root}/game"
output_path="${game_root}/builds/ios/game_ghost.zip"
mkdir -p "$(dirname "${output_path}")"
"${godot_bin}" --headless --path "${game_root}" --export-debug "iOS" "${output_path}"
echo "IOS_XCODE_PROJECT_EXPORT_OK: ${output_path}"
