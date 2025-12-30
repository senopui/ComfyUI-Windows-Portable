param(
  [Parameter(Mandatory = $true)]
  [string]$PinnedUrl,
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

$pinnedTag = Get-PinnedTag -Url $PinnedUrl
$root = ($PinnedUrl -split "/releases/download/")[0] + "/releases/download/"

Write-Host "Pinned Python URL: $PinnedUrl"
Write-Host "Pinned Python tag: $pinnedTag"
Write-Host "Latest attempt root: $root"

$headers = @{ Authorization = "token $env:GITHUB_TOKEN" }
$resolvedUrl = ""
$resolvedTag = ""

try {
  $response = Invoke-WebRequest -Uri $ApiUrl -Headers $headers -Method Get
  $content = $response.Content
} catch {
  Write-Warning "Latest attempt failed to fetch GitHub API: $($_.Exception.Message)"
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
  }
}

if (-not $resolvedUrl) {
  $finalUrl = $PinnedUrl
  $finalTag = $pinnedTag
  Write-Host "Fallback pinned URL: $finalUrl"
} else {
  $finalUrl = $resolvedUrl
  $finalTag = $resolvedTag
  Write-Host "Resolved latest URL: $finalUrl"
}

Write-Host "Final Python URL: $finalUrl"
Write-Host "Final Python tag: $finalTag"

Write-EnvValue -Name "PYTHON_STANDALONE_URL" -Value $finalUrl
Write-EnvValue -Name "PYTHON_STANDALONE_TAG" -Value $finalTag
