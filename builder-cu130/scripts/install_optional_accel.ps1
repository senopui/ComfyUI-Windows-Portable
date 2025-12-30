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
  $version = & $Python -c "import importlib.metadata as m; print(m.version('$PackageName'))" 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $null
  }
  return $version.Trim()
}

function Get-FirstPackageVersion {
  param(
    [string]$Python,
    [string[]]$PackageNames
  )
  foreach ($name in $PackageNames) {
    $version = Get-PackageVersion -Python $Python -PackageName $name
    if ($version) {
      return @{ Name = $name; Version = $version }
    }
  }
  return $null
}

function Test-VersionAtLeast {
  param(
    [string]$Python,
    [string]$Version,
    [string]$Minimum
  )
  $script = @"
from packaging.version import Version
import sys
sys.exit(0 if Version('$Version') >= Version('$Minimum') else 1)
"@
  & $Python -c $script 2>$null
  return ($LASTEXITCODE -eq 0)
}

function Test-PackageImportAny {
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
        print(name)
        sys.exit(0)
    except Exception as exc:
        errors.append(f"{name}: {exc}")
print("; ".join(errors))
sys.exit(1)
"@
  $output = & $Python -c $script 2>&1
  if ($LASTEXITCODE -eq 0) {
    return @{ Success = $true; Error = $null; Import = $output.Trim() }
  }
  return @{ Success = $false; Error = $output.Trim(); Import = $null }
}

