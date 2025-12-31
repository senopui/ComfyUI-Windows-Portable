function Read-TextFileSafe {
  param(
    [string]$Path
  )
  if (-not (Test-Path $Path)) {
    return ""
  }
  $raw = Get-Content -Raw $Path -ErrorAction SilentlyContinue
  if ($null -eq $raw) {
    return ""
  }
  return [string]$raw
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
  $normalized = ($rawString -replace "^\uFEFF", "")
  $trimmed = $normalized.Trim()
  $preview = if ($trimmed.Length -gt 200) { $trimmed.Substring(0, 200) } else { $trimmed }
  $candidate = $trimmed
  $usedLastJsonLine = $false

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
    $lines = $trimmed -split "`r?`n"
    for ($idx = $lines.Length - 1; $idx -ge 0; $idx--) {
      $line = $lines[$idx]
      if (-not $line) {
        continue
      }
      $lineTrimmed = $line.Trim()
      if ($lineTrimmed.StartsWith("{") -or $lineTrimmed.StartsWith("[")) {
        $candidate = $lineTrimmed
        $usedLastJsonLine = $true
        break
      }
    }
    if (-not $usedLastJsonLine) {
      $reason = if ($trimmed.StartsWith("<")) { "HTML response detected" } else { "non-JSON output detected" }
      Write-Warning "JSON parse skipped for ${Source}: $reason."
      return [pscustomobject]@{
        ok = $false
        reason = $reason
        raw_preview = $preview
        source = $Source
      }
    }
  }

  try {
    $parsed = $candidate | ConvertFrom-Json
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

function Get-Excerpt {
  param(
    [string]$Text,
    [int]$MaxLength = 400
  )
  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $null
  }
  $trimmed = $Text.Trim()
  if ($trimmed.Length -le $MaxLength) {
    return $trimmed
  }
  return $trimmed.Substring(0, $MaxLength)
}

function Read-JsonFileSafe {
  param(
    [string]$Path,
    [string]$SourceLabel
  )

  if (-not (Test-Path $Path)) {
    return @()
  }

  $raw = Get-Content -Raw $Path -ErrorAction SilentlyContinue
  if ($null -eq $raw) {
    return @()
  }

  $parsed = Parse-JsonSafe -RawOutput $raw -Source $SourceLabel
  if (-not $parsed.ok) {
    Write-Warning ("Failed to parse {0} at {1}: {2}" -f $SourceLabel, $Path, $parsed.reason)
    return @()
  }
  if ($parsed.data -is [System.Collections.IEnumerable] -and -not ($parsed.data -is [string])) {
    return @($parsed.data)
  }
  return @($parsed.data)
}

function Write-AccelSummary {
  param(
    [string]$Title,
    [object[]]$Results
  )
  $rows = @($Results | ForEach-Object {
    $status = if ($_.success) {
      "success"
    } elseif ($_.gated -or $_.gate_reason) {
      "gated"
    } else {
      "failed"
    }
    [pscustomobject]@{
      name = $_.name
      status = $status
      version = $_.version
      source = $_.source
    }
  })

  $successCount = ($rows | Where-Object { $_.status -eq "success" }).Count
  $gatedCount = ($rows | Where-Object { $_.status -eq "gated" }).Count
  $failedCount = ($rows | Where-Object { $_.status -eq "failed" }).Count

  Write-Host "=== $Title summary ==="
  Write-Host ("Success: {0} | Gated: {1} | Failed: {2}" -f $successCount, $gatedCount, $failedCount)
  $rows | Format-Table -AutoSize
}

$script:WheelIndexCache = @{}
$script:FallbackWheelTemplates = @(
  # Fallback URL templates: replace {0} with the wheel filename.
  "https://github.com/wildminder/AI-windows-whl/releases/latest/download/{0}",
  "https://github.com/wildminder/AI-windows-whl/releases/download/latest/{0}"
)

function Get-AIWindowsWheelIndex {
  param(
    [string]$IndexJsonUrl
  )

  if ($script:WheelIndexCache.ContainsKey($IndexJsonUrl)) {
    return $script:WheelIndexCache[$IndexJsonUrl]
  }

  Write-Host "=== Fetching AI-windows-whl wheels.json from $IndexJsonUrl ==="
  try {
    $page = Invoke-WebRequest -Uri $IndexJsonUrl -UseBasicParsing
    $payloadRaw = ($page.Content 2>&1 | Out-String).TrimEnd()
    $parsed = Parse-JsonSafe -RawOutput $payloadRaw -Source "AI-windows-whl wheels.json"
    if (-not $parsed.ok) {
      Write-Warning "AI-windows-whl wheels.json invalid: $($parsed.reason)."
      return $null
    }
    $script:WheelIndexCache[$IndexJsonUrl] = $parsed.data
    return $parsed.data
  } catch {
    Write-Warning "Failed to query AI-windows-whl wheels.json: $($_.Exception.Message)"
  }
  return $null
}

