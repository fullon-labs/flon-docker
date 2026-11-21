# FullOn v0.9.2 Docker Compose 部署

以下示例分别用于普通节点、BP 节点和 History 节点。普通节点和 BP 使用 `flon-node`，History 使用 `flon-node-history`。

## 主网与测试网隔离

网络必须显式选择，不能共用 `.env`、genesis、节点数据或 snapshot：

| 项目 | 主网 | 测试网 |
| --- | --- | --- |
| 普通节点环境模板 | `.env.mainnet.example` | `.env.testnet.example` |
| BP 环境模板 | `.env.bp.mainnet.example` | `.env.bp.testnet.example` |
| `FLON_NETWORK` | `mainnet` | `testnet` |
| Chain ID | `d4019d7d…d8d12` | `18b4d583…6043f` |
| genesis | `networks/mainnet/genesis.json` | `networks/testnet/genesis.json` |
| Interop 路由 | `networks/mainnet/interop-routes.json` | `networks/testnet/interop-routes.json` |
| 默认宿主机 RPC | 8888 | 18888 |
| 默认宿主机 P2P | 19876 | 29876 |
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
# 普通节点：二选一；不要让两个网络共用同一个 .env
cp .env.testnet.example .env
# cp .env.mainnet.example .env

# 让后续 curl/fucli 示例也读取当前网络变量
set -a; source .env; set +a

mkdir -p \
  data/mainnet/{common,bp,history} data/testnet/{common,bp,history} \
  snapshots/{mainnet,testnet} wallet/{mainnet,testnet} workspace
```

编辑 `.env`，确认 `FLON_NETWORK`、`EXPECTED_CHAIN_ID`、端口、`P2P_PEER` 和目标网络一致。仓库已经固化两套 genesis，不要手工复制或互换。从 snapshot 启动时，把文件放入 `snapshots/$FLON_NETWORK/` 并设置 `SNAPSHOT_FILE`。不要提交 `.env`、BP 私钥、钱包、snapshot 或节点数据。

测试网模板使用 `hk-it.vm.nestar.vip:29876`，主网模板使用 `hk-m1.vm.nestar.vip:19876`。这些入口可能随部署调整；上线前应确认 peer 当前可达，但不要把另一网络的 peer 填入。

## 普通节点

```bash
docker compose --env-file .env -f compose.common.yaml pull
docker compose --env-file .env -f compose.common.yaml up -d
docker compose --env-file .env -f compose.common.yaml ps
```

普通节点仅将只读 chain API 暴露在 `${RPC_PORT}`；net API 只绑定容器 loopback，不启用 producer 或 state-history 插件。P2P 端口由 `.env` 的 `P2P_PORT` 同时决定节点监听和宿主机映射。

## BP 节点

```bash
# BP 必须使用专用环境模板；不要使用普通节点的 .env。
cp .env.bp.testnet.example .env
# cp .env.bp.mainnet.example .env

cp "config/bp/${FLON_NETWORK}/config.ini.example" \
  "config/bp/${FLON_NETWORK}/config.ini"
chmod 600 "config/bp/${FLON_NETWORK}/config.ini"
```

在当前网络的 BP `config.ini` 中填写一个 BP 的 `producer-name` 和对应 `signature-provider`。主网和测试网的私钥文件分开保存，且均被 `.gitignore` 排除。

BP 使用分类 HTTP API：只有 `chain_ro` 监听容器 `0.0.0.0:8888`，且 Compose 仅将它映射到宿主机 `127.0.0.1:${RPC_PORT}`；`chain_rw`、`net_rw`、`producer_rw` 均只监听容器 loopback。不要把这些重复的 `http-category-address` 写入 `.env`，它们必须保留为 `config.ini` 中的多行参数。

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

## 启用 Interop

以下以 `v0.9.4` history 节点为例。在 `deploy/` 中叠加
`compose.interop.yaml`，它会启用 `eosio::interop_relayer_api_plugin`，并按
`FLON_NETWORK` 只读挂载对应的 `interop-routes.json`。

| 网络 | 环境示例 | 公网入口 | 独立配置目录 |
| --- | --- | --- | --- |
| 主网 | `.env.mainnet.example` | `https://m.flonscan.io` | `./interop/mainnet` |
| 测试网 | `.env.testnet.example` | `https://t.flonscan.io` | `./interop/testnet` |

### 节点配置与 Compose

使用 Docker Compose 2.24.4 或更新版本。在 `deploy/` 中，为要部署的网络
复制环境和节点配置。下面的命令以主网为例，测试网将变量改为 `testnet`。

```sh
network=mainnet
example="./interop/$network"
cp -n "$example/.env.example" "$example/.env"
if [ ! -e "$example/config.ini" ]; then
  install -m 0600 "$example/config.ini.example" "$example/config.ini"
fi
sudo install -d -m 0700 -o root -g root "./data/$network/history/interop-run"
```

