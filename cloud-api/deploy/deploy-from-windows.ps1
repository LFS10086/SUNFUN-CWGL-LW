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
  [string]$DataDir = "/data/sanfeng-finance"
)

$ErrorActionPreference = "Stop"

$package = "D:\workspace\sanfeng-cloud-api-tencent.zip"
if (!(Test-Path -LiteralPath $package)) {
  throw "Deployment package not found: $package. Regenerate it first."
}

$remote = "${User}@${HostName}"
$sshArgs = @("-p", "$Port")
$scpArgs = @("-P", "$Port")
if ($SshKeyPath) {
  $sshArgs = @("-i", $SshKeyPath) + $sshArgs
  $scpArgs = @("-i", $SshKeyPath) + $scpArgs
}

Write-Host "Uploading cloud API package to $remote ..."
ssh @sshArgs $remote "mkdir -p /tmp/sanfeng-cloud-api-upload"
scp @scpArgs $package "${remote}:/tmp/sanfeng-cloud-api-upload/sanfeng-cloud-api-tencent.zip"

$remoteScript = @'
set -e
sudo mkdir -p '__REMOTE_DIR__' '__DATA_DIR__'
sudo rm -rf '__REMOTE_DIR__'/*
sudo unzip -o /tmp/sanfeng-cloud-api-upload/sanfeng-cloud-api-tencent.zip -d '__REMOTE_DIR__'
cd '__REMOTE_DIR__'
sudo npm install --omit=dev
sudo chmod +x '__REMOTE_DIR__/deploy/backup-data.sh' '__REMOTE_DIR__/deploy/restore-data.sh' '__REMOTE_DIR__/deploy/setup-nginx-https.sh'
if [ ! -f /etc/sanfeng-cloud-api.env ]; then
  SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
  sudo sh -c "cat > /etc/sanfeng-cloud-api.env <<EOF
PORT=8787
SANFENG_CLOUD_DATA_DIR=__DATA_DIR__
SANFENG_JWT_SECRET=$SECRET
SANFENG_ALLOWED_ORIGINS=
EOF"
fi
sudo chown -R www-data:www-data '__REMOTE_DIR__' '__DATA_DIR__' || true
sudo cp '__REMOTE_DIR__/deploy/sanfeng-cloud-api.service' /etc/systemd/system/sanfeng-cloud-api.service
sudo cp '__REMOTE_DIR__/deploy/sanfeng-cloud-api-backup.service' /etc/systemd/system/sanfeng-cloud-api-backup.service
sudo cp '__REMOTE_DIR__/deploy/sanfeng-cloud-api-backup.timer' /etc/systemd/system/sanfeng-cloud-api-backup.timer
sudo systemctl daemon-reload
sudo systemctl enable --now sanfeng-cloud-api
sudo systemctl enable --now sanfeng-cloud-api-backup.timer
sudo systemctl restart sanfeng-cloud-api
sleep 2
curl -fsS http://127.0.0.1:8787/api/health
curl -fsS http://127.0.0.1:8787/api/health/storage
'@

$remoteScript = $remoteScript.Replace("__REMOTE_DIR__", $RemoteDir).Replace("__DATA_DIR__", $DataDir)

Write-Host "Installing and starting remote service ..."
$remoteScript | ssh @sshArgs $remote "bash -s"

Write-Host ""
Write-Host "Deployment completed. Open Tencent Cloud firewall port 8787."
Write-Host "Client cloud API URL: http://$HostName`:8787"
Write-Host "Daily 03:20 backup timer is enabled. Default backup directory: $DataDir-backups."
