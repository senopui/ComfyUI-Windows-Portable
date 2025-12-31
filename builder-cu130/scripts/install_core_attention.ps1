$ErrorActionPreference = "Stop"

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
  $output = (& $Python -s -m pip @Arguments 2>&1 | Out-String).TrimEnd()
  $exitCode = $LASTEXITCODE
  return @{
    Success = ($exitCode -eq 0)
    ExitCode = $exitCode
    Output = $output
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

function Parse-JsonSafe {
  param(
    [Parameter(Mandatory = $true)]
    $RawOutput,
    [string]$Source
  )

  $rawString = if ($RawOutput -is [string]) {
    $RawOutput
  } else {
    [string]::Join("`n", $RawOutput)
  }
  $trimmed = ($rawString -replace "^\uFEFF", "").Trim()
  $preview = if ($trimmed.Length -gt 200) { $trimmed.Substring(0, 200) } else { $trimmed }

  if (-not $trimmed) {
    Write-Warning "JSON parse skipped for ${Source}: empty response."
    return [pscustomobject]@{
      ok = $false
      reason = "empty response"
      raw_preview = $preview
      source = $Source
    }
  }

  if (-not ($trimmed.StartsWith("{") -or $trimmed.StartsWith("["))) {
    $reason = if ($trimmed.StartsWith("<")) { "HTML response detected" } else { "non-JSON output detected" }
    Write-Warning "JSON parse skipped for ${Source}: $reason."
    return [pscustomobject]@{
      ok = $false
      reason = $reason
      raw_preview = $preview
      source = $Source
    }
  }

  try {
    $parsed = $trimmed | ConvertFrom-Json
    return [pscustomobject]@{
      ok = $true
      data = $parsed
      source = $Source
    }
  } catch {
    Write-Warning "JSON parse failed for ${Source}: $($_.Exception.Message)"
    return [pscustomobject]@{
      ok = $false
      reason = "ConvertFrom-Json failed: $($_.Exception.Message)"
      raw_preview = $preview
      source = $Source
    }
  }
}

function Test-PackageImport {
  param(
    [string]$Python,
    [string[]]$ImportNames
  )
  $payload = ($ImportNames | ConvertTo-Json -Compress)
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

function Get-TorchInfo {
  param(
    [string]$Python
  )
  $script = @"
import json
import sys
import torch
from packaging.version import Version, InvalidVersion

ver = getattr(torch, "__version__", None)
if not ver or not isinstance(ver, str):
    sys.exit(1)
base = ver.split("+", 1)[0]
try:
    parsed = Version(base)
except InvalidVersion:
    sys.exit(1)
info = {
    "torch_version": base,
    "torch_major": parsed.major,
    "torch_minor": parsed.minor,
    "torch_is_dev": bool(parsed.is_devrelease),
    "python_version": f"{sys.version_info.major}.{sys.version_info.minor}"
}
print(json.dumps(info))
"@
  $raw = (& $Python -c $script 2>&1 | Out-String).TrimEnd()
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    return $null
  }
  $parsed = Parse-JsonSafe -RawOutput $raw -Source "Get-TorchInfo (python metadata)"
  if (-not $parsed.ok) {
    Write-Warning "Torch metadata JSON invalid: $($parsed.reason)."
    return $null
  }
  return $parsed.data
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

function Resolve-WildminderWheelUrl {
  param(
    [string]$Python,
    [string]$PackagePattern,
    [string]$IndexJsonUrl,
    [pscustomobject]$TorchInfo,
    [string]$PythonTag
  )
  Write-Host "=== Resolving AI-windows-whl wheel from $IndexJsonUrl (pattern: $PackagePattern) ==="
  if (-not $TorchInfo) {
    Write-Warning "Torch info unavailable; skipping Wildminder resolver."
    return $null
  }
  try {
    $page = Invoke-WebRequest -Uri $IndexJsonUrl -UseBasicParsing
    $payloadRaw = ($page.Content 2>&1 | Out-String).TrimEnd()
    $parsed = Parse-JsonSafe -RawOutput $payloadRaw -Source "Resolve-WildminderWheelUrl $IndexJsonUrl"
    if (-not $parsed.ok) {
      Write-Warning "Wildminder index JSON invalid: $($parsed.reason)."
      return $null
    }
    $payload = $parsed.data
    $packages = @($payload.packages | Where-Object { $_.id -match $PackagePattern -or $_.name -match $PackagePattern })
    if ($packages.Count -eq 0) {
      Write-Warning "No Wildminder package entries matched pattern '$PackagePattern'"
      return $null
    }

    $pythonVersion = $TorchInfo.python_version
    $torchMajor = $TorchInfo.torch_major
    $torchMinor = $TorchInfo.torch_minor
    $torchIsDev = [bool]$TorchInfo.torch_is_dev

    $candidates = @()
    foreach ($pkg in $packages) {
      foreach ($wheel in @($pkg.wheels)) {
        if (-not $wheel.url) {
          continue
        }
        if ($wheel.python_version -ne $pythonVersion) {
          continue
        }
        if ($wheel.url -notmatch "win_amd64") {
          continue
        }
        if ($PythonTag -and ($wheel.url -notmatch $PythonTag)) {
          continue
        }
        $cudaNorm = ($wheel.cuda_version -replace "\.", "")
        if ($cudaNorm -ne "130") {
          continue
        }
        $torchVersion = $wheel.torch_version
        if (-not ($torchVersion -match "^$torchMajor\\.$torchMinor")) {
          continue
        }
        if ($torchIsDev -and ($torchVersion -notmatch "dev")) {
          continue
        }
        if (-not $torchIsDev -and ($torchVersion -match "dev")) {
          continue
        }
        $candidates += [pscustomobject]@{
          url = $wheel.url
          package_version = $wheel.package_version
          torch_version = $torchVersion
        }
      }
    }

    if ($candidates.Count -eq 0) {
      Write-Warning "No Wildminder wheels matched python $pythonVersion, $PythonTag, cu130, torch $torchMajor.$torchMinor."
      return $null
    }

    $sorted = $candidates | Sort-Object -Property @{Expression = { [version]$_.package_version }}, @{Expression = { $_.torch_version }}, @{Expression = { $_.url } }
    return $sorted[-1].url
  } catch {
    Write-Warning "Failed to query Wildminder AI-windows-whl index: $($_.Exception.Message)"
  }
  return $null
}

function Resolve-AIWindowsWheelUrlFromIndex {
  param(
    [string]$Python,
    [string]$PackagePattern,
    [string]$IndexUrl
  )
  Write-Host "=== Resolving AI-windows-whl wheel from $IndexUrl (pattern: $PackagePattern) ==="
  try {
    $page = Invoke-WebRequest -Uri $IndexUrl -UseBasicParsing
    $links = [regex]::Matches($page.Content, 'href="([^"]+\.whl)"') | ForEach-Object { $_.Groups[1].Value }
    $matches = $links | Where-Object { $_ -match $PackagePattern }
    if ($matches.Count -gt 0) {
      $payload = ($matches | ConvertTo-Json -Compress)
      $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
      $script = @"
import base64
import json
from packaging.tags import sys_tags
from packaging.utils import parse_wheel_filename

links = json.loads(base64.b64decode("$encoded"))
tag_set = {str(tag) for tag in sys_tags()}
compatible = []
for link in links:
    filename = link.rsplit("/", 1)[-1]
    try:
        _, _, _, wheel_tags = parse_wheel_filename(filename)
    except Exception:
        continue
    if any(str(tag) in tag_set for tag in wheel_tags):
        compatible.append(link)

print("\n".join(compatible))
"@
      $filtered = (& $Python -c $script 2>&1 | Out-String).TrimEnd()
      if ($LASTEXITCODE -eq 0 -and $filtered) {
        $matches = $filtered -split "`r?`n"
      } elseif ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to filter AI-windows-whl wheels by tag; falling back to unfiltered list."
      }
    }
    $matches = $matches | Sort-Object
    if ($matches.Count -gt 0) {
      $candidate = $matches[-1]
      if ($candidate -match '^https?://') {
        return $candidate
      }
      return "$IndexUrl$candidate"
    }
    Write-Warning "No wheel links matched pattern '$PackagePattern'"
  } catch {
    Write-Warning "Failed to query AI-windows-whl index: $($_.Exception.Message)"
  }
  return $null
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

$aiWindowsWhlJson = "https://raw.githubusercontent.com/wildminder/AI-windows-whl/main/wheels.json"
$aiWindowsIndex = "https://ai-windows-whl.github.io/whl/"
$torchInfo = Get-TorchInfo -Python $python
$pythonTag = $null
if ($torchInfo) {
  $pythonTag = switch ($torchInfo.python_version) {
    "3.13" { "cp313" }
    "3.12" { "cp312" }
    default { $null }
  }
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
    error_if_any = "unsupported (SAGEATTENTION2PP_PACKAGE not set)"
  }
  Write-Warning "GATED: sageattention2pp unsupported (SAGEATTENTION2PP_PACKAGE not set)"
}

foreach ($package in $packages) {
  $success = $false
  $source = "none"
  $errors = @()
  $version = $null

  $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from PyPI (binary-only)" -Arguments @("install", "--no-deps", "--only-binary", ":all:", $package.SourceSpec)
  if ($installAttempt.Success) {
    $source = "pypi"
    $success = $true
    $errors = @()
  } else {
    $errors += "pip exit $($installAttempt.ExitCode): $($installAttempt.Output)"
  }

  if (-not $success) {
    $wildminderUrl = Resolve-WildminderWheelUrl -Python $python -PackagePattern $package.AiPattern -IndexJsonUrl $aiWindowsWhlJson -TorchInfo $torchInfo -PythonTag $pythonTag
    if ($wildminderUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from Wildminder AI-windows-whl" -Arguments @("install", "--no-deps", $wildminderUrl)
      if ($installAttempt.Success) {
        $source = "wildminder-ai-windows-whl"
        $success = $true
        $errors = @()
      } else {
        $errors += "pip exit $($installAttempt.ExitCode): $($installAttempt.Output)"
      }
    } else {
      $errors += "Wildminder AI-windows-whl wheel unavailable"
    }
  }

  if (-not $success) {
    $aiUrl = Resolve-AIWindowsWheelUrlFromIndex -Python $python -PackagePattern $package.AiPattern -IndexUrl $aiWindowsIndex
    if ($aiUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from AI-windows-whl index" -Arguments @("install", "--no-deps", $aiUrl)
      if ($installAttempt.Success) {
        $source = "ai-windows-whl-index"
        $success = $true
        $errors = @()
      } else {
        $errors += "pip exit $($installAttempt.ExitCode): $($installAttempt.Output)"
      }
    } else {
      $errors += "AI-windows-whl index wheel unavailable"
    }
  }

  if (-not $success) {
    if ($package.AllowSourceBuild) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from source" -Arguments @("install", "--no-binary", ":all:", $package.SourceSpec)
      if ($installAttempt.Success) {
        $source = "source"
        $success = $true
        $errors = @()
      } else {
        $errors += "pip exit $($installAttempt.ExitCode): $($installAttempt.Output)"
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

  $results += [pscustomobject]@{
    name = $package.Name
    version = $version
    source = $source
    success = $success
    gated = (-not $success)
    error_if_any = $errorMessage
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

Write-Host "=== Core attention summary ==="
$results | Select-Object name, version, source, success | Format-Table -AutoSize