在 `.env` 中核对 P2P peer，在 `config.ini` 中用对应网络的签名提供方替换
`REPLACE_WITH_NETWORK_RELAY_PROVIDER`。实际配置文件已加入 Git 排除规则。
两条链分别使用各自的 `interopminer@relay` 密钥。保留默认
`interop-signing-protocol = v1`，并核对链上 `interopproxy::global.signing_protocol`。
v0.9.4 会忽略旧路由 JSON 的签名协议字段。

```sh
docker compose --env-file "$example/.env" -f compose.history.yaml \
  -f compose.interop.yaml -f "$example/compose.yaml" config -q
docker compose --env-file "$example/.env" -f compose.history.yaml \
  -f compose.interop.yaml -f "$example/compose.yaml" up -d
```

主网和测试网示例均使用 history 镜像 v0.9.4。RPC 和 history WebSocket 默认
仅发布到回环地址，P2P 使用网络模板中的端口。两套示例的端口互不冲突。

### Nginx 公网入口

`interop-submit-tcp = false` 时，节点 TCP 上的 `submit` 返回 `404`。
`get_routes` 和 `prepare` 仍可经普通 HTTP RPC 转发。公网 HTTPS 的
`submit` 需要由 Nginx 单独转发到 Unix socket。

当前公网部署的 `POST /v1/interop/submit` 转发路径如下。两边均启用了
`fullon-interop-gateway.socket`，其对应的 `systemd-socket-proxyd` 服务负责连接
同机的 `funod` socket。

| 公网域名 | Nginx 所在位置 | Nginx 使用的网关 socket | `funod` 监听的宿主机 socket |
| --- | --- | --- | --- |
| `m.flonscan.io` | a4 的 Nginx 容器 | 容器内 `/etc/nginx/conf.d/interop-gateway/submit.sock`，对应 a4 上的 `/home/richardchen/nginx/conf.d/interop-gateway/submit.sock` | `/data/funod_stats_mainnet/interop-run/interop.sock` |
| `t.flonscan.io` | hk-it 的宿主机 Nginx | `/run/fullon-interop-gateway/submit.sock` | `/mnt/data1/funod_testnet/interop-run/interop.sock` |

两个站点均使用精确匹配的 `location = /v1/interop/submit`。a4 的
`proxy_pass` 为 `http://unix:/etc/nginx/conf.d/interop-gateway/submit.sock:;`，
hk-it 为 `http://unix:/run/fullon-interop-gateway/submit.sock:;`。两条规则都保留请求 URI。

新部署使用各网络目录里的 `nginx-unix.conf` 和同名 systemd socket/service
示例。将 systemd 文件安装到 `/etc/systemd/system/`，按宿主机实际情况调整
`SocketGroup`、`systemd-socket-proxyd` 二进制路径，以及 `ExecStart` 最后一项
指向的绝对数据路径。只启用已部署网络的 socket。

```sh
sudo install -m 0644 "$example/flon-interop-$network.socket" \
  "$example/flon-interop-$network.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now "flon-interop-$network.socket"
```

将 `nginx-unix.conf` 放到 Nginx 可读的目录，然后在对应域名现有的 HTTPS
`server` 块中用 `include` 加载。主网使用 `127.0.0.1:8888` 和
`/run/flon-interop/mainnet.sock`，测试网使用 `127.0.0.1:18888` 和
`/run/flon-interop/testnet.sock`。若 Nginx 在容器中，挂载网关 socket 的父目录，
给 worker 匹配的组 ID，并将 TCP upstream 改成容器可达的节点地址。
已有相同路径的 `location` 时，用示例规则替换这些条目。

用 `nginx -t` 检查后重载。公网 `get_routes` 应报告正确的 `chain_id`、
`fullon-interop-v1`、`submission_enabled: true` 和 8 条路由。公网网关收到空请求
应由节点返回 `400`，直连节点 TCP 同一路径则应为 `404`。

```sh
for host in m.flonscan.io t.flonscan.io; do
  curl -fsS "https://$host/v1/interop/get_routes" |
    jq -e 'select(.submission_enabled and .signing_protocol == "fullon-interop-v1"
                  and (.routes | length) == 8)
           | {chain_id, signing_protocol, submission_enabled, routes: (.routes | keys)}'
  curl -sS -o /dev/null -w '%{http_code}\n' -H 'Content-Type: application/json' \
    -d '{}' "https://$host/v1/interop/submit"
done
```

### 跨主机转发

公网 Nginx 与节点分属不同主机时，可以通过私网 HTTP 将 `submit` 转发给节点
同机的 Nginx，再由节点侧 Nginx 通过上面的 Unix socket 规则交给 `funod`。
此方式保持 `interop-submit-tcp = false`。将节点侧 Nginx 绑定到私网地址，
并限制入站来源为公网 Nginx。公网 Nginx 的 upstream 填写节点侧 Nginx 的私网地址
和监听端口，保留 `/v1/interop/submit` 请求路径。

