param(
  [Parameter(Mandatory = $true)]
  [string]$PinnedUrl,
  [string]$PinnedSha256 = "",
  [string]$ApiUrl = "https://api.github.com/repos/astral-sh/python-build-standalone/releases?per_page=5"
)

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
  if ($env:GITHUB_OUTPUT) {
    "{0}={1}" -f $Name, $Value | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
  }
}

function Get-PinnedTag {
  param([string]$Url)
  if ($Url -match "/releases/download/([^/]+)/") {
    return $Matches[1]
  }
  return "pinned"
}

function Get-Sha256FromSums {
  param(
    [string]$ShaUrl,
    [string]$AssetName,
    [hashtable]$Headers
  )
  if (-not $ShaUrl) {
    return ""
  }
  try {
    $shaResponse = Invoke-WebRequest -Uri $ShaUrl -Headers $Headers -Method Get
  } catch {
    Write-Warning "Failed to fetch SHA256SUMS from $ShaUrl: $($_.Exception.Message)"
    return ""
  }
  $content = $shaResponse.Content
  if (-not $content) {
    return ""
  }
  foreach ($line in ($content -split "`n")) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }
    if ($trimmed -match '^(?<sha>[a-fA-F0-9]{64})\s+\*?(?<file>\S+)$') {
      if ($Matches.file -eq $AssetName) {
        return $Matches.sha.ToLowerInvariant()
      }
    }
  }
  return ""
}

$pinnedTag = Get-PinnedTag -Url $PinnedUrl
$root = ($PinnedUrl -split "/releases/download/")[0] + "/releases/download/"

Write-Host "Pinned Python URL: $PinnedUrl"
Write-Host "Pinned Python tag: $pinnedTag"
if ($PinnedSha256) {
  Write-Host "Pinned Python SHA256: $PinnedSha256"
}
Write-Host "Latest attempt root: $root"

$headers = @{}
if ($env:GITHUB_TOKEN) {
  $headers.Authorization = "token $env:GITHUB_TOKEN"
} else {
  Write-Warning "GITHUB_TOKEN not set; GitHub API calls may be rate-limited."
}
$resolvedUrl = ""
$resolvedTag = ""
$resolvedSha = ""

try {
  $response = Invoke-WebRequest -Uri $ApiUrl -Headers $headers -Method Get
  $content = $response.Content
} catch {
  $statusCode = $_.Exception.Response.StatusCode.value__ 2>$null
  if ($statusCode -eq 403) {
    Write-Warning "Latest attempt hit GitHub API rate limits; falling back to pinned."
  } else {
    Write-Warning "Latest attempt failed to fetch GitHub API: $($_.Exception.Message)"
  }
  $content = ""
}

if (-not $content) {
  Write-Warning "Latest attempt returned empty response; falling back to pinned."
} elseif (-not (Test-Json -Json $content)) {
  Write-Warning "Latest attempt returned non-JSON response; falling back to pinned."
} else {
  $releases = $content | ConvertFrom-Json
  $pattern = '^cpython-3\.13\.\d+\+\d+-x86_64-pc-windows-msvc-install_only\.tar\.gz$'
  foreach ($release in $releases) {
    foreach ($asset in ($release.assets | Where-Object { $_ })) {
      $name = $asset.name
      if ($name -match $pattern) {
        $resolvedTag = $release.tag_name
        $resolvedUrl = $asset.browser_download_url
        if (-not $resolvedUrl -or -not $resolvedUrl.StartsWith($root)) {
          $resolvedUrl = "${root}${resolvedTag}/${name}"
        }
        $shaAsset = $release.assets | Where-Object { $_.name -eq "SHA256SUMS" } | Select-Object -First 1
        $shaUrl = ""
        if ($shaAsset) {
          $shaUrl = $shaAsset.browser_download_url
        }
        if (-not $shaUrl -and $resolvedTag) {
          $shaUrl = "${root}${resolvedTag}/SHA256SUMS"
        }
        if ($shaUrl) {
          $resolvedSha = Get-Sha256FromSums -ShaUrl $shaUrl -AssetName $name -Headers $headers
          if (-not $resolvedSha) {
            Write-Warning "Latest attempt failed to resolve SHA256 for $name from $shaUrl"
          }
        } else {
          Write-Warning "Latest attempt could not find SHA256SUMS asset for tag $resolvedTag"
        }
        break
      }
    }
    if ($resolvedUrl) { break }
  }
}

if ($resolvedUrl) {
  Write-Host "Latest attempt candidate: $resolvedUrl"
  try {
    Invoke-WebRequest -Uri $resolvedUrl -Method Head | Out-Null
  } catch {
    Write-Warning "Latest attempt failed to access candidate; falling back to pinned."
    $resolvedUrl = ""
    $resolvedTag = ""
    $resolvedSha = ""
  }
}

if ($resolvedUrl -and -not $resolvedSha) {
  Write-Warning "Latest attempt missing SHA256 for resolved asset; falling back to pinned."
  $resolvedUrl = ""
  $resolvedTag = ""
}

if (-not $resolvedUrl) {
  $finalUrl = $PinnedUrl
  $finalTag = $pinnedTag
  $finalSha = $PinnedSha256
  Write-Host "Fallback pinned URL: $finalUrl"
} else {
  $finalUrl = $resolvedUrl
  $finalTag = $resolvedTag
  $finalSha = $resolvedSha
  Write-Host "Resolved latest URL: $finalUrl"
}

Write-Host "Final Python URL: $finalUrl"
Write-Host "Final Python tag: $finalTag"
if ($finalSha) {
  Write-Host "Final Python SHA256: $finalSha"
} else {
  Write-Warning "Final Python SHA256 is empty."
}

Write-EnvValue -Name "PYTHON_STANDALONE_URL" -Value $finalUrl
Write-EnvValue -Name "PYTHON_STANDALONE_TAG" -Value $finalTag
if ($finalSha) {
  Write-EnvValue -Name "PYTHON_STANDALONE_SHA256" -Value $finalSha
}
