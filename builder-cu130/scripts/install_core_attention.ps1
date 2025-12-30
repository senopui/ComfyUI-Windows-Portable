$ErrorActionPreference = "Stop"

function Invoke-PipInstall {
  param(
    [string]$Python,
    [string]$Label,
    [string[]]$Arguments
  )
  Write-Host "=== $Label ==="
  & $Python -s -m pip @Arguments
  if ($LASTEXITCODE -eq 0) {
    return @{ Success = $true; Error = $null }
  }
  return @{ Success = $false; Error = "pip exited with code $LASTEXITCODE" }
}

function Get-PackageVersion {
  param(
    [string]$Python,
    [string]$PackageName
  )
  $version = & $Python -c "import importlib.metadata as m; print(m.version('$PackageName'))"
  if ($LASTEXITCODE -ne 0) {
    return $null
  }
  return $version.Trim()
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
  $output = & $Python -c $script 2>&1
  if ($LASTEXITCODE -eq 0) {
    return @{ Success = $true; Error = $null }
  }
  return @{ Success = $false; Error = $output.Trim() }
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
  $output = & $Python -c $script 2>&1
  if ($LASTEXITCODE -eq 0) {
    return @{ Success = $true; Version = $output.Trim() }
  }
  return @{ Success = $false; Version = $output.Trim() }
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
  Write-Warning "Torch check failed after $Label ($($check.Version)); restoring from pak3.txt"
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
    Write-Warning "Torch recovery verification failed ($($recheck.Version))"
  }
}

function Resolve-AIWindowsWheelUrl {
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
      $filtered = & $Python -c $script 2>$null
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

if (-not (Test-Path $python)) {
  throw "Python executable not found at $python"
}

$packages = @(
  [pscustomobject]@{
    Name = "flash-attn"
    ImportNames = @("flash_attn")
    SourceSpec = "flash-attn"
    AiPattern = "flash[_-]attn"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "Source build not feasible on Windows runner."
  },
  [pscustomobject]@{
    Name = "sageattention"
    ImportNames = @("sageattention")
    SourceSpec = "sageattention"
    AiPattern = "sageattention"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "Source build not feasible on Windows runner."
  },
  [pscustomobject]@{
    Name = "sageattention2"
    ImportNames = @("sageattention2", "sageattention")
    SourceSpec = "sageattention2"
    AiPattern = "sageattention2"
    Required = $false
    AllowSourceBuild = $false
    SourceReason = "Source build not feasible on Windows runner."
  },
  [pscustomobject]@{
    Name = "triton-windows"
    ImportNames = @("triton")
    SourceSpec = "triton-windows<3.6"
    AiPattern = "triton[_-]windows"
    Required = $false
    AllowSourceBuild = $true
    SourceReason = $null
  }
)

$results = @()

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
    $errors += $installAttempt.Error
  }

  if (-not $success) {
    $aiUrl = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern $package.AiPattern -IndexUrl "https://ai-windows-whl.github.io/whl/"
    if ($aiUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing $($package.Name) from AI-windows-whl" -Arguments @("install", "--no-deps", $aiUrl)
      if ($installAttempt.Success) {
        $source = "ai-windows-whl"
        $success = $true
        $errors = @()
      } else {
        $errors += $installAttempt.Error
      }
    } else {
      $errors += "AI-windows-whl wheel unavailable"
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
        $errors += $installAttempt.Error
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
      $version = Get-PackageVersion -Python $python -PackageName $package.Name
    }
  }

  Invoke-TorchGuard -Python $python -Root $root -Label "$($package.Name) install"

  $errorMessage = if ($errors.Count -gt 0) { ($errors -join " | ") } else { $null }

  $results += [pscustomobject]@{
    name = $package.Name
    version = $version
    source = $source
    success = $success
    error_if_any = $errorMessage
  }

  if (-not $success) {
    Write-Warning "GATED: $($package.Name) not available ($errorMessage)"
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