公网 Nginx 通过私网 TCP 直连 `funod` 时，使用对应网络的
`nginx-private-tcp.conf`。在节点 `config.ini` 中改为
`interop-submit-tcp = true`，在 `.env` 中将 `INTEROP_RPC_BIND`
设为节点宿主机的私网 IPv4 地址，再用上述 Compose 启动命令加上
`--force-recreate` 重新创建容器。
将 Nginx 示例的 upstream 地址和端口改为该节点发布的私网地址和 `RPC_PORT`。
对私网监听配置防火墙，只允许网关的来源地址访问，访问控制和限流由网关执行。

同一 HTTPS `server` 块应只加载一种 Interop 转发示例。启用私网 TCP 后，
从网关主机向节点 TCP 或公网 HTTPS 发送空 `submit`，两处都应返回 `400`。

### Solana 绑定端到端验证

以下示例使用 Node.js 18+ 生成一个独立的临时 Ed25519 钱包。每次运行都会提交
一笔真实绑定，成功后在所选链上创建账户。临时私钥只存在于进程内存中，
因此该测试账户不适合存入资产。

保存为 `solana-interop-bind.cjs`，选择要测试的网络。

```sh
# 测试网
node solana-interop-bind.cjs https://t.flonscan.io \
  18b4d5837d83a8f7203ea57cb7ab37b9cef59547ea307e70b1bf1103cb06043f
# 主网
node solana-interop-bind.cjs https://m.flonscan.io \
  d4019d7d8633a337973408c6c00e5c4888933ad1b6ce10edddea8145317d8d12
```

```js
const { generateKeyPairSync, sign } = require('node:crypto');
const [rpc, chainId] = process.argv.slice(2);
async function post(path, body, status = 200) {
  const res = await fetch(rpc + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
  const text = await res.text();
  if (res.status !== status) throw new Error(path + ' HTTP ' + res.status + ' ' + text);
  return JSON.parse(text);
}
function base58(bytes) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
  let n = BigInt('0x' + bytes.toString('hex'));
  let result = '';
  while (n > 0n) {
    result = alphabet[Number(n % 58n)] + result;
    n /= 58n;
  }
  for (const byte of bytes) {
    if (byte !== 0) break;
    result = '1' + result;
  }
  return result;
}

(async () => {
  const info = await post('/v1/chain/get_info', {});
  if (info.chain_id !== chainId) throw new Error('Unexpected chain ID');

  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const address = base58(publicKey.export({ type: 'spki', format: 'der' }).subarray(-32));
  const prepared = await post('/v1/interop/prepare', {
    operation: 'bind', source: 'solana', address,
  });
  if (prepared.chain_id !== chainId || prepared.wallet_signing !== 'solana_sign_message'
      || prepared.submit_args?.address !== address) {
    throw new Error('Unexpected prepare response');
  }

  const signature = sign(null, Buffer.from(prepared.signing_message, 'utf8'), privateKey);
  const { account } = prepared.submit_args;
  console.log({ address, account, start_block: info.head_block_num });
  const { transaction_id } = await post('/v1/interop/submit', {
    ...prepared.submit_args, signature: signature.toString('hex'),
  }, 202);
  console.log({ transaction_id });
})().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
```

收到 HTTP `202` 后，按以下步骤验收。

1. 从脚本输出的 `start_block` 开始，通过 `POST /v1/chain/get_block` 查找该
   `transaction_id`。确认回执为 `executed`，动作为 `interopproxy::bindsol`，
   授权为 `interopminer@relay`，且动作中的账户和 Solana 地址与脚本输出一致。
2. 通过 `POST /v1/chain/get_account` 查询输出的账户名，确认账户已创建。
3. 调用 `GET /v1/chain/get_info`，确认 `last_irreversible_block_num` 大于或等于
   交易所在块高。若提交请求超时，先核对交易或账户状态，再决定是否重试。

## floncdt 编译环境

```bash
cd deploy/cdt
CONTRACTS_DIR=/absolute/path/to/contracts docker compose run --rm cdt cdt-cpp --version
CONTRACTS_DIR=/absolute/path/to/contracts docker compose run --rm cdt \
  cdt-cpp -abigen -I include -o build/contract.wasm src/contract.cpp
```

## 命令行运行环境

`flon-node`/`flon-node-history` 只包含 `funod`。CLI 镜像以官方 `floncdt:v0.9.2` 为基础，并从 flon-core v0.9.2 Release 安装经过 SHA-256 校验的 `flon-core-tools`，提供 `fucli` 和 `fuwal`。

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
