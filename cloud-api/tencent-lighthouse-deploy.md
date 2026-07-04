# 腾讯云轻量应用服务器部署命令

以下命令在腾讯云轻量应用服务器 SSH 终端执行。

```bash
sudo mkdir -p /opt/sanfeng-cloud-api /data/sanfeng-finance
sudo chown -R $USER:$USER /opt/sanfeng-cloud-api /data/sanfeng-finance
cd /opt/sanfeng-cloud-api
npm install --omit=dev
export PORT=8787
export SANFENG_CLOUD_DATA_DIR=/data/sanfeng-finance
export SANFENG_JWT_SECRET=请改成一串很长的随机密钥
npm start
```

验证：

```bash
curl http://127.0.0.1:8787/api/health
curl http://127.0.0.1:8787/api/health/storage
```

腾讯云防火墙需要放通 `8787` 端口。正式使用建议使用 Nginx 配置 HTTPS，再让桌面端填写 HTTPS 地址。

如需限制浏览器来源，可编辑：

```bash
sudo nano /etc/sanfeng-cloud-api.env
```

设置：

```env
SANFENG_ALLOWED_ORIGINS=https://api.example.com,https://finance.example.com
```

当前桌面端使用可保持为空。

Windows 本机公网验收：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\verify-remote-api.ps1 -ApiUrl http://服务器IP:8787
```

Windows 一键预检、部署并验收：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\deploy-full-from-windows.ps1 -HostName 服务器IP -User root
```

正式域名 HTTPS：

```bash
sudo /opt/sanfeng-cloud-api/deploy/setup-nginx-https.sh \
  --domain api.example.com \
  --email admin@example.com
```

执行前确认域名已经解析到服务器公网 IP，并且腾讯云防火墙已放通 `80/TCP`、`443/TCP`。

验证：

```bash
curl https://api.example.com/api/health
curl https://api.example.com/api/health/storage
```

HTTPS 公网验收：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\verify-remote-api.ps1 -ApiUrl https://api.example.com
```

带 HTTPS 的一键部署：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\deploy-full-from-windows.ps1 `
  -HostName 服务器IP `
  -User root `
  -Domain api.example.com `
  -Email admin@example.com
```

远程诊断：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\collect-remote-diagnostics.ps1 -HostName 服务器IP -User root
```

自动备份验证：

```bash
sudo systemctl status sanfeng-cloud-api-backup.timer --no-pager
sudo systemctl start sanfeng-cloud-api-backup.service
ls -lh /data/sanfeng-finance-backups
```
