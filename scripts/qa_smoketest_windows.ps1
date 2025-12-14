Param(
    [string]$PortableRoot = "",
    [switch]$ExpectCuda
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

function Invoke-CudaProbe {
    Param([string]$PythonExe)
    try {
        $cudaProbeScript = @"
import json, torch
try:
    import torch
    import torch.cuda as tc
except Exception as exc:
    print(json.dumps({'error': f'torch import failed: {exc}'}))
    raise
info = {
    'version': torch.__version__,
    'cuda_available': torch.cuda.is_available(),
    'cuda_version': torch.version.cuda,
}
info['device_name'] = tc.get_device_name(0) if tc.is_available() else None
print(json.dumps(info))
"@
        $probe = & $PythonExe -c $cudaProbeScript
        $probeExitCode = $LASTEXITCODE
        if ($probeExitCode -ne 0 -or -not $probe) {
            Write-Warning "CUDA probe failed to return data (exit code $probeExitCode)."
            return $null
        }
        return $probe | ConvertFrom-Json
    }
    catch {
        Write-Warning "CUDA probe threw: $_"
        return $null
    }
}

function Invoke-CpuSmokeTest {
    Param(
        [string]$PythonExe,
        [string]$ComfyMain,
        [string]$PortableRoot
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logPath = Join-Path $PortableRoot "qa_smoketest-$timestamp.log"

    $args = @(
        "-s", "-B", $ComfyMain,
        "--windows-standalone-build",
        "--cpu",
        "--quick-test-for-ci",
        "--disable-auto-launch"
    )

    Write-Host "Starting CPU smoketest with log at $logPath"
    & $PythonExe @args 2>&1 | Tee-Object -FilePath $logPath | Out-Null
    $exitCode = $LASTEXITCODE

    $logContent = Get-Content -Path $logPath -Raw
    if ($exitCode -ne 0) {
        throw "ComfyUI quick test exited with code $exitCode. See log: $logPath"
    }

    if ($logContent -match "Traceback \(most recent call last\)" -or $logContent -match "ModuleNotFoundError:" -or $logContent -match "ImportError:") {
        $snippet = $logContent.Substring(0, [Math]::Min($logContent.Length, 400))
        throw "Detected import error or traceback in log: $logPath`nSnippet:`n$snippet"
    }

    Write-Host "CPU smoketest completed successfully. Log: $logPath"
}

$portableRootPath = Resolve-PortableRoot -RootArg $PortableRoot
$pythonExe = Join-Path $portableRootPath "python_standalone/python.exe"
$comfyMain = Join-Path $portableRootPath "ComfyUI/main.py"

if (-not (Test-Path -Path $pythonExe)) {
    throw "python_standalone not found at $pythonExe"
}

if (-not (Test-Path -Path $comfyMain)) {
    throw "ComfyUI/main.py not found at $comfyMain"
}

# Set portable-friendly environment
$env:HF_HUB_CACHE = Join-Path $portableRootPath "HuggingFaceHub"
$env:TORCH_HOME = Join-Path $portableRootPath "TorchHome"
$env:PYTHONPYCACHEPREFIX = Join-Path $portableRootPath "pycache"
$env:PATH = "$($env:PATH);$portableRootPath\MinGit\cmd;$portableRootPath\python_standalone\Scripts"

if (-not (Test-Path -Path $env:HF_HUB_CACHE)) { New-Item -ItemType Directory -Path $env:HF_HUB_CACHE -Force | Out-Null }
if (-not (Test-Path -Path $env:TORCH_HOME)) { New-Item -ItemType Directory -Path $env:TORCH_HOME -Force | Out-Null }

$cudaInfo = Invoke-CudaProbe -PythonExe $pythonExe
if ($cudaInfo) {
    Write-Host ("torch {0}, CUDA available: {1}, device: {2}, cuda_version: {3}" -f $cudaInfo.version, $cudaInfo.cuda_available, $cudaInfo.device_name, $cudaInfo.cuda_version)
    if ($ExpectCuda -and -not $cudaInfo.cuda_available) {
        throw "GPU mode expected but torch.cuda.is_available() is False."
    }
}
elseif ($ExpectCuda) {
    throw "GPU mode expected but CUDA probe failed."
}

Invoke-CpuSmokeTest -PythonExe $pythonExe -ComfyMain $comfyMain -PortableRoot $portableRootPath

Write-Host "QA smoketest finished without errors."
