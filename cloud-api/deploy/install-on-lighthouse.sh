#!/usr/bin/env bash
set -euo pipefail

APP_DIR=/opt/sanfeng-cloud-api
DATA_DIR=/data/sanfeng-finance

sudo mkdir -p "$APP_DIR" "$DATA_DIR"
sudo cp -r . "$APP_DIR"
sudo cp "$APP_DIR/deploy/sanfeng-cloud-api.env" /etc/sanfeng-cloud-api.env
sudo chmod +x "$APP_DIR/deploy/backup-data.sh" "$APP_DIR/deploy/restore-data.sh" "$APP_DIR/deploy/setup-nginx-https.sh"
sudo chown -R www-data:www-data "$APP_DIR" "$DATA_DIR"

cd "$APP_DIR"
sudo npm install --omit=dev

echo "请先编辑 /etc/sanfeng-cloud-api.env，把 SANFENG_JWT_SECRET 改成随机长密钥。"
echo "确认后执行："
echo "sudo cp $APP_DIR/deploy/sanfeng-cloud-api.service /etc/systemd/system/sanfeng-cloud-api.service"
echo "sudo cp $APP_DIR/deploy/sanfeng-cloud-api-backup.service /etc/systemd/system/sanfeng-cloud-api-backup.service"
echo "sudo cp $APP_DIR/deploy/sanfeng-cloud-api-backup.timer /etc/systemd/system/sanfeng-cloud-api-backup.timer"
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable --now sanfeng-cloud-api"
echo "sudo systemctl enable --now sanfeng-cloud-api-backup.timer"
echo "curl http://127.0.0.1:8787/api/health"
echo "curl http://127.0.0.1:8787/api/health/storage"