function Get-TorchInfoFromPython {
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
cuda = torch.version.cuda or ""
cuda_tag = f"cu{cuda.replace('.', '')}" if cuda else ""
info = {
    "torch_version": base,
    "torch_major": parsed.major,
    "torch_minor": parsed.minor,
    "torch_is_dev": bool(parsed.is_devrelease),
    "python_version": f"{sys.version_info.major}.{sys.version_info.minor}",
    "cuda_tag": cuda_tag
}
print(json.dumps(info))
"@
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $raw = ""
  try {
    & $Python -W ignore -c $script 1> $stdoutPath 2> $stderrPath
  } finally {
    $raw = (Read-TextFileSafe -Path $stdoutPath).TrimEnd()
    if (Test-Path $stderrPath) {
      $stderrRaw = Read-TextFileSafe -Path $stderrPath
      $stderr = $stderrRaw.Trim()
      Remove-Item -Path $stderrPath -Force
    } else {
      $stderr = ""
    }
    if (Test-Path $stdoutPath) {
      Remove-Item -Path $stdoutPath -Force
    }
  }
  if ($LASTEXITCODE -ne 0 -or -not $raw) {
    if ($stderr) {
      Write-Warning "Torch metadata probe failed: $stderr"
    }
    return $null
  }
  $parsed = Parse-JsonSafe -RawOutput $raw -Source "Get-TorchInfoFromPython"
  if (-not $parsed.ok) {
    Write-Warning "Torch metadata JSON invalid: $($parsed.reason)."
    return $null
  }
  return $parsed.data
}

function Get-PythonTag {
  param(
    [string]$PythonVersion
  )
  $mm = $null
  if ($PythonVersion) {
    $match = [regex]::Match($PythonVersion, "^(\\d+\\.\\d+)")
    if ($match.Success) {
      $mm = $match.Groups[1].Value
    }
  }
  return (switch ($mm) {
    "3.13" { "cp313" }
    "3.12" { "cp312" }
    default { $null }
  })
}

function Test-WheelUrlReachable {
  param(
    [string]$Url,
    [int]$TimeoutSec = 20
  )
  try {
    Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null
    return [pscustomobject]@{ ok = $true; reason = $null }
  } catch {
    $headReason = $_.Exception.Message
    try {
      $headers = @{ Range = "bytes=0-0" }
      Invoke-WebRequest -Uri $Url -Method Get -Headers $headers -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null
      return [pscustomobject]@{ ok = $true; reason = $null }
    } catch {
      $getReason = $_.Exception.Message
      return [pscustomobject]@{
        ok = $false
        reason = "HEAD failed: $headReason; GET failed: $getReason"
      }
    }
  }
}

function Get-FallbackWheelUrls {
  param(
    [string]$WheelUrl
  )
  if (-not $WheelUrl) {
    return @()
  }
  $filename = [IO.Path]::GetFileName($WheelUrl)
  if (-not $filename) {
    return @()
  }
  $fallbacks = @()
  foreach ($template in $script:FallbackWheelTemplates) {
    $fallbacks += ($template -f $filename)
  }
  return $fallbacks
}

