# FullOn v0.9.0 Docker Compose 部署

以下示例分别用于普通节点、BP 节点和 History 节点。普通节点和 BP 使用 `flon-node`，History 使用 `flon-node-history`。

## 准备

```bash
cd deploy
cp .env.example .env
mkdir -p data/common data/bp data/history snapshots wallet workspace
```

编辑 `.env`，至少设置可用的 `P2P_PEER`。将目标网络的 `genesis.json` 复制到对应配置目录；从 snapshot 启动时，把文件放入 `snapshots/` 并设置 `SNAPSHOT_FILE`。不要提交 `.env`、BP 私钥、钱包、snapshot 或节点数据。

## 普通节点

```bash
cp /path/to/genesis.json config/common/genesis.json
docker compose --env-file .env -f compose.common.yaml pull
docker compose --env-file .env -f compose.common.yaml up -d
docker compose --env-file .env -f compose.common.yaml ps
```

普通节点提供 chain/net API，不启用 producer 或 state-history 插件。

## BP 节点

```bash
cp config/bp/config.ini.example config/bp/config.ini
cp /path/to/genesis.json config/bp/genesis.json
chmod 600 config/bp/config.ini
```

在 `config/bp/config.ini` 中填写一个 BP 的 `producer-name` 和对应 `signature-provider`。私钥文件已被 `.gitignore` 排除。BP RPC 默认只绑定宿主机 `127.0.0.1`。

```bash
docker compose --env-file .env -f compose.bp.yaml pull
docker compose --env-file .env -f compose.bp.yaml up -d
docker compose --env-file .env -f compose.bp.yaml ps
```

## History 节点

```bash
cp /path/to/genesis.json config/history/genesis.json
docker compose --env-file .env -f compose.history.yaml pull
docker compose --env-file .env -f compose.history.yaml up -d
docker compose --env-file .env -f compose.history.yaml ps
```

History 节点启用 `state_history_plugin`，开放 WebSocket 端口 9555，不包含 BP 私钥，也不生产区块。

## 健康检查和日志

三个节点均通过 `/v1/chain/get_info` 做 Docker healthcheck：

```bash
docker inspect --format '{{.State.Health.Status}}' "$NODE_NAME"
curl -s http://127.0.0.1:${RPC_PORT:-8888}/v1/chain/get_info
docker logs --tail 200 "$NODE_NAME"
```

Docker `json-file` 日志限制为单文件 30 MB。`funod` 以前台进程运行，退出状态会传给 Docker；`restart: unless-stopped` 负责异常重启。

## 升级和回滚

升级前备份配置并创建 snapshot，然后修改 `.env` 中的固定版本：

```bash
docker compose --env-file .env -f compose.common.yaml pull
docker compose --env-file .env -f compose.common.yaml up -d --force-recreate
```

按实际角色替换 Compose 文件。验证镜像版本、chain ID 和 head/LIB 后再清理旧镜像。回滚时恢复旧版本号和对应数据备份，不要让不同二进制同时写一个 data 目录。

## floncdt 编译环境

```bash
cd deploy/cdt
CONTRACTS_DIR=/absolute/path/to/contracts docker compose run --rm cdt cdt-cpp --version
CONTRACTS_DIR=/absolute/path/to/contracts docker compose run --rm cdt \
  cdt-cpp -abigen -I include -o build/contract.wasm src/contract.cpp
```

## 命令行运行环境

`flon-node`/`flon-node-history` 只包含 `funod`。CLI 镜像以官方 `floncdt:v0.9.0` 为基础，并从 flon-core v0.9.0 Release 安装经过 SHA-256 校验的 `flon-core-tools`，提供 `fucli` 和 `fuwal`。

```bash
cd deploy/cli
docker compose build wallet
docker compose up -d wallet cli
docker compose exec cli fucli --wallet-url unix:///wallet/fuwal.sock version client
docker compose exec cli fucli --wallet-url unix:///wallet/fuwal.sock \
  --url https://your-rpc.example.org get info
```

创建或导入钱包时执行 `docker compose exec cli fucli ...`。`deploy/wallet/` 不会进入 Git，但仍应加密备份。RPC URL 必须明确指向目标主网或测试网，提交交易前先核对 `chain_id`。
