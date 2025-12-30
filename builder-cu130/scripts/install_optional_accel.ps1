$ErrorActionPreference = "Stop"

function Invoke-PipInstall {
  param(
    [string]$Python,
    [string]$Label,
    [string[]]$Arguments
  )
  Write-Host "=== $Label ==="
  $output = & $Python -s -m pip @Arguments 2>&1 | Out-String
  if ($output) {
    Write-Host $output.TrimEnd()
  }
  if ($LASTEXITCODE -eq 0) {
    return @{ Success = $true; Error = $null }
  }
  $errorMessage = if ($output) { "pip exited with code $LASTEXITCODE: $($output.Trim())" } else { "pip exited with code $LASTEXITCODE" }
  return @{ Success = $false; Error = $errorMessage }
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

function Resolve-WildminderWheelUrl {
  param(
    [string]$Python,
    [string]$PackageId,
    [string]$PythonTag,
    [string]$CudaTag
  )
  $wheelIndexUrl = "https://raw.githubusercontent.com/wildminder/AI-windows-whl/main/wheels.json"
  Write-Host "=== Resolving wheels.json entry for $PackageId ($wheelIndexUrl) ==="
  try {
    $data = Invoke-RestMethod -Uri $wheelIndexUrl -UseBasicParsing
    $package = $data.packages | Where-Object { $_.id -eq $PackageId } | Select-Object -First 1
    if (-not $package) {
      Write-Warning "Package '$PackageId' not found in wheels.json"
      return $null
    }
    $wheels = @($package.wheels)
    if (-not $wheels -or $wheels.Count -eq 0) {
      Write-Warning "No wheels listed for '$PackageId' in wheels.json"
      return $null
    }
    $matching = $wheels | Where-Object {
      $url = $_.url
      $pythonMatch = ($_.python_version -eq "3.13") -or ($url -match $PythonTag)
      $cudaMatch = ($_.cuda_version -eq "13.0") -or ($_.cuda_version -eq "13") -or ($url -match $CudaTag)
      $torchMatch = ($_.torch_version -match "dev|nightly") -or ($url -match "torch.*dev") -or ($url -match "torch.*nightly")
      $pythonMatch -and $cudaMatch -and $torchMatch -and $url
    }
    if (-not $matching -or $matching.Count -eq 0) {
      Write-Warning "No wheels matched cp313/torch-nightly/cu130 in wheels.json for $PackageId"
      return $null
    }
    $urls = $matching | ForEach-Object { $_.url } | Where-Object { $_ }
    $filtered = Filter-CompatibleWheelUrls -Python $Python -Urls $urls
    if ($filtered.Count -eq 0) {
      Write-Warning "No compatible wheels found in wheels.json for $PackageId"
      return $null
    }
    $filtered = $filtered | Sort-Object
    return $filtered[-1]
  } catch {
    Write-Warning "Failed to query wheels.json: $($_.Exception.Message)"
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
$spargeNightlyEnabled = $env:SPARGEATTN_NIGHTLY -eq "1"

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
  Invoke-TorchGuard -Python $python -Root $root -Label "nunchaku install group"

  # SpargeAttn (spas_sage_attn / sparse_sageattn)
  $spargeErrors = @()
  $spargeSource = "none"
  $spargeVersion = $null
  $spargeSuccess = $false
  $spargeTorchReady = $true
  $spargePackageInfo = Get-FirstPackageVersion -Python $python -PackageNames @("spas_sage_attn", "sparse_sageattn")

  if ($spargePackageInfo) {
    $spargeSuccess = $true
    $spargeSource = "existing"
    $spargeVersion = $spargePackageInfo.Version
  }

  if (-not $spargeSuccess) {
    $torchCheck = Test-TorchNightlyCu130 -Python $python
    if (-not $torchCheck.Success) {
      $spargeErrors += "Torch not nightly cu130 ($($torchCheck.Version))"
      Write-Warning "Skipping SpargeAttn installs because torch nightly cu130 is not present."
      $spargeTorchReady = $false
    } else {
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
  }

  if (-not $spargeSuccess -and $spargeNightlyEnabled -and $spargeTorchReady) {
    $wildminderUrl = Resolve-WildminderWheelUrl -Python $python -PackageId "spargeattn" -PythonTag "cp313" -CudaTag "cu130"
    if ($wildminderUrl) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from wheels.json" -Arguments @("install", "--no-deps", "--force-reinstall", $wildminderUrl)
      if ($installAttempt.Success) {
        $spargeSource = "wheels-json"
        $spargeSuccess = $true
        $spargeErrors = @()
      } else {
        $spargeErrors += $installAttempt.Error
      }
    } else {
      $spargeErrors += "wheels.json wheel unavailable"
    }
  }

  if (-not $spargeSuccess -and $spargeTorchReady) {
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

  if (-not $spargeSuccess -and $spargeNightlyEnabled -and $spargeTorchReady) {
    $nvccPath = (Get-Command nvcc -ErrorAction SilentlyContinue).Source
    if (-not $nvccPath -and $env:CUDA_HOME) {
      $candidate = Join-Path $env:CUDA_HOME "bin/nvcc.exe"
      if (Test-Path $candidate) {
        $nvccPath = $candidate
      }
    }
    if (-not $nvccPath) {
      $spargeErrors += "nvcc not found; set CUDA_HOME or install CUDA toolkit"
      Write-Warning "GATED: SpargeAttn source build skipped (nvcc not found)"
    } else {
      $buildTools = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn build prerequisites" -Arguments @("install", "--upgrade", "ninja", "build", "setuptools", "wheel")
      if (-not $buildTools.Success) {
        $spargeErrors += $buildTools.Error
      } else {
        $spargeRepo = Join-Path $root "spargeattn-src"
        if (Test-Path $spargeRepo) {
          Remove-Item -Path $spargeRepo -Recurse -Force
        }
        $cloneOutput = & git clone --depth 1 https://github.com/thu-ml/SpargeAttn $spargeRepo 2>&1 | Out-String
        if ($cloneOutput) {
          Write-Host $cloneOutput.TrimEnd()
        }
        if ($LASTEXITCODE -ne 0) {
          $spargeErrors += "SpargeAttn git clone failed"
        } else {
          Push-Location $spargeRepo
          try {
            if (Test-Path "dist") {
              Remove-Item -Path "dist" -Recurse -Force
            }
            $wheelOutput = & $python -s -m pip wheel . -w dist --no-deps --no-build-isolation 2>&1 | Out-String
            if ($wheelOutput) {
              Write-Host $wheelOutput.TrimEnd()
            }
            if ($LASTEXITCODE -ne 0) {
              $spargeErrors += "SpargeAttn wheel build failed"
            } else {
              $wheel = Get-ChildItem -Path "dist" -Filter "*.whl" | Sort-Object Name | Select-Object -Last 1
              if (-not $wheel) {
                $spargeErrors += "SpargeAttn wheel not found after build"
              } else {
                $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from source build" -Arguments @("install", "--no-deps", "--force-reinstall", $wheel.FullName)
                if ($installAttempt.Success) {
                  $spargeSource = "source"
                  $spargeSuccess = $true
                  $spargeErrors = @()
                } else {
                  $spargeErrors += $installAttempt.Error
                }
              }
            }
          } finally {
            Pop-Location
          }
        }
      }
    }
  }
  }

  if ($spargeSuccess) {
    $spargeImportOutput = & $python -c "import spas_sage_attn; print('spas_sage_attn import OK')" 2>&1 | Out-String
    if ($spargeImportOutput) {
      Write-Host $spargeImportOutput.TrimEnd()
    }
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "SpargeAttn spas_sage_attn import failed: $($spargeImportOutput.Trim())"
      $importAttempt = Test-PackageImportAny -Python $python -ImportNames @("spas_sage_attn", "sparse_sageattn")
    } else {
      $importAttempt = @{ Success = $true; Error = $null }
    }
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
  Invoke-TorchGuard -Python $python -Root $root -Label "spargeattn install group"

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
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing natten from PyPI (binary-only)" -Arguments @("install", "--no-deps", "--only-binary", ":all:", "natten")
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
  Invoke-TorchGuard -Python $python -Root $root -Label "natten install group"

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
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing bitsandbytes from PyPI (binary-only)" -Arguments @("install", "--no-deps", "--only-binary", ":all:", "bitsandbytes")
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
  Invoke-TorchGuard -Python $python -Root $root -Label "bitsandbytes install group"
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
