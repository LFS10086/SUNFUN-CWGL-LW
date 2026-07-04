#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${SANFENG_CLOUD_DATA_DIR:-/data/sanfeng-finance}"
BACKUP_DIR="${SANFENG_BACKUP_DIR:-/data/sanfeng-finance-backups}"
KEEP_BACKUPS="${SANFENG_KEEP_BACKUPS:-14}"

if [ ! -d "$DATA_DIR" ]; then
  echo "Data directory does not exist: $DATA_DIR" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="$BACKUP_DIR/sanfeng-finance-$STAMP.tar.gz"

tar -czf "$TARGET" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")"
chmod 600 "$TARGET"

find "$BACKUP_DIR" -maxdepth 1 -type f -name 'sanfeng-finance-*.tar.gz' \
  | sort -r \
  | awk -v keep="$KEEP_BACKUPS" 'NR > keep { print }' \
  | xargs -r rm -f

echo "$TARGET"
