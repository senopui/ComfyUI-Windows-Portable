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

function Get-AIWindowsWheelIndex {
  param(
    [string]$IndexJsonUrl
  )

  if ($script:AIWindowsWheelIndex -and $script:AIWindowsWheelIndex.Url -eq $IndexJsonUrl) {
    return $script:AIWindowsWheelIndex.Data
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
    $script:AIWindowsWheelIndex = @{
      Url = $IndexJsonUrl
      Data = $parsed.data
    }
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
  $raw = ""
  try {
    $raw = (& $Python -W ignore -c $script 2> $stderrPath | Out-String).TrimEnd()
  } finally {
    if (Test-Path $stderrPath) {
      $stderrRaw = Get-Content -Raw $stderrPath -ErrorAction SilentlyContinue
      if ($null -eq $stderrRaw) {
        $stderr = ""
      } else {
        $stderr = $stderrRaw.Trim()
      }
      Remove-Item -Path $stderrPath -Force
    } else {
      $stderr = ""
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

function Resolve-AIWindowsWheelUrl {
  param(
    [string]$Python,
    [string]$PackagePattern,
    [string]$IndexJsonUrl = "https://raw.githubusercontent.com/wildminder/AI-windows-whl/main/wheels.json",
    [string]$CudaTag = "cu130",
    [string]$PythonTag,
    [string]$TorchMinimum = "2.10.0",
    [switch]$AllowAbi3,
    [pscustomobject]$TorchInfo
  )
  Write-Host "=== Resolving AI-windows-whl wheel via wheels.json (pattern: $PackagePattern) ==="
  if (-not $TorchInfo) {
    $TorchInfo = Get-TorchInfoFromPython -Python $Python
  }
  if (-not $TorchInfo) {
    return [pscustomobject]@{
      url = $null
      reason = "torch metadata unavailable"
      source = "wheels-json"
    }
  }

  if (-not $PythonTag) {
    $PythonTag = switch ($TorchInfo.python_version) {
      "3.13" { "cp313" }
      "3.12" { "cp312" }
      default { $null }
    }
  }
  if (-not $PythonTag) {
    return [pscustomobject]@{
      url = $null
      reason = "unsupported python version $($TorchInfo.python_version)"
      source = "wheels-json"
    }
  }

  $payload = Get-AIWindowsWheelIndex -IndexJsonUrl $IndexJsonUrl
  if (-not $payload) {
    return [pscustomobject]@{
      url = $null
      reason = "wheels.json unavailable"
      source = "wheels-json"
    }
  }

  $packages = @($payload.packages | Where-Object { $_.id -match $PackagePattern -or $_.name -match $PackagePattern })
  if ($packages.Count -eq 0) {
    return [pscustomobject]@{
      url = $null
      reason = "no wheels.json package matched pattern '$PackagePattern'"
      source = "wheels-json"
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
    }
  }

  $sorted = $candidates | Sort-Object -Property python_score, dev_score, abi_score, parsed_version, url
  $selected = $sorted[-1]
  return [pscustomobject]@{
    url = $selected.url
    reason = $null
    source = "wheels-json"
  }
}
