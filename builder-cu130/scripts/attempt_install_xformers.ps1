$ErrorActionPreference = "Stop"

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

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$python = Join-Path $root "python_standalone/python.exe"

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

$installed = $false
$installed = Try-PipInstall -Python $python -Label "Attempting xformers from PyPI (no deps)" -Arguments @("install", "--no-deps", "xformers")

if (-not $installed) {
  $aiWheelUrl = $env:XFORMERS_AI_WHL_URL
  if (-not $aiWheelUrl) {
    $indexUrl = "https://ai-windows-whl.github.io/whl/xformers/"
    Write-Host "=== Resolving AI-windows-whl xformers wheel from $indexUrl ==="
    try {
      $page = Invoke-WebRequest -Uri $indexUrl -UseBasicParsing
      $matches = [regex]::Matches($page.Content, 'href="([^"]+xformers[^\"]+\.whl)"')
      if ($matches.Count -gt 0) {
        $candidate = $matches[$matches.Count - 1].Groups[1].Value
        if ($candidate -match '^https?://') {
          $aiWheelUrl = $candidate
        } else {
          $aiWheelUrl = "$indexUrl$candidate"
        }
        Write-Host "Resolved AI-windows-whl wheel: $aiWheelUrl"
      } else {
        Write-Warning "No xformers wheel links found at $indexUrl"
      }
    } catch {
      Write-Warning "Failed to query AI-windows-whl index: $($_.Exception.Message)"
    }
  } else {
    Write-Host "Using AI-windows-whl wheel URL from environment: $aiWheelUrl"
  }

  if ($aiWheelUrl) {
    $installed = Try-PipInstall -Python $python -Label "Attempting xformers from AI-windows-whl (no deps)" -Arguments @("install", "--no-deps", $aiWheelUrl)
  } else {
    Write-Warning "AI-windows-whl wheel URL unavailable; skipping fallback."
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

if ($installed) {
  & $python -c "import xformers; print(f'xformers {xformers.__version__} installed')"
  if ($LASTEXITCODE -eq 0 -and $torchVersionAfter -eq $torchVersionBefore) {
    Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "1"
    Write-Host "xformers installed successfully."
    exit 0
  }
}

Write-EnvValue -Name "XFORMERS_AVAILABLE" -Value "0"
Write-Warning "xformers not available; continuing without it."
exit 0
