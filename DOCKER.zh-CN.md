# Mistgate 管理面板：Docker Compose 与 GHCR 发布（Fork 适配）

**适用范围：只容器化管理面板；节点 Agent 继续使用官方宿主机 systemd 安装方式。**
本方案非 Mistgate 官方支持的 Docker 发行方式。

## GitHub Actions：自动构建多架构镜像

仓库的 `.github/workflows/docker-ghcr.yml` 在推送到 `main` 或手动执行 `workflow_dispatch` 时：

- 构建当前 Fork 的 React/TypeScript 前端，再由 Go 将 `web/dist` 内嵌编译到面板；
- 构建 `linux/amd64` 和 `linux/arm64`；
- 推送到 `ghcr.io/jonathan143/mistgate-panel:main`、`:latest`、`:sha-<short-hash>`；
- 检查多架构镜像 manifest，并运行 Linux amd64 的 `mistgate version`。

Actions 使用 `GITHUB_TOKEN` 与 `packages: write`，一般不需要自行创建 PAT。**GitHub Fork 的 Actions 可能默认关闭**，需要在本仓库的 Actions 页面启用。首次创建 GHCR Package 后，默认可能是 Private，需要到 Package 设置中改为 Public 才能匿名拉取。

## 在 VPS 上部署

先确保域名 A/AAAA 记录**直连**服务器，Cloudflare 使用 DNS Only（灰云）；公网 TCP/80、TCP/443 可达，服务器没有其他服务占用这两个端口。

```bash
mkdir -p /opt/mistgate && cd /opt/mistgate
# 将仓库里的 compose.yaml 和 .env.example 下载至此
cp .env.example .env
nano .env  # 修改 PANEL_DOMAIN
mkdir -p data && chmod 700 data

docker compose config
docker compose pull
docker compose run --rm --no-deps mistgate setup
# 保存输出的 Admin URL 和完整 Setup link（含 # 后面的 token，约 30 分钟有效）
docker compose up -d
docker compose logs -f --tail=100 mistgate
```

如系统上仍有旧版 Mistgate 容器或 systemd 服务占用端口，先按需备份数据并迁移，避免冲突；不要直接覆盖正在使用的数据库。

## 更新与备份

```bash
cd /opt/mistgate
docker compose pull
docker compose stop mistgate
tar -czf "/root/mistgate-backup-$(date +%F-%H%M).tar.gz" data
docker compose up -d
docker compose logs --tail=100 mistgate
```

`data/` 包括 SQLite、`master.key`、CA 与敏感证书材料；请加密离线备份。新版本可能进行不可逆迁移，回滚时务必**同时恢复旧版数据**。

## 注意

- 该容器不包含 systemd，**不能使用后台内置的面板自更新功能**，通过重新拉取镜像更新。
- 镜像编译时从上游 `scripts/install.sh` 提取**公有** Ed25519 Release 验证密钥，继续信任上游签名节点包；未包含任何发布私钥。
- 使用 Fork 修改后，自定义面板镜像并不因此成为上游官方签名版本。
- VPS 如果只有 NAT 映射端口，不要直接照搬默认直连 80/443 方案；需要额外设计 TLS、证书和 Agent 地址。
- 此仓库遵守 AGPL-3.0-only 许可证；管理面板提供 Fork 的源码链接。

参考：[上游安装说明](https://github.com/Mistgate/mistgate/blob/main/docs/en/getting-started/install-panel.md)、[配置说明](https://github.com/Mistgate/mistgate/blob/main/docs/en/reference/configuration.md)。
