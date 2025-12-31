$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "accel_helpers.ps1")

function Test-SkipFlag {
  param(
    [string]$Value
  )
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }
  $normalized = $Value.Trim().ToLowerInvariant()
  return ($normalized -eq "1" -or $normalized -eq "true" -or $normalized -eq "yes")
}

function Invoke-PipInstall {
  param(
    [string]$Python,
    [string]$Label,
    [string[]]$Arguments
  )
  Write-Host "=== $Label ==="
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $output = ""
  $stderr = ""
  try {
    & $Python -s -m pip @Arguments 1> $stdoutPath 2> $stderrPath
  } finally {
    $output = (Read-TextFileSafe -Path $stdoutPath).TrimEnd()
    if (Test-Path $stderrPath) {
      $stderrRaw = Read-TextFileSafe -Path $stderrPath
      $stderr = $stderrRaw.Trim()
      Remove-Item -Path $stderrPath -Force
    }
    if (Test-Path $stdoutPath) {
      Remove-Item -Path $stdoutPath -Force
    }
  }
  if ($output) {
    Write-Host $output
  }
  $exitCode = $LASTEXITCODE
  return @{
    Success = ($exitCode -eq 0)
    ExitCode = $exitCode
    Stdout = $output
    Stderr = $stderr
    Version = $null
  }
}

function Get-PackageVersion {
  param(
    [string]$Python,
    [string]$PackageName
  )
  $version = (& $Python -c "import importlib.metadata as m; print(m.version('$PackageName'))" 2>&1 | Out-String).TrimEnd()
  if ($LASTEXITCODE -ne 0) {
    return $null
  }
  return $version
}

function Test-PackageImport {
  param(
    [string]$Python,
    [string[]]$ImportNames
  )
  $payload = (ConvertTo-Json -Compress -InputObject @($ImportNames))
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
  $script = @"
import base64, importlib, json, sys
names = json.loads(base64.b64decode('$encoded'))
if isinstance(names, str):
    names = [names]
errors = []
for name in names:
    try:
        importlib.import_module(name)
    except Exception as exc:
        errors.append(f"{name}: {exc}")
if errors:
    print("; ".join(errors))
    sys.exit(1)
print("OK")
"@
  $output = (& $Python -c $script 2>&1 | Out-String).TrimEnd()
  if ($LASTEXITCODE -eq 0) {
    return @{ Success = $true; Error = $null }
  }
  return @{ Success = $false; Error = $output }
}

function Test-TorchNightlyCu130 {
  param(
    [string]$Python
  )
  $script = @"
from packaging.version import Version, InvalidVersion
import sys, torch

ver = getattr(torch, "__version__", None)
if not ver or not isinstance(ver, str):
    sys.exit(1)
base = ver.split("+", 1)[0]
try:
    parsed = Version(base)
except InvalidVersion:
    sys.exit(1)
if parsed < Version("2.10.0.dev0"):
    sys.exit(1)
if "cu130" not in ver:
    sys.exit(1)
print(ver)
"@
  $output = (& $Python -c $script 2>&1 | Out-String).TrimEnd()
  $exitCode = $LASTEXITCODE
  $success = ($exitCode -eq 0)
  return @{
    Success = $success
    ExitCode = $exitCode
    Output = $output
    Version = if ($success) { $output } else { $null }
  }
}

function Invoke-TorchGuard {
  param(
    [string]$Python,
    [string]$Root,
    [string]$Label
  )
  Write-Host "=== Verifying torch after $Label ==="
  $check = Test-TorchNightlyCu130 -Python $Python
  if ($check.Success) {
    Write-Host "Torch $($check.Version) verified"
    return
  }
  $checkDetails = if ($check.Output) { $check.Output } else { "exit $($check.ExitCode)" }
  Write-Warning "Torch check failed after $Label ($checkDetails); restoring from pak3.txt"
  $pak3 = Join-Path $Root "pak3.txt"
  & $Python -s -m pip install --force-reinstall --no-deps -r $pak3
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to restore PyTorch from $pak3"
    return
  }
  $recheck = Test-TorchNightlyCu130 -Python $Python
  if ($recheck.Success) {
    Write-Host "Torch $($recheck.Version) recovery verified"
  } else {
    $recheckDetails = if ($recheck.Output) { $recheck.Output } else { "exit $($recheck.ExitCode)" }
    Write-Warning "Torch recovery verification failed ($recheckDetails)"
  }
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$python = Join-Path $root "python_standalone/python.exe"
$manifestPath = Join-Path $root "accel_manifest.json"
$skipCoreAttention = Test-SkipFlag $env:SKIP_CORE_ATTENTION

