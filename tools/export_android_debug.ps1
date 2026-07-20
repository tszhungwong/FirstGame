param(
    [string]$GodotPath = "godot"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$gameRoot = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot "game")).Path
if (-not $gameRoot.StartsWith($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Resolved game path escaped repository: $gameRoot"
}

$sdkRoot = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { $env:ANDROID_HOME }
if (-not $sdkRoot) {
    throw "Android export not attempted: ANDROID_SDK_ROOT or ANDROID_HOME is not set."
}
$buildTools = Join-Path $sdkRoot "build-tools"
if (-not (Test-Path -LiteralPath $buildTools -PathType Container)) {
    throw "Android export not attempted: build-tools directory is missing at $buildTools"
}
$installedBuildTools = Get-ChildItem -LiteralPath $buildTools -Directory -ErrorAction Stop
if ($installedBuildTools.Count -eq 0) {
    throw "Android export not attempted: no Android build-tools versions are installed at $buildTools"
}

$godotCommand = Get-Command $GodotPath -ErrorAction Stop
$outputDirectory = Join-Path $gameRoot "builds\android"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
& $godotCommand.Source --headless --path $gameRoot --export-debug "Android" (Join-Path $outputDirectory "game_ghost.apk")
if ($LASTEXITCODE -ne 0) {
    throw "Godot Android debug export failed with exit code $LASTEXITCODE"
}
Write-Output "ANDROID_DEBUG_EXPORT_OK: $outputDirectory\game_ghost.apk"
