Param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot "..")),
    [ValidateSet("cpu", "gpu")]
    [string]$Mode = "cpu",
    [switch]$ExpectGpu
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-PortableRoot {
    param([string]$Base)
    $direct = Join-Path $Base "ComfyUI_Windows_portable"
    $nested = Join-Path $Base "builder/ComfyUI_Windows_portable"
    if (Test-Path $direct) { return (Resolve-Path $direct) }
    if (Test-Path $nested) { return (Resolve-Path $nested) }
    throw "ComfyUI_Windows_portable not found under $Base"
}

$root = Resolve-Path $RootPath
$portableRoot = Resolve-PortableRoot -Base $root
$pythonExe = Join-Path $portableRoot "python_standalone/python.exe"
$comfyMain = Join-Path $portableRoot "ComfyUI/main.py"
$logPath = Join-Path $portableRoot "qa_smoketest.log"

Write-Host "RootPath: $root"
Write-Host "Portable root: $portableRoot"
Write-Host "Python: $pythonExe"

if (-not (Test-Path $pythonExe)) { throw "python_standalone not found at $pythonExe" }
if (-not (Test-Path $comfyMain)) { throw "ComfyUI main missing at $comfyMain" }

function Run-Py {
    param([string[]]$Args)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $pythonExe
    $psi.ArgumentList = $Args
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $portableRoot
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $rc = $proc.ExitCode
    return @{ code = $rc; out = $stdout; err = $stderr }
}

# CUDA detection (best effort)
$gpuCheck = Run-Py -Args @("-s", "-c", @"
import torch
print(f'torch: {getattr(torch, "__version__", "unknown")}')
print(f'cuda_available: {torch.cuda.is_available()}')
print(f'device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none"}')
"@)
Write-Host $gpuCheck.out.Trim()
if ($ExpectGpu -and ($gpuCheck.out -notmatch "cuda_available: True")) {
    Write-Error "GPU mode expected but torch.cuda.is_available() is False"
    exit 2
}

# Quick test (CPU or GPU based on mode)
$modeArgs = if ($Mode -eq "gpu") { @("--cuda-device", "0") } else { @("--cpu") }
$run = Run-Py -Args (@("-s", "-B", $comfyMain, "--quick-test-for-ci") + $modeArgs)
[IO.File]::WriteAllText($logPath, $run.out + "`n`nSTDERR:`n" + $run.err)
Write-Host $run.out
if ($run.code -ne 0) {
    Write-Error "Quick-test failed (exit $($run.code)). See $logPath"
    exit $run.code
}

if ($run.out -match "Traceback" -or $run.err -match "Traceback" -or $run.err -match "ImportError") {
    Write-Error "Traceback detected during smoke test. See $logPath"
    exit 3
}

Write-Host "Smoke test succeeded. Logs: $logPath"
exit 0
