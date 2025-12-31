$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "accel_helpers.ps1")

function Invoke-PipInstall {
  param(
    [string]$Python,
    [string]$Label,
    [string[]]$Arguments
  )
  Write-Host "=== $Label ==="
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $stdout = ""
  $stderr = ""
  try {
    $stdout = (& $Python -s -m pip @Arguments 2> $stderrPath | Out-String).TrimEnd()
  } finally {
    if (Test-Path $stderrPath) {
      $stderrRaw = Get-Content -Raw $stderrPath -ErrorAction SilentlyContinue
      if ($null -ne $stderrRaw) {
        $stderr = $stderrRaw.Trim()
      }
      Remove-Item -Path $stderrPath -Force
    }
  }
  if ($stdout) {
    Write-Host $stdout
  }
  if ($LASTEXITCODE -eq 0) {
    return @{ Success = $true; Error = $null; Stdout = $stdout; Stderr = $stderr }
  }
  $errorMessage = if ($stdout) {
    ("pip exited with code {0}: {1}" -f $LASTEXITCODE, $stdout.Trim())
  } else {
    ("pip exited with code {0}" -f $LASTEXITCODE)
  }
  return @{ Success = $false; Error = $errorMessage; Stdout = $stdout; Stderr = $stderr }
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
if isinstance(names, str):
    names = [names]
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
$spargeNightlyEnabled = $env:SPARGEATTN_NIGHTLY -eq "1"

if (-not (Test-Path $python)) {
  throw "Python executable not found at $python"
}

$torchInfo = Get-TorchInfoFromPython -Python $python
$pythonTag = $null
if ($torchInfo) {
  $pythonTag = Get-PythonTag -PythonVersion $torchInfo.python_version
}

$results = @()

function Add-Result {
  param(
    [string]$Name,
    [string]$Requested,
    [string]$Version,
    [string]$Source,
    [bool]$Success,
    [string]$Url,
    [string]$GateReason,
    [string]$ErrorMessage,
    [string]$StderrExcerpt
  )
  $script:results += [pscustomobject]@{
    name = $Name
    requested = $Requested
    version = $Version
    source = $Source
    success = $Success
    url = if ($Url) { $Url } else { "none" }
    gate_reason = $GateReason
    error_if_any = $ErrorMessage
    stderr_excerpt = $StderrExcerpt
  }
}

try {
  # Nunchaku
  $nunchakuMinVersion = "1.0.0"
  $nunchakuErrors = @()
  $nunchakuSource = "none"
  $nunchakuVersion = Get-PackageVersion -Python $python -PackageName "nunchaku"
  $nunchakuSuccess = $false
  $nunchakuUrl = "none"
  $nunchakuGateReason = $null
  $nunchakuRequested = "nunchaku>=$nunchakuMinVersion (pattern=nunchaku)"
  $nunchakuStderr = $null

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
        $nunchakuUrl = $ghUrl
        $nunchakuStderr = Get-Excerpt -Text $installAttempt.Stderr
      } else {
        $nunchakuErrors += $installAttempt.Error
        $nunchakuStderr = Get-Excerpt -Text $installAttempt.Stderr
      }
    } else {
      $nunchakuErrors += "GitHub release wheel unavailable"
    }
  }

  if (-not $nunchakuSuccess) {
    $resolved = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "nunchaku" -TorchInfo $torchInfo -PythonTag $pythonTag -AllowAbi3
    if ($resolved.requested) {
      $nunchakuRequested = $resolved.requested
    }
    if ($resolved.url) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing nunchaku from AI-windows-whl wheel URL" -Arguments @("install", "--no-deps", "--force-reinstall", $resolved.url)
      if ($installAttempt.Success) {
        $nunchakuSource = $resolved.source
        $nunchakuSuccess = $true
        $nunchakuErrors = @()
        $nunchakuUrl = $resolved.url
        $nunchakuStderr = Get-Excerpt -Text $installAttempt.Stderr
      } else {
        $nunchakuErrors += $installAttempt.Error
        $nunchakuStderr = Get-Excerpt -Text $installAttempt.Stderr
      }
    } else {
      $nunchakuGateReason = if ($resolved.reason) { $resolved.reason } else { "wheels.json wheel unavailable" }
      $nunchakuErrors += $nunchakuGateReason
    }
  }

  if (-not $nunchakuSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing nunchaku from source" -Arguments @("install", "--no-binary", ":all:", "nunchaku>=$nunchakuMinVersion")
    if ($installAttempt.Success) {
      $nunchakuSource = "source"
      $nunchakuSuccess = $true
      $nunchakuErrors = @()
      $nunchakuStderr = Get-Excerpt -Text $installAttempt.Stderr
    } else {
      $nunchakuErrors += $installAttempt.Error
      $nunchakuStderr = Get-Excerpt -Text $installAttempt.Stderr
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
    if (-not $nunchakuGateReason) {
      $nunchakuGateReason = $nunchakuErrorMessage
    }
  }
  Add-Result -Name "nunchaku" -Requested $nunchakuRequested -Version $nunchakuVersion -Source $nunchakuSource -Success $nunchakuSuccess -Url $nunchakuUrl -GateReason $nunchakuGateReason -ErrorMessage (if ($nunchakuErrors.Count -gt 0) { $nunchakuErrors -join " | " } else { $null }) -StderrExcerpt $nunchakuStderr
  Invoke-TorchGuard -Python $python -Root $root -Label "nunchaku install group"

  # SpargeAttn (spas_sage_attn / sparse_sageattn)
  $spargeErrors = @()
  $spargeSource = "none"
  $spargeVersion = $null
  $spargeSuccess = $false
  $spargeTorchReady = $true
  $spargePackageInfo = Get-FirstPackageVersion -Python $python -PackageNames @("spas_sage_attn", "sparse_sageattn")
  $spargeUrl = "none"
  $spargeGateReason = $null
  $spargeRequested = "spargeattn (pattern=spargeattn)"
  $spargeStderr = $null

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
      $ghUrl = Resolve-GitHubReleaseWheelUrl -Python $python -Repository "thu-ml/SpargeAttn" -PackagePattern "(spas|sparse).*sage.*attn.*\.whl"
      if ($ghUrl) {
        $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from GitHub release" -Arguments @("install", "--no-deps", "--force-reinstall", $ghUrl)
        if ($installAttempt.Success) {
          $spargeSource = "github-release"
          $spargeSuccess = $true
          $spargeErrors = @()
          $spargeUrl = $ghUrl
          $spargeStderr = Get-Excerpt -Text $installAttempt.Stderr
        } else {
          $spargeErrors += $installAttempt.Error
          $spargeStderr = Get-Excerpt -Text $installAttempt.Stderr
        }
      } else {
        $spargeErrors += "GitHub release wheel unavailable"
      }
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
      $buildTools = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn build prerequisites" -Arguments @("install", "--upgrade", "pip", "setuptools", "wheel", "ninja")
      if (-not $buildTools.Success) {
        $spargeErrors += $buildTools.Error
        $spargeStderr = Get-Excerpt -Text $buildTools.Stderr
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
            $buildOutput = & $python -s -m pip wheel . -w dist --no-deps --no-build-isolation 2>&1 | Out-String
            if ($buildOutput) {
              Write-Host $buildOutput.TrimEnd()
            }
            if ($LASTEXITCODE -ne 0) {
              $spargeErrors += "SpargeAttn wheel build failed"
            } else {
              $wheel = Get-ChildItem -Path "dist" -Filter "*.whl" | Sort-Object LastWriteTime | Select-Object -Last 1
              if (-not $wheel) {
                $spargeErrors += "SpargeAttn wheel not found after build"
              } else {
                $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from source wheel" -Arguments @("install", "--no-deps", $wheel.FullName)
                if ($installAttempt.Success) {
                  $importOutput = & $python -c "import spas_sage_attn; print('spas_sage_attn OK')" 2>&1 | Out-String
                  if ($importOutput) {
                    Write-Host $importOutput.TrimEnd()
                  }
                  if ($LASTEXITCODE -ne 0) {
                    $spargeErrors += "SpargeAttn import check failed after source wheel install"
                  } else {
                    $spargeSource = "source"
                    $spargeSuccess = $true
                    $spargeErrors = @()
                  }
                  $spargeStderr = Get-Excerpt -Text $installAttempt.Stderr
                } else {
                  $spargeErrors += $installAttempt.Error
                  $spargeStderr = Get-Excerpt -Text $installAttempt.Stderr
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

  if (-not $spargeSuccess -and $spargeNightlyEnabled -and $spargeTorchReady) {
    $resolved = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "spargeattn" -TorchInfo $torchInfo -PythonTag $pythonTag -AllowAbi3
    if ($resolved.requested) {
      $spargeRequested = $resolved.requested
    }
    if ($resolved.url) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing SpargeAttn from wheel URL" -Arguments @("install", "--no-deps", "--force-reinstall", $resolved.url)
      if ($installAttempt.Success) {
        $spargeSource = $resolved.source
        $spargeSuccess = $true
        $spargeErrors = @()
        $spargeUrl = $resolved.url
        $spargeStderr = Get-Excerpt -Text $installAttempt.Stderr
      } else {
        $spargeErrors += $installAttempt.Error
        $spargeStderr = Get-Excerpt -Text $installAttempt.Stderr
      }
    } else {
      $spargeGateReason = if ($resolved.reason) { $resolved.reason } else { "wheels.json wheel unavailable" }
      $spargeErrors += $spargeGateReason
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
    if (-not $spargeGateReason) {
      $spargeGateReason = $spargeErrorMessage
    }
  }
  Add-Result -Name "spargeattn" -Requested $spargeRequested -Version $spargeVersion -Source $spargeSource -Success $spargeSuccess -Url $spargeUrl -GateReason $spargeGateReason -ErrorMessage (if ($spargeErrors.Count -gt 0) { $spargeErrors -join " | " } else { $null }) -StderrExcerpt $spargeStderr
  Invoke-TorchGuard -Python $python -Root $root -Label "spargeattn install group"

  # NATTEN
  $nattenErrors = @()
  $nattenSource = "none"
  $nattenVersion = Get-PackageVersion -Python $python -PackageName "natten"
  $nattenSuccess = $false
  $nattenUrl = "none"
  $nattenGateReason = $null
  $nattenRequested = "natten (pattern=natten)"
  $nattenStderr = $null

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
      $nattenStderr = Get-Excerpt -Text $installAttempt.Stderr
    } else {
      $nattenErrors += $installAttempt.Error
      $nattenStderr = Get-Excerpt -Text $installAttempt.Stderr
    }
  }

  if (-not $nattenSuccess) {
    $resolved = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "natten" -TorchInfo $torchInfo -PythonTag $pythonTag -AllowAbi3
    if ($resolved.requested) {
      $nattenRequested = $resolved.requested
    }
    if ($resolved.url) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing natten from AI-windows-whl wheel URL" -Arguments @("install", "--no-deps", "--force-reinstall", $resolved.url)
      if ($installAttempt.Success) {
        $nattenSource = $resolved.source
        $nattenSuccess = $true
        $nattenErrors = @()
        $nattenUrl = $resolved.url
        $nattenStderr = Get-Excerpt -Text $installAttempt.Stderr
      } else {
        $nattenErrors += $installAttempt.Error
        $nattenStderr = Get-Excerpt -Text $installAttempt.Stderr
      }
    } else {
      $nattenGateReason = if ($resolved.reason) { $resolved.reason } else { "wheels.json wheel unavailable" }
      $nattenErrors += $nattenGateReason
    }
  }

  if (-not $nattenSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing natten from source" -Arguments @("install", "--no-binary", ":all:", "natten")
    if ($installAttempt.Success) {
      $nattenSource = "source"
      $nattenSuccess = $true
      $nattenErrors = @()
      $nattenStderr = Get-Excerpt -Text $installAttempt.Stderr
    } else {
      $nattenErrors += $installAttempt.Error
      $nattenStderr = Get-Excerpt -Text $installAttempt.Stderr
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
    if (-not $nattenGateReason) {
      $nattenGateReason = $nattenErrorMessage
    }
  }
  Add-Result -Name "natten" -Requested $nattenRequested -Version $nattenVersion -Source $nattenSource -Success $nattenSuccess -Url $nattenUrl -GateReason $nattenGateReason -ErrorMessage (if ($nattenErrors.Count -gt 0) { $nattenErrors -join " | " } else { $null }) -StderrExcerpt $nattenStderr
  Invoke-TorchGuard -Python $python -Root $root -Label "natten install group"

  # bitsandbytes
  $bnbErrors = @()
  $bnbSource = "none"
  $bnbVersion = Get-PackageVersion -Python $python -PackageName "bitsandbytes"
  $bnbSuccess = $false
  $bnbUrl = "none"
  $bnbGateReason = $null
  $bnbRequested = "bitsandbytes (pattern=bitsandbytes)"
  $bnbStderr = $null

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
      $bnbStderr = Get-Excerpt -Text $installAttempt.Stderr
    } else {
      $bnbErrors += $installAttempt.Error
      $bnbStderr = Get-Excerpt -Text $installAttempt.Stderr
    }
  }

  if (-not $bnbSuccess) {
    $resolved = Resolve-AIWindowsWheelUrl -Python $python -PackagePattern "bitsandbytes" -TorchInfo $torchInfo -PythonTag $pythonTag -AllowAbi3
    if ($resolved.requested) {
      $bnbRequested = $resolved.requested
    }
    if ($resolved.url) {
      $installAttempt = Invoke-PipInstall -Python $python -Label "Installing bitsandbytes from AI-windows-whl wheel URL" -Arguments @("install", "--no-deps", "--force-reinstall", $resolved.url)
      if ($installAttempt.Success) {
        $bnbSource = $resolved.source
        $bnbSuccess = $true
        $bnbErrors = @()
        $bnbUrl = $resolved.url
        $bnbStderr = Get-Excerpt -Text $installAttempt.Stderr
      } else {
        $bnbErrors += $installAttempt.Error
        $bnbStderr = Get-Excerpt -Text $installAttempt.Stderr
      }
    } else {
      $bnbGateReason = if ($resolved.reason) { $resolved.reason } else { "wheels.json wheel unavailable" }
      $bnbErrors += $bnbGateReason
    }
  }

  if (-not $bnbSuccess) {
    $installAttempt = Invoke-PipInstall -Python $python -Label "Installing bitsandbytes from source" -Arguments @("install", "--no-binary", ":all:", "bitsandbytes")
    if ($installAttempt.Success) {
      $bnbSource = "source"
      $bnbSuccess = $true
      $bnbErrors = @()
      $bnbStderr = Get-Excerpt -Text $installAttempt.Stderr
    } else {
      $bnbErrors += $installAttempt.Error
      $bnbStderr = Get-Excerpt -Text $installAttempt.Stderr
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
    if (-not $bnbGateReason) {
      $bnbGateReason = $bnbErrorMessage
    }
  }
  Add-Result -Name "bitsandbytes" -Requested $bnbRequested -Version $bnbVersion -Source $bnbSource -Success $bnbSuccess -Url $bnbUrl -GateReason $bnbGateReason -ErrorMessage (if ($bnbErrors.Count -gt 0) { $bnbErrors -join " | " } else { $null }) -StderrExcerpt $bnbStderr
  Invoke-TorchGuard -Python $python -Root $root -Label "bitsandbytes install group"
} catch {
  Write-Warning "Optional accelerator install encountered an unexpected error: $($_.Exception.Message)"
}

$existingResults = Read-JsonFileSafe -Path $manifestPath -SourceLabel "accel_manifest.json"

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
