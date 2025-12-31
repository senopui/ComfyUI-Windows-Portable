$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ai_windows_whl_resolver.ps1")

function Write-EnvValue {
  param(
    [string]$Name,
    [string]$Value
  )
  Set-Item -Path "env:$Name" -Value $Value
  if ($env:GITHUB_ENV) {
    "{0}={1}" -f $Name, $Value | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
  }
}

function Get-TorchVersion {
  param([string]$Python)
  $version = & $Python -c "import torch; print(torch.__version__)"
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read torch version."
  }
  return $version.Trim()
}

function Test-TorchNightlyCu130 {
  param([string]$Python)
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

function Try-PipInstall {
  param(
    [string]$Python,
    [string]$Label,
    [string[]]$Arguments
  )
  Write-Host "=== $Label ==="
  & $Python -s -m pip @Arguments
  if ($LASTEXITCODE -eq 0) {
    return $true
  }
  Write-Warning "$Label failed with exit code $LASTEXITCODE"
  return $false
}

function Get-WheelLinks {
  param(
    [string]$IndexUrl,
    [string]$Pattern
  )
  try {
    $page = Invoke-WebRequest -Uri $IndexUrl -UseBasicParsing
    $matches = [regex]::Matches($page.Content, 'href="([^"]+\.whl)"') | ForEach-Object { $_.Groups[1].Value }
    if ($Pattern) {
      $matches = $matches | Where-Object { $_ -match $Pattern }
    }
    $links = @()
    foreach ($match in $matches) {
      if ($match -match '^https?://') {
        $links += $match
      } else {
        $links += "$IndexUrl$match"
      }
    }
    return $links
  } catch {
    Write-Warning ("Failed to query index {0}: {1}" -f $IndexUrl, $_.Exception.Message)
    return @()
  }
}

function Select-CompatibleWheels {
  param(
    [string]$Python,
    [string[]]$WheelUrls,
    [string]$TorchBaseVersion,
    [string]$CudaTag
  )
  if (-not $WheelUrls -or $WheelUrls.Count -eq 0) {
    return @()
  }
  $pattern = "(?i)(torch|pt|pytorch)?[-_.]?$([regex]::Escape($TorchBaseVersion))"
  $filtered = $WheelUrls | Where-Object {
    $name = [IO.Path]::GetFileName($_)
    ($name -match "(?i)$CudaTag") -and ($name -match $pattern)
  }
  if (-not $filtered -or $filtered.Count -eq 0) {
    return @()
  }
  $payload = ($filtered | ConvertTo-Json -Compress)
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
  $output = & $Python -c $script 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to filter xformers wheels by tag: $output"
    return @()
  }
  $lines = ($output | Out-String).TrimEnd()
  if (-not $lines) {
    return @()
  }
  return $lines -split "`r?`n"
}

function Get-PackageVersion {
  param(
    [string]$Python,
    [string]$PackageName
  )
  $version = & $Python -c "import importlib.metadata as m; print(m.version('$PackageName'))" 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $null
  }
  return $version.Trim()
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$python = Join-Path $root "python_standalone/python.exe"
$manifestPath = Join-Path $root "accel_manifest.json"

if (-not (Test-Path $python)) {
  throw "Python executable not found at $python"
}

$torchVersionBefore = Get-TorchVersion -Python $python
Write-Host "Torch before xformers attempt: $torchVersionBefore"

Write-Host "=== Verifying torch CUDA build ==="
& $python -c "import sys, torch; print(torch.__version__, torch.version.cuda); sys.exit(0 if torch.version.cuda else 1)"
if ($LASTEXITCODE -ne 0) {
  Write-Warning "Torch CUDA build metadata missing; skipping xformers attempt."
  Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "0"
  exit 0
}

$torchInfo = Get-TorchInfoFromPython -Python $python
if (-not $torchInfo) {
  Write-Warning "Unable to read torch metadata; skipping xformers attempt."
  Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "0"
  exit 0
}

$torchBase = $torchInfo.torch_version
$cudaTag = $torchInfo.cuda_tag
if (-not $torchBase -or -not $cudaTag -or $cudaTag -ne "cu130") {
  Write-Warning "Torch version/cuda metadata unsupported for xformers (base=$torchBase cuda=$cudaTag); skipping."
  Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "0"
  exit 0
}

$installed = $false
$source = "none"
$errors = @()
$version = $null
$candidateWheel = $null
$selectedUrl = "none"
$gateReason = $null
$explicitWheelUrl = $env:XFORMERS_WHEEL_URL
if ($explicitWheelUrl) {
  Write-Host "Using xformers wheel URL from environment: $explicitWheelUrl"
  $compat = Select-CompatibleWheels -Python $python -WheelUrls @($explicitWheelUrl) -TorchBaseVersion $torchBase -CudaTag $cudaTag
  if ($compat.Count -gt 0) {
    $candidateWheel = $compat[0]
    $source = "explicit-url"
    $selectedUrl = $candidateWheel
  } else {
    $errors += "Explicit xformers wheel URL incompatible with torch $torchBase $cudaTag"
  }
}

