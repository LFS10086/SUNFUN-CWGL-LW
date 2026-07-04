#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: sudo SANFENG_CLOUD_DATA_DIR=/data/sanfeng-finance $0 /path/to/backup.tar.gz" >&2
  exit 1
fi

BACKUP_FILE="$1"
DATA_DIR="${SANFENG_CLOUD_DATA_DIR:-/data/sanfeng-finance}"
BACKUP_DIR="${SANFENG_BACKUP_DIR:-/data/sanfeng-finance-backups}"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file does not exist: $BACKUP_FILE" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
if [ -d "$DATA_DIR" ]; then
  PRE_RESTORE="$BACKUP_DIR/pre-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar -czf "$PRE_RESTORE" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
  chmod 600 "$PRE_RESTORE"
  echo "Created pre-restore backup: $PRE_RESTORE"
fi

systemctl stop sanfeng-cloud-api 2>/dev/null || true
rm -rf "$DATA_DIR"
mkdir -p "$(dirname "$DATA_DIR")"
tar -xzf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")"
chown -R www-data:www-data "$DATA_DIR" 2>/dev/null || true
systemctl start sanfeng-cloud-api 2>/dev/null || true

echo "Restored data directory from: $BACKUP_FILE"
