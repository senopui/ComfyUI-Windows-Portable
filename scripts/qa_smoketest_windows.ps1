$ErrorActionPreference = "Stop"

function Find-PortableRoot {
    param([string]$Start)
    $candidates = @(
        $Start,
        (Join-Path $Start "ComfyUI_Windows_portable"),
        (Join-Path $Start "builder" "ComfyUI_Windows_portable"),
        (Join-Path $Start "builder-cu130" "ComfyUI_Windows_portable"),
        (Join-Path $Start "builder-cu128" "ComfyUI_Windows_portable")
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "python_standalone" "python.exe") -PathType Leaf -ErrorAction SilentlyContinue) {
            return (Get-Item $c)
        }
    }
    throw "Could not locate ComfyUI portable root."
}

function Assert-NoLogFailures {
    param([string]$LogPath)
    $patterns = @("Traceback", "ImportError", "ModuleNotFoundError", "DLL load failed", "OSError")
    foreach ($p in $patterns) {
        if (Select-String -Path $LogPath -Pattern $p -SimpleMatch -Quiet) {
            throw "Detected '$p' in log $LogPath"
        }
    }
}

$repoRoot = (Split-Path -Parent $PSScriptRoot)
$portableRoot = Find-PortableRoot -Start $repoRoot

$env:HF_HUB_CACHE = Join-Path $portableRoot "hf_cache"
$env:TORCH_HOME = Join-Path $portableRoot "torch_cache"
$env:PYTHONPYCACHEPREFIX = Join-Path $portableRoot "pycache"
$env:PATH = ($env:PATH + ";" + (Join-Path $portableRoot "MinGit" "cmd") + ";" + (Join-Path $portableRoot "python_standalone" "Scripts"))

$python = Join-Path $portableRoot "python_standalone" "python.exe"
$mainPy = Join-Path $portableRoot "ComfyUI" "main.py"
# Allow disabling the standalone flag for environments that do not use the portable launcher (set QA_DISABLE_WINDOWS_STANDALONE=1|true)
$disableStandalone = $env:QA_DISABLE_WINDOWS_STANDALONE
$extraArgs = if ($disableStandalone -in @("1", "true", "TRUE")) { "" } else { "--windows-standalone-build" }

if (-not (Test-Path $python)) { throw "python.exe not found at $python" }
if (-not (Test-Path $mainPy)) { throw "ComfyUI main.py not found at $mainPy" }

$logsDir = Join-Path $portableRoot "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$logPath = Join-Path $logsDir "qa-smoketest.log"

Write-Host "Portable root: $portableRoot"
Write-Host "Log: $logPath"

$infoScript = @"
import torch
print(f"torch version: {torch.__version__}")
print(f"cuda available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"cuda devices: {torch.cuda.get_device_name(0)}")
"@
& $python -c $infoScript

& $python -s -B $mainPy --quick-test-for-ci --cpu $extraArgs *> $logPath
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    Get-Content $logPath | Write-Host
    throw "Smoke test exited with code $exitCode"
}

Assert-NoLogFailures -LogPath $logPath

Write-Host "Smoke test passed. See log at $logPath"
