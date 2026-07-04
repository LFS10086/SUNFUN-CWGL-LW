# SUNFUN-CWGL-LW

三峰整装财务收支管理系统联网版与腾讯云部署资料仓库。

## 客户下载

请到 Releases 下载完整交付包：

https://github.com/LFS10086/SUNFUN-CWGL-LW/releases/tag/tencent-deploy-kit-20260704

交付包内包含：

- `sanfeng-cloud-api-tencent.zip`：腾讯云后端部署包
- `服务器信息填写模板.txt`：客户填写公网 IP、SSH、域名、防火墙等信息
- `腾讯云开通部署清单.md`：服务器开通与部署检查清单
- `README.md`：部署、HTTPS、验收、诊断命令说明

## 仓库目录

- `cloud-api/`：联网版 Node.js 后端源码、部署脚本、验收脚本和腾讯云部署文档。
- `服务器信息填写模板.txt`：服务器信息表。
- `腾讯云开通部署清单.md`：开通与部署清单。

## 与本地版仓库的关系

本地运行版项目源码和桌面端构建配置保存在：

https://github.com/LFS10086/SUNFUN-CWGL

本仓库只放联网腾讯云部署相关内容，避免客户把本地版和云端部署资料混淆。