function Resolve-AIWindowsWheelUrl {
  param(
    [string]$Python,
    [string]$PackagePattern,
    [string]$PackageVersionPattern,
    [string]$IndexJsonUrl,
    [string]$CudaTag = "cu130",
    [string]$PythonTag,
    [string]$TorchMinimum = "2.10.0",
    [switch]$AllowAbi3,
    [switch]$SkipFallback,
    [pscustomobject]$TorchInfo
  )
  $requested = if ($PackageVersionPattern) {
    "{0} (version pattern: {1})" -f $PackagePattern, $PackageVersionPattern
  } else {
    $PackagePattern
  }
  Write-Host "=== Resolving AI-windows-whl wheel via wheels.json (pattern: $requested) ==="

  if (-not $IndexJsonUrl) {
    $IndexJsonUrl = if ($env:AI_WINDOWS_WHL_WHEELS_JSON_URL) {
      $env:AI_WINDOWS_WHL_WHEELS_JSON_URL
    } else {
      "https://raw.githubusercontent.com/wildminder/AI-windows-whl/main/wheels.json"
    }
  }

  if (-not $TorchInfo) {
    $TorchInfo = Get-TorchInfoFromPython -Python $Python
  }
  if (-not $TorchInfo) {
    return [pscustomobject]@{
      url = $null
      reason = "torch metadata unavailable"
      source = "wheels-json"
      requested = $requested
      candidate_url = $null
    }
  }

  if (-not $PythonTag) {
    $PythonTag = Get-PythonTag -PythonVersion $TorchInfo.python_version
  }
  if (-not $PythonTag) {
    return [pscustomobject]@{
      url = $null
      reason = "unsupported python version $($TorchInfo.python_version)"
      source = "wheels-json"
      requested = $requested
      candidate_url = $null
    }
  }

  $payload = Get-AIWindowsWheelIndex -IndexJsonUrl $IndexJsonUrl
  if (-not $payload) {
    return [pscustomobject]@{
      url = $null
      reason = "wheels.json unavailable"
      source = "wheels-json"
      requested = $requested
      candidate_url = $null
    }
  }

  $packages = @($payload.packages | Where-Object { $_.id -match $PackagePattern -or $_.name -match $PackagePattern })
  if ($packages.Count -eq 0) {
    return [pscustomobject]@{
      url = $null
      reason = "no wheels.json package matched pattern '$PackagePattern'"
      source = "wheels-json"
      requested = $requested
      candidate_url = $null
    }
  }

  $candidates = @()
  foreach ($pkg in $packages) {
    foreach ($wheel in @($pkg.wheels)) {
      $url = $wheel.url
      if (-not $url) {
        continue
      }
      if ($url -notmatch "win_amd64") {
        continue
      }

      if ($PackageVersionPattern) {
        $versionTarget = if ($wheel.package_version) { $wheel.package_version } else { "" }
        if (-not ($versionTarget -match $PackageVersionPattern -or $url -match $PackageVersionPattern)) {
          continue
        }
      }

      $pythonScore = 0
      if ($wheel.python_version -and $wheel.python_version -eq $TorchInfo.python_version) {
        $pythonScore = 3
      } elseif ($PythonTag -and ($url -match $PythonTag)) {
        $pythonScore = 2
      } elseif ($AllowAbi3 -and ($url -match "abi3")) {
        $pythonScore = 1
      }
      if ($pythonScore -eq 0) {
        continue
      }

      $cudaMatch = $false
      $cudaNorm = ($wheel.cuda_version -replace "\.", "")
      if ($cudaNorm) {
        $cudaMatch = ("cu$cudaNorm" -eq $CudaTag)
      } elseif ($url -match $CudaTag) {
        $cudaMatch = $true
      }
      if (-not $cudaMatch) {
        continue
      }

      $torchVersion = $wheel.torch_version
      if ($torchVersion) {
        if ($torchVersion -notmatch "^2\\.(\\d+)") {
          continue
        }
        if ([int]$Matches[1] -lt 10) {
          continue
        }
        if ($TorchInfo.torch_is_dev -and ($torchVersion -notmatch "dev|nightly")) {
          continue
        }
      } else {
        if ($url -notmatch "torch") {
          continue
        }
      }

      $rawVersion = if ($wheel.package_version) { $wheel.package_version } else { "" }
      $numericVersion = ($rawVersion -replace "[^0-9\\.]", "")
      if ([string]::IsNullOrWhiteSpace($numericVersion)) {
        $numericVersion = "0.0"
      }
      $parsedVersion = try { [version]$numericVersion } catch { [version]"0.0" }
      $devScore = if ($torchVersion -and ($torchVersion -match "dev|nightly")) { 1 } else { 0 }
      $abiScore = if ($AllowAbi3 -and ($url -match "abi3")) { 1 } else { 0 }

      $candidates += [pscustomobject]@{
        url = $url
        package_version = $rawVersion
        parsed_version = $parsedVersion
        python_score = $pythonScore
        dev_score = $devScore
        abi_score = $abiScore
      }
    }
  }

  if ($candidates.Count -eq 0) {
    $reason = "no matching wheel for ${PythonTag} torch>=${TorchMinimum} ${CudaTag}"
    return [pscustomobject]@{
      url = $null
      reason = $reason
      source = "wheels-json"
      requested = $requested
      candidate_url = $null
    }
  }

  $sorted = $candidates | Sort-Object -Property python_score, dev_score, abi_score, parsed_version, url
  $selected = $sorted[-1]
  $check = Test-WheelUrlReachable -Url $selected.url
  if ($check.ok) {
    return [pscustomobject]@{
      url = $selected.url
      reason = $null
      source = "wheels-json"
      requested = $requested
      candidate_url = $selected.url
    }
  }

  if ($SkipFallback) {
    return [pscustomobject]@{
      url = $null
      reason = "resolved wheel URL unreachable"
      source = "wheels-json"
      requested = $requested
      candidate_url = $selected.url
    }
  }

  $fallbacks = Get-FallbackWheelUrls -WheelUrl $selected.url
  foreach ($fallback in $fallbacks) {
    $fallbackCheck = Test-WheelUrlReachable -Url $fallback
    if ($fallbackCheck.ok) {
      return [pscustomobject]@{
        url = $fallback
        reason = $null
        source = "fallback-template"
        requested = $requested
        candidate_url = $selected.url
      }
    }
  }

  return [pscustomobject]@{
    url = $null
    reason = "resolved wheel URL unreachable; fallback templates failed"
    source = "wheels-json"
    requested = $requested
    candidate_url = $selected.url
  }
}
