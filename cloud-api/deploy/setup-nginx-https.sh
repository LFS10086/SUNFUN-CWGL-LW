#!/usr/bin/env bash
set -euo pipefail

DOMAIN=""
EMAIL=""
API_PORT="${PORT:-8787}"
ENABLE_CERTBOT=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --email)
      EMAIL="${2:-}"
      shift 2
      ;;
    --port)
      API_PORT="${2:-8787}"
      shift 2
      ;;
    --no-certbot)
      ENABLE_CERTBOT=0
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: sudo $0 --domain api.example.com --email you@example.com [--port 8787] [--no-certbot]" >&2
      exit 1
      ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  echo "Missing --domain" >&2
  echo "Usage: sudo $0 --domain api.example.com --email you@example.com [--port 8787] [--no-certbot]" >&2
  exit 1
fi

if [ "$ENABLE_CERTBOT" = "1" ] && [ -z "$EMAIL" ]; then
  echo "Missing --email when certbot is enabled" >&2
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  apt-get update
  apt-get install -y nginx
fi

cat > "/etc/nginx/sites-available/sanfeng-cloud-api" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    client_max_body_size 100m;

    location / {
        proxy_pass http://127.0.0.1:$API_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sfn /etc/nginx/sites-available/sanfeng-cloud-api /etc/nginx/sites-enabled/sanfeng-cloud-api
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

if [ "$ENABLE_CERTBOT" = "1" ]; then
  if ! command -v certbot >/dev/null 2>&1; then
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
  fi
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect
fi

echo "Nginx is ready."
echo "Health: http://$DOMAIN/api/health"
if [ "$ENABLE_CERTBOT" = "1" ]; then
  echo "HTTPS Health: https://$DOMAIN/api/health"
fi
