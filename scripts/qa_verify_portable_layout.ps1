Param(
    [string]$PortableRoot = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Resolve-PortableRoot {
    Param([string]$RootArg)
    if ($RootArg) {
        if (-not (Test-Path -Path $RootArg)) {
            throw "Portable root '$RootArg' does not exist."
        }
        return (Resolve-Path $RootArg).Path
    }

    $defaultRoot = Join-Path $PSScriptRoot ".."
    if (-not (Test-Path -Path $defaultRoot)) {
        throw "Unable to determine portable root automatically. Pass -PortableRoot."
    }
    return (Resolve-Path $defaultRoot).Path
}

$portableRootPath = Resolve-PortableRoot -RootArg $PortableRoot

$checks = @(
    @{ Path = "python_standalone"; Type = "Directory"; Description = "Embedded Python runtime" },
    @{ Path = "python_standalone/python.exe"; Type = "File"; Description = "Python executable" },
    @{ Path = "python_standalone/Scripts/ffmpeg.exe"; Type = "File"; Description = "Bundled ffmpeg" },
    @{ Path = "ComfyUI"; Type = "Directory"; Description = "ComfyUI checkout" },
    @{ Path = "ComfyUI/main.py"; Type = "File"; Description = "ComfyUI entrypoint" },
    @{ Path = "ComfyUI/custom_nodes"; Type = "Directory"; Description = "Custom nodes directory" },
    @{ Path = "ComfyUI/extensions"; Type = "Directory"; Description = "Extensions directory" },
    @{ Path = "ExtraScripts"; Type = "Directory"; Description = "ExtraScripts launchers" },
    @{ Path = "MinGit"; Type = "Directory"; Description = "Portable Git" }
)

$missing = @()
foreach ($check in $checks) {
    $fullPath = Join-Path $portableRootPath $check.Path
    $exists = if ($check.Type -eq "File") { Test-Path -Path $fullPath -PathType Leaf } else { Test-Path -Path $fullPath -PathType Container }
    if (-not $exists) {
        $missing += "Missing $($check.Description): $fullPath"
    }
}

if ($missing.Count -gt 0) {
    foreach ($msg in $missing) { Write-Host $msg -ForegroundColor Red }
    throw "Portable layout verification failed: $($missing.Count) required component(s) missing. See above for details."
}

Write-Host "Portable layout verification passed for $portableRootPath"
