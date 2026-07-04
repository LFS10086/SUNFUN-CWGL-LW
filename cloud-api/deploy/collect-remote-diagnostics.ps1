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
$sshArgs = @("-p", "$Port", "-o", "ConnectTimeout=12")
if ($SshKeyPath) {
  if (!(Test-Path -LiteralPath $SshKeyPath)) {
    throw "SSH key does not exist: $SshKeyPath"
  }
  $sshArgs = @("-i", $SshKeyPath) + $sshArgs
}

$script = @'
set +e
echo "==== BASIC ===="
date
whoami
uname -a

echo ""
echo "==== NODE ===="
command -v node && node -v
command -v npm && npm -v

echo ""
echo "==== ENV FILE ===="
if [ -f /etc/sanfeng-cloud-api.env ]; then
  sed -E 's/(SANFENG_JWT_SECRET=).*/\1***MASKED***/' /etc/sanfeng-cloud-api.env
else
  echo "MISSING /etc/sanfeng-cloud-api.env"
fi

echo ""
echo "==== SYSTEMD SERVICE ===="
systemctl status sanfeng-cloud-api --no-pager -l

echo ""
echo "==== SYSTEMD TIMER ===="
systemctl status sanfeng-cloud-api-backup.timer --no-pager -l

echo ""
echo "==== RECENT API LOGS ===="
journalctl -u sanfeng-cloud-api -n 120 --no-pager

echo ""
echo "==== PORTS ===="
ss -lntp | grep -E '(:8787|:80|:443)' || true

echo ""
echo "==== HEALTH ===="
curl -fsS http://127.0.0.1:8787/api/health || true
echo ""
curl -fsS http://127.0.0.1:8787/api/health/storage || true
echo ""

echo ""
echo "==== DATA DIRECTORY ===="
DATA_DIR="$(grep '^SANFENG_CLOUD_DATA_DIR=' /etc/sanfeng-cloud-api.env 2>/dev/null | cut -d= -f2-)"
if [ -z "$DATA_DIR" ]; then DATA_DIR="/data/sanfeng-finance"; fi
ls -lah "$DATA_DIR" 2>/dev/null || true
ls -lah "$DATA_DIR/dealers" 2>/dev/null || true

echo ""
echo "==== BACKUPS ===="
BACKUP_DIR="${DATA_DIR}-backups"
ls -lah "$BACKUP_DIR" 2>/dev/null || true

echo ""
echo "==== NGINX ===="
command -v nginx && nginx -t
systemctl status nginx --no-pager -l
ls -lah /etc/nginx/sites-enabled 2>/dev/null || true

echo ""
echo "==== DISK ===="
df -h
'@

Write-Host "Collecting remote diagnostics from $remote ..."
$script | ssh @sshArgs $remote "bash -s"

if ($LASTEXITCODE -ne 0) {
  throw "Remote diagnostics failed. Check SSH connection and server access."
}
