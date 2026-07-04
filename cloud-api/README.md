# 三峰整装财务系统云端 API

这是给腾讯云部署用的最小后端。桌面端填写该服务地址后，账户和经销商业务数据会保存到云端。

## 腾讯云推荐部署

1. 购买腾讯云轻量应用服务器 Lighthouse，选择 Node.js 或 Ubuntu 镜像。
2. 放通防火墙端口，例如 `8787`。
3. 上传本目录到服务器，例如 `/opt/sanfeng-cloud-api`。
4. 在服务器执行：

```bash
cd /opt/sanfeng-cloud-api
npm install --omit=dev
export PORT=8787
export SANFENG_CLOUD_DATA_DIR=/data/sanfeng-finance
export SANFENG_JWT_SECRET=请改成一串很长的随机密钥
npm start
```

5. 建议用 Nginx 和 HTTPS 反向代理到 `http://127.0.0.1:8787`。
6. 桌面端登录页“云端 API 地址”填写你的 HTTPS 地址，例如：

```text
https://api.example.com
```

## 数据隔离

- 每个经销商代码独立保存一份数据快照。
- 服务端会校验登录 token 中的 `dealerCode`，不能读取或保存其他经销商代码的数据。
- 删除经销商主账号时，会同步删除该经销商代码下的业务数据文件。

## 正式域名和 HTTPS

临时测试可以让客户端填写 `http://服务器IP:8787`。正式使用建议绑定域名并开启 HTTPS：

```bash
sudo /opt/sanfeng-cloud-api/deploy/setup-nginx-https.sh \
  --domain api.example.com \
  --email admin@example.com
```

执行前需要先把域名 A 记录解析到腾讯云服务器公网 IP，并在腾讯云防火墙放通 `80/TCP` 和 `443/TCP`。

完成后桌面端登录页“云端 API 地址”填写：

```text
https://api.example.com
```

## 浏览器来源白名单

云端 API 支持通过 `SANFENG_ALLOWED_ORIGINS` 限制浏览器来源：

```bash
sudo nano /etc/sanfeng-cloud-api.env
```

示例：

```env
SANFENG_ALLOWED_ORIGINS=https://api.example.com,https://finance.example.com
```

留空时不限制来源，适合当前 Electron 桌面客户端和部署验收脚本。桌面客户端、PowerShell 验收脚本等无 `Origin` 的请求始终允许。

## 注意

当前版本优先解决“云端存储”和“多电脑同账号查看同一套数据”。票据文件仍会随数据快照一起保存，数据量很大时建议下一步接腾讯云 COS。

## 健康检查

部署后可分别检查服务和云端数据目录：

```bash
curl http://127.0.0.1:8787/api/health
curl http://127.0.0.1:8787/api/health/storage
```

`/api/health/storage` 会实际写入并删除一个临时文件，用来确认服务器上的数据目录可写。

从 Windows 本机完整验收公网 API：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\verify-remote-api.ps1 -ApiUrl http://服务器IP:8787
```

如果已经配置 HTTPS：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\verify-remote-api.ps1 -ApiUrl https://api.example.com
```

该脚本会自动测试健康检查、数据目录可写、注册、登录、保存快照和读取快照。

## Windows 一键部署

拿到腾讯云服务器 IP 和 SSH 信息后，可用总控脚本串联预检、部署和公网验收：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\deploy-full-from-windows.ps1 -HostName 服务器IP -User root
```

如果已准备域名并解析到服务器公网 IP，可同时配置 HTTPS：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\deploy-full-from-windows.ps1 `
  -HostName 服务器IP `
  -User root `
  -Domain api.example.com `
  -Email admin@example.com
```

使用私钥时追加 `-SshKeyPath D:\workspace\your-key.pem`。

## 远程诊断

如果部署后访问失败，可从 Windows 本机收集服务器状态和日志：

```powershell
powershell -ExecutionPolicy Bypass -File .\cloud-api\deploy\collect-remote-diagnostics.ps1 -HostName 服务器IP -User root
```

使用私钥时追加 `-SshKeyPath D:\workspace\your-key.pem`。诊断脚本只读取服务状态、日志、端口、Nginx、数据目录和备份目录，不会修改服务器。

## 云端备份

部署脚本会安装 `sanfeng-cloud-api-backup.timer`，每天 03:20 自动备份云端数据目录。

- 默认数据目录：`/data/sanfeng-finance`
- 默认备份目录：`/data/sanfeng-finance-backups`
- 默认保留最近 `14` 份备份

手动备份：

```bash
sudo systemctl start sanfeng-cloud-api-backup.service
ls -lh /data/sanfeng-finance-backups
```

恢复备份：

```bash
sudo SANFENG_CLOUD_DATA_DIR=/data/sanfeng-finance \
  /opt/sanfeng-cloud-api/deploy/restore-data.sh /data/sanfeng-finance-backups/备份文件.tar.gz
```

恢复前脚本会自动再生成一份 `pre-restore-*.tar.gz`，避免误覆盖。
