param(
  [Parameter(Mandatory = $true)]
  [string]$HostName,

  [Parameter(Mandatory = $false)]
  [string]$User = "root",

  [Parameter(Mandatory = $false)]
  [string]$SshKeyPath = "",

  [Parameter(Mandatory = $false)]
  [int]$Port = 22,

  [Parameter(Mandatory = $false)]
  [string]$RemoteDir = "/opt/sanfeng-cloud-api",

  [Parameter(Mandatory = $false)]
  [string]$DataDir = "/data/sanfeng-finance",

  [Parameter(Mandatory = $false)]
  [string]$Domain = "",

  [Parameter(Mandatory = $false)]
  [string]$Email = ""
)

$ErrorActionPreference = "Stop"

$deployDir = $PSScriptRoot
$preflight = Join-Path $deployDir "preflight-from-windows.ps1"
$deploy = Join-Path $deployDir "deploy-from-windows.ps1"
$verify = Join-Path $deployDir "verify-remote-api.ps1"

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )
  Write-Host ""
  Write-Host "==> $Name"
  & $Action
}

$commonArgs = @{
  HostName = $HostName
  User = $User
  Port = $Port
}
if ($SshKeyPath) {
  $commonArgs.SshKeyPath = $SshKeyPath
}

Invoke-Step "Preflight SSH and runtime" {
  & $preflight @commonArgs
}

Invoke-Step "Deploy cloud API service" {
  $deployArgs = $commonArgs.Clone()
  $deployArgs.RemoteDir = $RemoteDir
  $deployArgs.DataDir = $DataDir
  & $deploy @deployArgs
}

$httpApiUrl = "http://$HostName`:8787"
Invoke-Step "Verify HTTP API read/write" {
  & $verify -ApiUrl $httpApiUrl
}

if ($Domain) {
  if (!$Email) {
    throw "When -Domain is provided, -Email is required for HTTPS certificate registration."
  }

  $remote = "$User@$HostName"
  $sshArgs = @("-p", "$Port")
  if ($SshKeyPath) {
    $sshArgs = @("-i", $SshKeyPath) + $sshArgs
  }

  Invoke-Step "Configure Nginx and HTTPS for $Domain" {
    ssh @sshArgs $remote "sudo '$RemoteDir/deploy/setup-nginx-https.sh' --domain '$Domain' --email '$Email'"
    if ($LASTEXITCODE -ne 0) {
      throw "HTTPS setup failed. Check domain DNS, Tencent Cloud 80/443 firewall rules, and certbot output."
    }
  }

  Invoke-Step "Verify HTTPS API read/write" {
    & $verify -ApiUrl "https://$Domain"
  }
}

Write-Host ""
Write-Host "All requested deployment steps completed."
Write-Host "Client cloud API URL: $(if ($Domain) { "https://$Domain" } else { $httpApiUrl })"