if (-not $candidateWheel) {
  $pythonTag = switch ($torchInfo.python_version) {
    "3.13" { "cp313" }
    "3.12" { "cp312" }
    default { $null }
  }
  $resolved = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "xformers" -TorchInfo $torchInfo -PythonTag $pythonTag -AllowAbi3
  if ($resolved.url) {
    $candidateWheel = $resolved.url
    $source = $resolved.source
    $selectedUrl = $resolved.url
  } else {
    $gateReason = if ($resolved.reason) { $resolved.reason } else { "no wheels.json entry for xformers" }
  }
}

if (-not $candidateWheel) {
  $fallbackIndex = $env:XFORMERS_FALLBACK_INDEX_URL
  if ($fallbackIndex) {
    Write-Host "=== Resolving xformers wheels from fallback index: $fallbackIndex ==="
    $fallbackLinks = Get-WheelLinks -IndexUrl $fallbackIndex -Pattern "xformers"
    $fallbackCompat = Select-CompatibleWheels -Python $python -WheelUrls $fallbackLinks -TorchBaseVersion $torchBase -CudaTag $cudaTag
    if ($fallbackCompat.Count -gt 0) {
      $candidateWheel = ($fallbackCompat | Sort-Object)[-1]
      $source = "fallback-index"
      $selectedUrl = $candidateWheel
    } else {
      $errors += "Fallback index provided but no compatible xformers wheels found"
    }
  }
}

if (-not $candidateWheel) {
  $gateReason = if ($gateReason) { $gateReason } else { "no compatible xformers wheel for torch $torchBase ($cudaTag)" }
  $errors += "GATED: $gateReason"
  Write-Warning "GATED: $gateReason. Skipping install."
  $manifestEntry = [pscustomobject]@{
    name = "xformers"
    version = $null
    source = "gated"
    success = $false
    url = $selectedUrl
    gate_reason = $gateReason
    error_if_any = if ($errors.Count -gt 0) { $errors -join " | " } else { $null }
  }
  $existingResults = @()
  if (Test-Path $manifestPath) {
    try {
      $existingResults = Get-Content -Raw $manifestPath | ConvertFrom-Json
    } catch {
      Write-Warning "Failed to read existing manifest at $manifestPath; overwriting."
    }
  }
  $combined = @()
  if ($existingResults) {
    $combined += @($existingResults)
  }
  $combined += $manifestEntry
  $combined | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestPath -Encoding utf8
  Write-Host "Wrote xformers manifest entry to $manifestPath"
  Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "0"
  exit 0
}

$installed = Try-PipInstall -Python $python -Label "Attempting xformers from $source (no deps)" -Arguments @("install", "--no-deps", $candidateWheel)
if (-not $installed) {
  $errors += "pip install xformers ($source) failed"
  if (-not $gateReason) {
    $gateReason = "pip install failed for $source"
  }
}

Write-Host "=== Skipping xformers source build attempt (optional) ==="

$torchVersionAfter = Get-TorchVersion -Python $python
Write-Host "Torch after xformers attempt: $torchVersionAfter"

if ($torchVersionAfter -ne $torchVersionBefore) {
  Write-Warning "Torch version changed after xformers attempt ($torchVersionBefore -> $torchVersionAfter); restoring PyTorch."
  $pak3 = Join-Path $root "pak3.txt"
  & $python -s -m pip install --force-reinstall --no-deps -r $pak3
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to restore PyTorch from $pak3"
  }
  $torchVersionAfter = Get-TorchVersion -Python $python
  if ($torchVersionAfter -ne $torchVersionBefore) {
    Write-Warning "Torch version still differs after restore ($torchVersionBefore -> $torchVersionAfter)"
  }
}

Invoke-TorchGuard -Python $python -Root $root -Label "xformers attempt"
$torchVersionAfter = Get-TorchVersion -Python $python

if ($installed) {
  & $python -c "import xformers; print(f'xformers {xformers.__version__} installed')"
  if ($LASTEXITCODE -eq 0 -and $torchVersionAfter -eq $torchVersionBefore) {
    $version = Get-PackageVersion -Python $python -PackageName "xformers"
    Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "1"
    Write-Host "xformers installed successfully."
    $installed = $true
  } else {
    $errors += "xformers import failed or torch drifted"
    $installed = $false
  }
}

$manifestEntry = [pscustomobject]@{
  name = "xformers"
  version = $version
  source = $source
  success = $installed
  url = $selectedUrl
  gate_reason = if (-not $installed) { $gateReason } else { $null }
  error_if_any = if ($errors.Count -gt 0) { $errors -join " | " } else { $null }
}

$existingResults = @()
if (Test-Path $manifestPath) {
  try {
    $existingResults = Get-Content -Raw $manifestPath | ConvertFrom-Json
  } catch {
    Write-Warning "Failed to read existing manifest at $manifestPath; overwriting."
  }
}

$combined = @()
if ($existingResults) {
  $combined += @($existingResults)
}
$combined += $manifestEntry

$combined | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestPath -Encoding utf8
Write-Host "Wrote xformers manifest entry to $manifestPath"

if ($installed) {
  Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "1"
  Write-Host "xformers installed successfully."
  exit 0
}

Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "0"
Write-Warning "xformers not available; continuing without it."
exit 0