if ($skipCoreAttention) {
  Write-Warning "Skipping core attention installs because SKIP_CORE_ATTENTION is set."
  @() | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestPath -Encoding utf8
  Write-Host "Wrote attention manifest to $manifestPath"
  exit 0
}

if (-not (Test-Path $python)) {
  throw "Python executable not found at $python"
}

$aiWindowsWhlJson = if ($env:AI_WINDOWS_WHL_WHEELS_JSON_URL) {
  $env:AI_WINDOWS_WHL_WHEELS_JSON_URL
} else {
  "https://raw.githubusercontent.com/wildminder/AI-windows-whl/main/wheels.json"
}
$torchInfo = Get-TorchInfoFromPython -Python $python
$pythonTag = $null
if ($torchInfo) {
  $pythonTag = Get-PythonTag -PythonVersion $torchInfo.python_version
  if (-not $pythonTag) {
    Write-Warning "Unsupported python version $($torchInfo.python_version) for AI-windows-whl filtering."
  }
} else {
  Write-Warning "Unable to read torch/python metadata for AI-windows-whl filtering."
}

$packages = @(
  [pscustomobject]@{
    Name = "flash-attn"
    VersionName = "flash-attn"
    ImportNames = @("flash_attn")
    SourceSpec = "flash-attn"
    AiPattern = "flash[_-]attn"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "Source build not feasible on Windows runner."
  },
  [pscustomobject]@{
    Name = "flash_attn_3"
    VersionName = "flash-attn-3"
    ImportNames = @("flash_attn_3")
    SourceSpec = "flash-attn-3"
    AiPattern = "flash[_-]attn[_-]?3"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "flash_attn_3 wheel unavailable for this build."
  },
  [pscustomobject]@{
    Name = "sageattention"
    VersionName = "sageattention"
    ImportNames = @("sageattention")
    SourceSpec = "sageattention"
    AiPattern = "sageattention"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "Source build not feasible on Windows runner."
  },
  [pscustomobject]@{
    Name = "sageattention2"
    VersionName = "sageattention2"
    ImportNames = @("sageattention2", "sageattention")
    SourceSpec = "sageattention2"
    AiPattern = "sageattention2"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "Source build not feasible on Windows runner."
  },
  [pscustomobject]@{
    Name = "triton-windows"
    VersionName = "triton-windows"
    ImportNames = @("triton")
    SourceSpec = "triton-windows<3.6"
    AiPattern = "triton[_-]windows"
    Required = $false
    AllowSourceBuild = $true
    SourceReason = $null
  }
)

$results = @()

$sageattention2ppSpec = $env:SAGEATTENTION2PP_PACKAGE
if ($sageattention2ppSpec) {
  $sageattention2ppVersionName = ($sageattention2ppSpec -split "[<>=! ]")[0]
  $packages += [pscustomobject]@{
    Name = "sageattention2pp"
    VersionName = $sageattention2ppVersionName
    ImportNames = @("sageattention2pp", "sageattention2", "sageattention")
    SourceSpec = $sageattention2ppSpec
    AiPattern = "sageattention2pp"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "SageAttention2++ wheel unavailable for this build."
  }
} else {
  $results += [pscustomobject]@{
    name = "sageattention2pp"
    version = $null
    source = "unsupported"
    success = $false
    url = "none"
    gate_reason = "unsupported (SAGEATTENTION2PP_PACKAGE not set)"
    error_if_any = "unsupported (SAGEATTENTION2PP_PACKAGE not set)"
  }
  Write-Warning "GATED: sageattention2pp unsupported (SAGEATTENTION2PP_PACKAGE not set)"
}

