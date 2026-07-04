param(
  [Parameter(Mandatory = $true)]
  [string]$HostName,

  [Parameter(Mandatory = $false)]
  [string]$User = "root",

  [Parameter(Mandatory = $false)]
  [string]$SshKeyPath = "",

  [Parameter(Mandatory = $false)]
  [int]$Port = 22
)

$ErrorActionPreference = "Stop"

$remote = "${User}@${HostName}"
$sshArgs = @("-p", "$Port", "-o", "BatchMode=yes", "-o", "ConnectTimeout=12")
if ($SshKeyPath) {
  if (!(Test-Path -LiteralPath $SshKeyPath)) {
    throw "SSH key does not exist: $SshKeyPath"
  }
  $sshArgs = @("-i", $SshKeyPath) + $sshArgs
}

Write-Host "Checking SSH connection: $remote ..."

$script = @'
set -e
echo "whoami=$(whoami)"
echo "kernel=$(uname -a)"
if command -v node >/dev/null 2>&1; then
  echo "node=$(node -v)"
else
  echo "node=MISSING"
fi
if command -v npm >/dev/null 2>&1; then
  echo "npm=$(npm -v)"
else
  echo "npm=MISSING"
fi
if command -v unzip >/dev/null 2>&1; then
  echo "unzip=OK"
else
  echo "unzip=MISSING"
fi
if command -v sudo >/dev/null 2>&1; then
  echo "sudo=OK"
else
  echo "sudo=MISSING"
fi
'@

$output = $script | ssh @sshArgs $remote "bash -s"
$output

if ($LASTEXITCODE -ne 0) {
  throw "SSH preflight failed. Check IP, username, password/key, and Tencent Cloud firewall port 22."
}

if ($output -match "node=MISSING" -or $output -match "npm=MISSING") {
  Write-Warning "Node.js or npm is missing. Use a Tencent Lighthouse Node.js image or install Node.js first."
}
if ($output -match "unzip=MISSING") {
  Write-Warning "unzip is missing. Ubuntu command: sudo apt-get update && sudo apt-get install -y unzip"
}

Write-Host "Preflight completed. If there is no WARNING, run deploy-from-windows.ps1."