function Filter-CompatibleWheelUrls {
  param(
    [string]$Python,
    [string[]]$Urls
  )
  $payload = ($Urls | ConvertTo-Json -Compress)
  $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
  $script = @"
import base64
import json
from packaging.tags import sys_tags
from packaging.utils import parse_wheel_filename

links = json.loads(base64.b64decode('$encoded'))
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
  if ($LASTEXITCODE -ne 0 -or -not $filtered) {
    return @()
  }
  return $filtered -split "`r?`n"
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
      $matches = Filter-CompatibleWheelUrls -Python $Python -Urls $matches
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

function Resolve-GitHubReleaseWheelUrl {
  param(
    [string]$Python,
    [string]$Repository,
    [string]$PackagePattern
  )
  Write-Host "=== Resolving GitHub release wheel for $Repository (pattern: $PackagePattern) ==="
  try {
    $headers = @{ "User-Agent" = "ComfyUI-Windows-Portable" }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers
    $assets = @($release.assets | Where-Object { $_.name -match $PackagePattern })
    if ($assets.Count -eq 0) {
      Write-Warning "No release assets matched pattern '$PackagePattern'"
      return $null
    }
    $urls = $assets | ForEach-Object { $_.browser_download_url }
    $filtered = Filter-CompatibleWheelUrls -Python $Python -Urls $urls
    if ($filtered.Count -eq 0) {
      Write-Warning "No compatible wheels found in release assets"
      return $null
    }
    $filtered = $filtered | Sort-Object
    return $filtered[-1]
  } catch {
    Write-Warning "Failed to query GitHub release: $($_.Exception.Message)"
  }
  return $null
}

function Set-AvailabilityFlag {
  param(
    [string]$Name,
    [string]$Value
  )
  $entry = "$Name=$Value"
  if ($env:GITHUB_ENV) {
    Add-Content -Path $env:GITHUB_ENV -Value $entry
  } else {
    Write-Host "ENV: $entry"
  }
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$python = Join-Path $root "python_standalone/python.exe"
$manifestPath = Join-Path $root "accel_manifest.json"

if (-not (Test-Path $python)) {
  throw "Python executable not found at $python"
}

$results = @()

function Add-Result {
  param(
    [string]$Name,
    [string]$Version,
    [string]$Source,
    [bool]$Success,
    [string]$ErrorMessage
  )
  $script:results += [pscustomobject]@{
    name = $Name
    version = $Version
    source = $Source
    success = $Success
    error_if_any = $ErrorMessage
  }
}

try {
  # Nunchaku
  $nunchakuMinVersion = "1.0.0"
  $nunchakuErrors = @()
  $nunchakuSource = "none"
  $nunchakuVersion = Get-PackageVersion -Python $python -PackageName "nunchaku"
  $nunchakuSuccess = $false

  if ($nunchakuVersion) {
    if (Test-VersionAtLeast -Python $python -Version $nunchakuVersion -Minimum $nunchakuMinVersion) {
      $nunchakuSuccess = $true
      $nunchakuSource = "existing"
    } else {
      $nunchakuErrors += "Installed version $nunchakuVersion is below required $nunchakuMinVersion"
    }
  }

  if (-not $nunchakuSuccess) {
    $ghUrl = Resolve-GitHubReleaseWheelUrl -Python $python -Repository "nunchaku-tech/nunchaku" -PackagePattern "nunchaku.*\.whl"
    if ($ghUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing nunchaku from GitHub release" -Arguments @("install", "--no-deps", "--force-reinstall", $ghUrl)
      if ($installAttempt.Success) {
        $nunchakuSource = "github-release"
        $nunchakuSuccess = $true
        $nunchakuErrors = @()
      } else {
        $nunchakuErrors += $installAttempt.Error
      }
    } else {
      $nunchakuErrors += "GitHub release wheel unavailable"
    }
  }

  if (-not $nunchakuSuccess) {
    $aiUrl = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "nunchaku" -IndexUrl "https://ai-windows-whl.github.io/whl/"
    if ($aiUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing nunchaku from AI-windows-whl" -Arguments @("install", "--no-deps", "--force-reinstall", $aiUrl)
      if ($installAttempt.Success) {
        $nunchakuSource = "ai-windows-whl"
        $nunchakuSuccess = $true
        $nunchakuErrors = @()
      } else {
        $nunchakuErrors += $installAttempt.Error
      }
    } else {
      $nunchakuErrors += "AI-windows-whl wheel unavailable"
    }
  }

  if (-not $nunchakuSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing nunchaku from source" -Arguments @("install", "--no-binary", ":all:", "nunchaku>=$nunchakuMinVersion")
    if ($installAttempt.Success) {
      $nunchakuSource = "source"
      $nunchakuSuccess = $true
      $nunchakuErrors = @()
    } else {
      $nunchakuErrors += $installAttempt.Error
    }
  }

  if ($nunchakuSuccess) {
    $importAttempt = Test-PackageImportAny -Python $python -ImportNames @("nunchaku")
    if (-not $importAttempt.Success) {
      $nunchakuSuccess = $false
      $nunchakuErrors += $importAttempt.Error
    } else {
      $nunchakuVersion = Get-PackageVersion -Python $python -PackageName "nunchaku"
      if ($nunchakuVersion -and -not (Test-VersionAtLeast -Python $python -Version $nunchakuVersion -Minimum $nunchakuMinVersion)) {
        $nunchakuSuccess = $false
        $nunchakuErrors += "Installed version $nunchakuVersion is below required $nunchakuMinVersion"
      }
    }
  }

  if ($nunchakuSuccess) {
    Set-AvailabilityFlag -Name "NUNCHAKU_AVAILABLE" -Value "1"
    Write-Host "nunchaku installed successfully ($nunchakuVersion) via $nunchakuSource"
  } else {
    Set-AvailabilityFlag -Name "NUNCHAKU_AVAILABLE" -Value "0"
    $nunchakuErrorMessage = if ($nunchakuErrors.Count -gt 0) { ($nunchakuErrors -join " | ") } else { "Unknown failure" }
    Write-Warning "GATED: nunchaku not available ($nunchakuErrorMessage)"
  }
  Add-Result -Name "nunchaku" -Version $nunchakuVersion -Source $nunchakuSource -Success $nunchakuSuccess -ErrorMessage (if ($nunchakuErrors.Count -gt 0) { $nunchakuErrors -join " | " } else { $null })

  # SpargeAttn (spas_sage_attn / sparse_sageattn)
  $spargeErrors = @()
  $spargeSource = "none"
  $spargeVersion = $null
  $spargeSuccess = $false
  $spargePackageInfo = Get-FirstPackageVersion -Python $python -PackageNames @("spas_sage_attn", "sparse_sageattn")

  if ($spargePackageInfo) {
    $spargeSuccess = $true
    $spargeSource = "existing"
    $spargeVersion = $spargePackageInfo.Version
  }

  if (-not $spargeSuccess) {
    $ghUrl = Resolve-GitHubReleaseWheelUrl -Python $python -Repository "woct0rdho/SpargeAttn" -PackagePattern "(spas|sparse).*sage.*attn.*\.whl"
    if ($ghUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from GitHub release" -Arguments @("install", "--no-deps", "--force-reinstall", $ghUrl)
      if ($installAttempt.Success) {
        $spargeSource = "github-release"
        $spargeSuccess = $true
        $spargeErrors = @()
      } else {
        $spargeErrors += $installAttempt.Error
      }
    } else {
      $spargeErrors += "GitHub release wheel unavailable"
    }
  }

  if (-not $spargeSuccess) {
    $aiUrl = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "(spas|sparse).*sage.*attn" -IndexUrl "https://ai-windows-whl.github.io/whl/"
    if ($aiUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from AI-windows-whl" -Arguments @("install", "--no-deps", "--force-reinstall", $aiUrl)
      if ($installAttempt.Success) {
        $spargeSource = "ai-windows-whl"
        $spargeSuccess = $true
        $spargeErrors = @()
      } else {
        $spargeErrors += $installAttempt.Error
      }
    } else {
      $spargeErrors += "AI-windows-whl wheel unavailable"
    }
  }

  if (-not $spargeSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from source (spas_sage_attn)" -Arguments @("install", "--no-binary", ":all:", "spas_sage_attn")
    if ($installAttempt.Success) {
      $spargeSource = "source"
      $spargeSuccess = $true
      $spargeErrors = @()
    } else {
      $spargeErrors += $installAttempt.Error
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from source (sparse_sageattn)" -Arguments @("install", "--no-binary", ":all:", "sparse_sageattn")
      if ($installAttempt.Success) {
        $spargeSource = "source"
        $spargeSuccess = $true
        $spargeErrors = @()
      } else {
        $spargeErrors += $installAttempt.Error
      }
    }
  }

  if ($spargeSuccess) {
    $importAttempt = Test-PackageImportAny -Python $python -ImportNames @("spas_sage_attn", "sparse_sageattn")
    if (-not $importAttempt.Success) {
      $spargeSuccess = $false
      $spargeErrors += $importAttempt.Error
    } else {
      $spargePackageInfo = Get-FirstPackageVersion -Python $python -PackageNames @("spas_sage_attn", "sparse_sageattn")
      if ($spargePackageInfo) {
        $spargeVersion = $spargePackageInfo.Version
      }
    }
  }

  if ($spargeSuccess) {
    Set-AvailabilityFlag -Name "SPARGEATTN_AVAILABLE" -Value "1"
    Write-Host "SpargeAttn installed successfully ($spargeVersion) via $spargeSource"
  } else {
    Set-AvailabilityFlag -Name "SPARGEATTN_AVAILABLE" -Value "0"
    $spargeErrorMessage = if ($spargeErrors.Count -gt 0) { ($spargeErrors -join " | ") } else { "Unknown failure" }
    Write-Warning "GATED: SpargeAttn not available ($spargeErrorMessage)"
  }
  Add-Result -Name "spargeattn" -Version $spargeVersion -Source $spargeSource -Success $spargeSuccess -ErrorMessage (if ($spargeErrors.Count -gt 0) { $spargeErrors -join " | " } else { $null })

  # NATTEN
  $nattenErrors = @()
  $nattenSource = "none"
  $nattenVersion = Get-PackageVersion -Python $python -PackageName "natten"
  $nattenSuccess = $false

  if ($nattenVersion) {
    $nattenSuccess = $true
    $nattenSource = "existing"
  }

  if (-not $nattenSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing natten from PyPI (binary-only)" -Arguments @("install", "--only-binary", ":all:", "natten")
    if ($installAttempt.Success) {
      $nattenSource = "pypi"
      $nattenSuccess = $true
      $nattenErrors = @()
    } else {
      $nattenErrors += $installAttempt.Error
    }
  }

  if (-not $nattenSuccess) {
    $aiUrl = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "natten" -IndexUrl "https://ai-windows-whl.github.io/whl/"
    if ($aiUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing natten from AI-windows-whl" -Arguments @("install", "--no-deps", "--force-reinstall", $aiUrl)
      if ($installAttempt.Success) {
        $nattenSource = "ai-windows-whl"
        $nattenSuccess = $true
        $nattenErrors = @()
      } else {
        $nattenErrors += $installAttempt.Error
      }
    } else {
      $nattenErrors += "AI-windows-whl wheel unavailable"
    }
  }

  if (-not $nattenSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing natten from source" -Arguments @("install", "--no-binary", ":all:", "natten")
    if ($installAttempt.Success) {
      $nattenSource = "source"
      $nattenSuccess = $true
      $nattenErrors = @()
    } else {
      $nattenErrors += $installAttempt.Error
    }
  }

  if ($nattenSuccess) {
    $importAttempt = Test-PackageImportAny -Python $python -ImportNames @("natten")
    if (-not $importAttempt.Success) {
      $nattenSuccess = $false
      $nattenErrors += $importAttempt.Error
    } else {
      $nattenVersion = Get-PackageVersion -Python $python -PackageName "natten"
    }
  }

  if ($nattenSuccess) {
    Set-AvailabilityFlag -Name "NATTEN_AVAILABLE" -Value "1"
    Write-Host "natten installed successfully ($nattenVersion) via $nattenSource"
  } else {
    Set-AvailabilityFlag -Name "NATTEN_AVAILABLE" -Value "0"
    $nattenErrorMessage = if ($nattenErrors.Count -gt 0) { ($nattenErrors -join " | ") } else { "Unknown failure" }
    Write-Warning "GATED: natten not available ($nattenErrorMessage)"
  }
  Add-Result -Name "natten" -Version $nattenVersion -Source $nattenSource -Success $nattenSuccess -ErrorMessage (if ($nattenErrors.Count -gt 0) { $nattenErrors -join " | " } else { $null })

  # bitsandbytes
  $bnbErrors = @()
  $bnbSource = "none"
  $bnbVersion = Get-PackageVersion -Python $python -PackageName "bitsandbytes"
  $bnbSuccess = $false

  if ($bnbVersion) {
    $bnbSuccess = $true
    $bnbSource = "existing"
  }

  if (-not $bnbSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing bitsandbytes from PyPI (binary-only)" -Arguments @("install", "--only-binary", ":all:", "bitsandbytes")
    if ($installAttempt.Success) {
      $bnbSource = "pypi"
      $bnbSuccess = $true
      $bnbErrors = @()
    } else {
      $bnbErrors += $installAttempt.Error
    }
  }

  if (-not $bnbSuccess) {
    $aiUrl = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "bitsandbytes" -IndexUrl "https://ai-windows-whl.github.io/whl/"
    if ($aiUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing bitsandbytes from AI-windows-whl" -Arguments @("install", "--no-deps", "--force-reinstall", $aiUrl)
      if ($installAttempt.Success) {
        $bnbSource = "ai-windows-whl"
        $bnbSuccess = $true
        $bnbErrors = @()
      } else {
        $bnbErrors += $installAttempt.Error
      }
    } else {
      $bnbErrors += "AI-windows-whl wheel unavailable"
    }
  }

  if (-not $bnbSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing bitsandbytes from source" -Arguments @("install", "--no-binary", ":all:", "bitsandbytes")
    if ($installAttempt.Success) {
      $bnbSource = "source"
      $bnbSuccess = $true
      $bnbErrors = @()
    } else {
      $bnbErrors += $installAttempt.Error
    }
  }

  if ($bnbSuccess) {
    $importAttempt = Test-PackageImportAny -Python $python -ImportNames @("bitsandbytes")
    if (-not $importAttempt.Success) {
      $bnbSuccess = $false
      $bnbErrors += $importAttempt.Error
    } else {
      $bnbVersion = Get-PackageVersion -Python $python -PackageName "bitsandbytes"
    }
  }

  if ($bnbSuccess) {
    Set-AvailabilityFlag -Name "BITSANDBYTES_AVAILABLE" -Value "1"
    Write-Host "bitsandbytes installed successfully ($bnbVersion) via $bnbSource"
  } else {
    Set-AvailabilityFlag -Name "BITSANDBYTES_AVAILABLE" -Value "0"
    $bnbErrorMessage = if ($bnbErrors.Count -gt 0) { ($bnbErrors -join " | ") } else { "Unknown failure" }
    Write-Warning "GATED: bitsandbytes not available ($bnbErrorMessage)"
  }
  Add-Result -Name "bitsandbytes" -Version $bnbVersion -Source $bnbSource -Success $bnbSuccess -ErrorMessage (if ($bnbErrors.Count -gt 0) { $bnbErrors -join " | " } else { $null })
} catch {
  Write-Warning "Optional accelerator install encountered an unexpected error: $($_.Exception.Message)"
}

$existingResults = @()
if (Test-Path $manifestPath) {
  try {
    $existingResults = Get-Content $manifestPath | ConvertFrom-Json
  } catch {
    Write-Warning "Failed to read existing manifest at $manifestPath; overwriting."
  }
}

$combined = @()
if ($existingResults) {
  $combined += @($existingResults)
}
$combined += $results

$combined | ConvertTo-Json -Depth 4 | Out-File -FilePath $manifestPath -Encoding utf8
Write-Host "Wrote optional accelerator manifest entries to $manifestPath"

Write-Host "=== Optional accelerator summary ==="
$results | Select-Object name, version, source, success | Format-Table -AutoSize

exit 0