foreach ($package in $packages) {
  $success = $false
  $source = "none"
  $errors = @()
  $version = $null
  $selectedUrl = $null
  $gateReason = $null
  $stderrExcerpt = $null
  $requestedSpec = "source_spec=$($package.SourceSpec); pattern=$($package.AiPattern)"

  $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from PyPI (binary-only)" -Arguments @("install", "--no-deps", "--only-binary", ":all:", $package.SourceSpec)
  if ($installAttempt.Success) {
    $source = "pypi"
    $success = $true
    $errors = @()
    $selectedUrl = "none"
    $stderrExcerpt = Get-Excerpt -Text $installAttempt.Stderr
  } else {
    $stderrExcerpt = Get-Excerpt -Text $installAttempt.Stderr
    $errors += "pip exit $($installAttempt.ExitCode): $($installAttempt.Stdout)"
  }

  if (-not $success) {
    $resolved = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern $package.AiPattern -IndexJsonUrl $aiWindowsWhlJson -TorchInfo $torchInfo -PythonTag $pythonTag -AllowAbi3
    if ($resolved.url) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from AI-windows-whl wheel URL" -Arguments @("install", "--no-deps", $resolved.url)
      if ($installAttempt.Success) {
        $source = $resolved.source
        $success = $true
        $errors = @()
        $selectedUrl = $resolved.url
        if (-not $stderrExcerpt) {
          $stderrExcerpt = Get-Excerpt -Text $installAttempt.Stderr
        }
      } else {
        $stderrExcerpt = Get-Excerpt -Text $installAttempt.Stderr
        $errors += "pip exit $($installAttempt.ExitCode): $($installAttempt.Stdout)"
      }
    } else {
      $gateReason = if ($resolved.reason) { $resolved.reason } else { "AI-windows-whl wheel unavailable" }
      $errors += $gateReason
    }
  }

  if (-not $success) {
    if ($package.AllowSourceBuild) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from source" -Arguments @("install", "--no-binary", ":all:", $package.SourceSpec)
      if ($installAttempt.Success) {
        $source = "source"
        $success = $true
        $errors = @()
        $selectedUrl = "none"
        if (-not $stderrExcerpt) {
          $stderrExcerpt = Get-Excerpt -Text $installAttempt.Stderr
        }
      } else {
        $stderrExcerpt = Get-Excerpt -Text $installAttempt.Stderr
        $errors += "pip exit $($installAttempt.ExitCode): $($installAttempt.Stdout)"
      }
    } else {
      $errors += $package.SourceReason
    }
  }

  if ($success) {
    $importAttempt = Test-PackageImport -Python $python -ImportNames $package.ImportNames
    if (-not $importAttempt.Success) {
      $success = $false
      $errors += $importAttempt.Error
    } else {
      $version = Get-PackageVersion -Python $python -PackageName $package.VersionName
    }
  }

  Invoke-TorchGuard -Python $python -Root $root -Label "$($package.Name) install"

  if ($success) {
    $postGuardImport = Test-PackageImport -Python $python -ImportNames $package.ImportNames
    if (-not $postGuardImport.Success) {
      $success = $false
      $version = $null
      $errors += "Post-guard import check failed: $($postGuardImport.Error)"
    } else {
      $version = Get-PackageVersion -Python $python -PackageName $package.VersionName
    }
  }

  $errorMessage = if ($errors.Count -gt 0) { ($errors -join " | ") } else { $null }
  if (-not $success -and -not $gateReason) {
    $gateReason = $errorMessage
  }

  $results += [pscustomobject]@{
    name = $package.Name
    requested = $requestedSpec
    version = $version
    source = $source
    success = $success
    gated = (-not $success)
    url = if ($selectedUrl) { $selectedUrl } else { "none" }
    gate_reason = $gateReason
    error_if_any = $errorMessage
    stderr_excerpt = $stderrExcerpt
  }

  if (-not $success) {
    Write-Warning "GATED: $($package.Name) not available ($errorMessage). Marked as gated in accel_manifest.json."
    if ($package.Required) {
      throw "$($package.Name) is required but failed to install"
    }
  } else {
    Write-Host "$($package.Name) installed successfully ($version) via $source"
  }
}

$results | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestPath -Encoding utf8
Write-Host "Wrote attention manifest to $manifestPath"

Write-AccelSummary -Title "Core attention" -Results $results
