param(
  [Parameter(Mandatory = $true)]
  [string]$ApiUrl
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$apiUrl = $ApiUrl.TrimEnd("/")

if ($apiUrl -notmatch "^https?://") {
  throw "ApiUrl must start with http:// or https://, for example http://SERVER_IP:8787 or https://api.example.com"
}

Write-Host "Verifying cloud API: $($apiUrl)"
$env:SANFENG_CLOUD_API_URL = $apiUrl
try {
  Push-Location $root
  npm run verify:remote
  Write-Host ""
  Write-Host "Cloud API verification passed. Client cloud API URL: $($apiUrl)"
} finally {
  Pop-Location
  Remove-Item Env:\SANFENG_CLOUD_API_URL -ErrorAction SilentlyContinue
}
