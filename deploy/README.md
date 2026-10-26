# FullOn v0.9.0 Docker Compose 部署

以下示例分别用于普通节点、BP 节点和 History 节点。普通节点和 BP 使用 `flon-node`，History 使用 `flon-node-history`。

## 主网与测试网隔离

网络必须显式选择，不能共用 `.env`、genesis、节点数据或 snapshot：

| 项目 | 主网 | 测试网 |
| --- | --- | --- |
| 环境文件模板 | `.env.mainnet.example` | `.env.testnet.example` |
| `FLON_NETWORK` | `mainnet` | `testnet` |
| Chain ID | `d4019d7d…d8d12` | `18b4d583…6043f` |
| genesis | `networks/mainnet/genesis.json` | `networks/testnet/genesis.json` |
| 默认宿主机 RPC | 8888 | 18888 |
| 默认宿主机 P2P | 9876 | 19876 |
| 数据目录 | `data/mainnet/<role>` | `data/testnet/<role>` |
| snapshot 目录 | `snapshots/mainnet` | `snapshots/testnet` |
| BP 私钥配置 | `config/bp/mainnet/config.ini` | `config/bp/testnet/config.ini` |
| CLI 钱包目录 | `wallet/mainnet` | `wallet/testnet` |
| 容器名前缀 | `funod-mainnet-` | `funod-testnet-` |

启动脚本只接受 `mainnet` 或 `testnet`，并在启动前校验对应 genesis 的 SHA-256；网络名、genesis 或校验值不匹配时直接退出。现有 data 目录非空时不会再次应用 genesis，但仍会执行网络 genesis 校验。Docker healthcheck 还会把节点返回的 Chain ID 与环境模板中的 `EXPECTED_CHAIN_ID` 比较，因此错误网络的 snapshot 或现有数据会显示为 `unhealthy`。

```text
Mainnet Chain ID: d4019d7d8633a337973408c6c00e5c4888933ad1b6ce10edddea8145317d8d12
Testnet Chain ID: 18b4d5837d83a8f7203ea57cb7ab37b9cef59547ea307e70b1bf1103cb06043f
```

主网 genesis SHA-256：

```text
d4aae059868a50401a6169c2a8261f0b9d1d12ab0638eaaf96f22d467b84bddb
```

测试网 genesis SHA-256：

```text
4df875d57f88fe244c21a5d9906a171af95a5bc208e5ea817be8e8089cc42311
```

## 准备

```bash
cd deploy
# 二选一；不要让两个网络共用同一个 .env
cp .env.testnet.example .env
# cp .env.mainnet.example .env

# 让后续 curl/fucli 示例也读取当前网络变量
set -a; source .env; set +a

mkdir -p \
  data/mainnet/{common,bp,history} data/testnet/{common,bp,history} \
  snapshots/{mainnet,testnet} wallet/{mainnet,testnet} workspace
```

编辑 `.env`，确认 `FLON_NETWORK`、`EXPECTED_CHAIN_ID`、端口、`P2P_PEER` 和目标网络一致。仓库已经固化两套 genesis，不要手工复制或互换。从 snapshot 启动时，把文件放入 `snapshots/$FLON_NETWORK/` 并设置 `SNAPSHOT_FILE`。不要提交 `.env`、BP 私钥、钱包、snapshot 或节点数据。

测试网模板使用 `hk-it.vm.nestar.vip:19606`，主网模板使用 `hk-m1.vm.nestar.vip:9806`。这些入口可能随部署调整；上线前应确认 peer 当前可达，但不要把另一网络的 peer 填入。

## 普通节点

```bash
docker compose --env-file .env -f compose.common.yaml pull
docker compose --env-file .env -f compose.common.yaml up -d
docker compose --env-file .env -f compose.common.yaml ps
```

普通节点提供 chain/net API，不启用 producer 或 state-history 插件。

## BP 节点

```bash
cp "config/bp/${FLON_NETWORK}/config.ini.example" \
  "config/bp/${FLON_NETWORK}/config.ini"
chmod 600 "config/bp/${FLON_NETWORK}/config.ini"
```

在当前网络的 BP `config.ini` 中填写一个 BP 的 `producer-name` 和对应 `signature-provider`。主网和测试网的私钥文件分开保存，且均被 `.gitignore` 排除。BP RPC 默认只绑定宿主机 `127.0.0.1`。

```bash
docker compose --env-file .env -f compose.bp.yaml pull
docker compose --env-file .env -f compose.bp.yaml up -d
docker compose --env-file .env -f compose.bp.yaml ps
```

## History 节点

```bash
docker compose --env-file .env -f compose.history.yaml pull
docker compose --env-file .env -f compose.history.yaml up -d
docker compose --env-file .env -f compose.history.yaml ps
```

History 节点启用 `state_history_plugin`，开放 WebSocket 端口 9555，不包含 BP 私钥，也不生产区块。

## 健康检查和日志

三个节点均通过 `/v1/chain/get_info` 做 Docker healthcheck：

```bash
docker inspect --format '{{.State.Health.Status}}' "funod-${FLON_NETWORK}-common"
curl -s -X POST -H 'Content-Type: application/json' -d '{}' \
  http://127.0.0.1:${RPC_PORT}/v1/chain/get_info
docker logs --tail 200 "funod-${FLON_NETWORK}-common"
```

Docker `json-file` 日志限制为单文件 30 MB。`funod` 以前台进程运行，退出状态会传给 Docker；`restart: unless-stopped` 负责异常重启。

## 升级和回滚

升级前备份配置并创建 snapshot，然后修改 `.env` 中的固定版本：

```bash
docker compose --env-file .env -f compose.common.yaml pull
docker compose --env-file .env -f compose.common.yaml up -d --force-recreate
```

按实际角色替换 Compose 文件。验证镜像版本、chain ID 和 head/LIB 后再清理旧镜像。回滚时恢复旧版本号和对应数据备份，不要让不同二进制或不同网络写同一个 data 目录。

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
set -a; source ../.env; set +a
docker compose --env-file ../.env build wallet
docker compose --env-file ../.env up -d wallet cli
docker compose exec cli fucli --wallet-url unix:///wallet/fuwal.sock version client
docker compose exec cli fucli --wallet-url unix:///wallet/fuwal.sock \
  --url "$RPC_URL" get info
```

创建或导入钱包时执行 `docker compose exec cli fucli ...`。钱包分别保存在 `deploy/wallet/mainnet/` 和 `deploy/wallet/testnet/`，不会进入 Git，但仍应加密备份。分别在主网、测试网环境文件中设置各自的 `RPC_URL`；提交交易前执行 `get info`，核对返回的 `chain_id` 和当前 `FLON_NETWORK`，不得只根据域名判断网络。
