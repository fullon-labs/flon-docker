# FullOn Docker

FullOn 节点、合约编译和命令行工具的 Docker Compose 部署示例。

## v0.9.0 官方镜像

| 用途 | 镜像 |
| --- | --- |
| 普通节点 / BP 节点 | `ghcr.io/fullon-labs/floncore/flon-node:v0.9.0` |
| History 节点 | `ghcr.io/fullon-labs/floncore/flon-node-history:v0.9.0` |
| floncdt 编译环境 | `ghcr.io/fullon-labs/floncore/floncdt:v0.9.0` |

节点镜像目前为 `linux/amd64`。ARM64 主机应使用支持 amd64 模拟的 Docker，生产节点建议部署在 amd64 主机。

固定版本而不是 `latest`。升级时修改 `deploy/.env` 中的 `FLON_VERSION`，拉取并验证后再重建容器。

## 部署入口

- [普通节点、BP 节点、History 节点](deploy/README.md)
- [floncdt 合约编译环境](deploy/README.md#floncdt-编译环境)
- [fucli / fuwal 命令行运行环境](deploy/README.md#命令行运行环境)

旧的 `flon.chain/` 目录保留用于历史脚本兼容；新部署请使用 `deploy/` 下的 Compose 文件。

主网与测试网使用独立环境文件、genesis、数据目录、snapshot 目录及容器名；详见部署文档的[网络隔离说明](deploy/README.md#主网与测试网隔离)。

## 镜像来源校验

v0.9.0 发布时对应的镜像 digest：

```text
flon-node:v0.9.0         sha256:9f1af9c7640262dc1baae057092f14ad2e57bf3f25a54710b8172d3b408bb7c1
flon-node-history:v0.9.0 sha256:123b19e4656452106e8565e876c80194b07e725793855721df5c9089c0575cc7
```

可用 `docker buildx imagetools inspect IMAGE` 再次核对远端 manifest。
