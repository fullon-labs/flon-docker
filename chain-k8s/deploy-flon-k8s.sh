#!/usr/bin/env bash
# deploy-flon-k8s.sh
# 一键在 K8s 部署 flon（nodflon）全节点/生产者节点
set -euo pipefail

### ========= 可调参数（也可用命令行覆盖） =========
NS="${NS:-flon}"
IMAGE="${IMAGE:-ghcr.io/greymass/flon:v2.1.0}"
STORAGE_CLASS="${STORAGE_CLASS:-fast-ssd}"
PVC_SIZE="${PVC_SIZE:-1Ti}"
HTTP_PORT="${HTTP_PORT:-8888}"
P2P_PORT="${P2P_PORT:-9876}"
CHAIN_STATE_MB="${CHAIN_STATE_MB:-65536}"      # chain-state-db-size-mb
REVERSIBLE_DB_MB="${REVERSIBLE_DB_MB:-4096}"
SNAPSHOT_URL="${SNAPSHOT_URL:-}"               # 可留空，或用 --snapshot-url 覆盖
INGRESS_HOST="${INGRESS_HOST:-}"               # 设为域名以启用 Ingress

# 生产者配置（默认关闭）
PRODUCER_ENABLED="${PRODUCER_ENABLED:-false}"
PRODUCER_NAME="${PRODUCER_NAME:-}"
SIGNATURE_PROVIDER="${SIGNATURE_PROVIDER:-}"   # 例：flonxxxx=KflonD:PW5Kxxxxx

# peers（逗号分隔，例：peer1:9876,peer2:9876）
PEERS="${PEERS:-}"

### ========= 工具检查 =========
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ 需要命令：$1"; exit 1; }; }
need kubectl
need sed

### ========= 参数解析 =========
usage() {
  cat <<EOF
用法: $0 [命令] [选项]

命令:
  install        部署/更新（幂等）
  uninstall      卸载（会删除数据PVC请谨慎）
  status         查看部署状态
  restart        滚动重启
  logs           查看 Pod 日志

常用选项（也可用环境变量）:
  --namespace NS                 命名空间（默认: $NS）
  --image IMAGE                  镜像（默认: $IMAGE）
  --storage-class CLASS          存储类（默认: $STORAGE_CLASS）
  --pvc-size SIZE                数据盘大小（默认: $PVC_SIZE）
  --snapshot-url URL             快照URL（zst或bin，留空表示不用）
  --ingress-host HOST            启用 Ingress 的域名（留空不创建）
  --peers "host1:9876,host2:9876"  P2P对等点
  --producer                     启用生产者节点
  --producer-name NAME           生产者名
  --signature-provider STR       签名提供者字符串
EOF
}

CMD="${1:-install}"
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NS="$2"; shift 2;;
    --image) IMAGE="$2"; shift 2;;
    --storage-class) STORAGE_CLASS="$2"; shift 2;;
    --pvc-size) PVC_SIZE="$2"; shift 2;;
    --snapshot-url) SNAPSHOT_URL="$2"; shift 2;;
    --ingress-host) INGRESS_HOST="$2"; shift 2;;
    --peers) PEERS="$2"; shift 2;;
    --producer) PRODUCER_ENABLED=true; shift;;
    --producer-name) PRODUCER_NAME="$2"; shift 2;;
    --signature-provider) SIGNATURE_PROVIDER="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "未知参数: $1"; usage; exit 1;;
  esac
done

### ========= 辅助 =========
info()  { echo "👉 $*"; }
ok()    { echo "✅ $*"; }
warn()  { echo "⚠️  $*"; }
err()   { echo "❌ $*"; }

kapply() { kubectl apply -f -; }
kdel()   { kubectl delete -f - --ignore-not-found; }

ensure_ns() {
  if ! kubectl get ns "$NS" >/dev/null 2>&1; then
    info "创建命名空间 $NS"
    kubectl create ns "$NS"
  fi
}

make_peers_ini() {
  local peers_ini=""
  if [[ -n "$PEERS" ]]; then
    IFS=',' read -ra arr <<< "$PEERS"
    for p in "${arr[@]}"; do
      peers_ini+="p2p-peer-address = ${p}\n"
    done
  fi
  printf "%b" "$peers_ini"
}

create_configmap() {
  info "应用 ConfigMap flon-config"
  local peers_ini; peers_ini="$(make_peers_ini)"
  kapply <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: flon-config
  namespace: ${NS}
data:
  config.ini: |
    blocks-dir = /data/blocks
    chain-state-db-size-mb = ${CHAIN_STATE_MB}
    reversible-blocks-db-size-mb = ${REVERSIBLE_DB_MB}
    http-server-address = 0.0.0.0:${HTTP_PORT}
    p2p-listen-endpoint = 0.0.0.0:${P2P_PORT}
    p2p-max-nodes-per-host = 100
    access-control-allow-origin = *
    http-validate-host = false
    abi-serializer-max-time-ms = 2000
    net-threads = 4
    sync-fetch-span = 200
    read-mode = speculative
    max-transaction-time = 1000
    reversible-blocks-db-guard-size-mb = 128
    chain-threads = 4
    http-threads = 6
    plugin = flonio::chain_plugin
    plugin = flonio::chain_api_plugin
    plugin = flonio::net_plugin
    plugin = flonio::net_api_plugin
    plugin = flonio::producer_api_plugin
${PRODUCER_ENABLED:+    plugin = flonio::producer_plugin}
${PRODUCER_ENABLED:+    producer-name = ${PRODUCER_NAME:-yourbpname}}
${PRODUCER_ENABLED:+    signature-provider = ${SIGNATURE_PROVIDER:-flonxxxx=KflonD:PW5Kxxxxx}}
  peers.txt: |
${peers_ini:+$(printf "%b" "$peers_ini" | sed 's/^/    /')}
  genesis.json: |
    {
      "initial_timestamp": "2018-06-08T08:08:08.888",
      "initial_key": "flon6MRy..ReplaceThis..",
      "initial_configuration": {
        "max_block_net_usage": 1048576,
        "target_block_net_usage_pct": 1000,
        "max_transaction_net_usage": 524288,
        "base_per_transaction_net_usage": 12,
        "net_usage_leeway": 500,
        "context_free_discount_net_usage_num": 20,
        "context_free_discount_net_usage_den": 100,
        "max_block_cpu_usage": 200000,
        "target_block_cpu_usage_pct": 1000,
        "max_transaction_cpu_usage": 150000,
        "min_transaction_cpu_usage": 100,
        "max_transaction_lifetime": 3600,
        "deferred_trx_expiration_window": 600,
        "max_transaction_delay": 3888000,
        "max_inline_action_size": 4096,
        "max_inline_action_depth": 4,
        "max_authority_depth": 6
      }
    }
EOF
  ok "ConfigMap 就绪"
}

create_snapshot_secret_if_needed() {
  if [[ -n "$SNAPSHOT_URL" ]]; then
    info "创建/更新快照 Secret flon-bootstrap"
    kubectl -n "$NS" delete secret flon-bootstrap --ignore-not-found >/dev/null 2>&1 || true
    kubectl -n "$NS" create secret generic flon-bootstrap \
      --from-literal=snapshot_url="$SNAPSHOT_URL" >/dev/null
    ok "快照 Secret 已配置"
  else
    warn "未提供 SNAPSHOT_URL，跳过快照 Secret"
  fi
}

create_statefulset() {
  info "应用 StatefulSet flon-node"
  kapply <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: flon-node
  namespace: ${NS}
spec:
  serviceName: flon-headless
  replicas: 1
  selector:
    matchLabels: { app: flon-node }
  template:
    metadata:
      labels: { app: flon-node }
    spec:
      terminationGracePeriodSeconds: 60
      securityContext:
        fsGroup: 1000
        runAsUser: 1000
        runAsNonRoot: true
      containers:
      - name: nodflon
        image: ${IMAGE}
        args:
          - nodflon
          - --data-dir=/data
          - --config-dir=/config
          - --genesis-json=/config/genesis.json
        ports:
          - name: http
            containerPort: ${HTTP_PORT}
          - name: p2p
            containerPort: ${P2P_PORT}
        volumeMounts:
          - name: data
            mountPath: /data
          - name: config
            mountPath: /config
        env:
        - name: SNAPSHOT_URL
          valueFrom:
            secretKeyRef:
              name: flon-bootstrap
              key: snapshot_url
              optional: true
        readinessProbe:
          httpGet:
            path: /v1/chain/get_info
            port: ${HTTP_PORT}
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
        livenessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - |
                last=\$(curl -s http://127.0.0.1:${HTTP_PORT}/v1/chain/get_info | grep head_block_time | sed 's/.*"head_block_time":"\\([^"]*\\)".*/\\1/')
                [ -z "\$last" ] && exit 1
                now=\$(date -u +%s)
                ts=\$(date -u -d "\$last" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%S.%NZ" "\$last" +%s)
                [ \$((now - ts)) -lt 180 ]
          initialDelaySeconds: 90
          periodSeconds: 20
          timeoutSeconds: 5
        resources:
          requests:
            cpu: "4"
            memory: "8Gi"
          limits:
            cpu: "8"
            memory: "16Gi"

      initContainers:
      - name: prepare-config
        image: alpine:3.20
        command: ["/bin/sh","-c"]
        args:
          - |
            set -e
            mkdir -p /config
            cp /cm/config.ini /config/config.ini
            cp /cm/genesis.json /config/genesis.json
            # 附加 peers 到 config.ini
            if [ -s /cm/peers.txt ]; then
              echo "" >> /config/config.ini
              cat /cm/peers.txt >> /config/config.ini
            fi
        volumeMounts:
          - name: config
            mountPath: /config
          - name: cm
            mountPath: /cm

      - name: fetch-snapshot
        image: ghcr.io/stonedreams/zstd:latest
        command: ["/bin/sh","-c"]
        args:
          - |
            set -e
            if [ -n "\$SNAPSHOT_URL" ] && [ ! -f /data/snapshot.bin ]; then
              echo "Downloading snapshot..."
              case "\$SNAPSHOT_URL" in
                *.zst) curl -L "\$SNAPSHOT_URL" -o /data/snapshot.bin.zst && zstd -d /data/snapshot.bin.zst -o /data/snapshot.bin ;;
                *)     curl -L "\$SNAPSHOT_URL" -o /data/snapshot.bin ;;
              esac
            fi
        env:
          - name: SNAPSHOT_URL
            valueFrom:
              secretKeyRef:
                name: flon-bootstrap
                key: snapshot_url
                optional: true
        volumeMounts:
          - name: data
            mountPath: /data

      volumes:
        - name: cm
          configMap: { name: flon-config }
        - name: config
          emptyDir: {}

  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: ${STORAGE_CLASS}
      resources:
        requests:
          storage: ${PVC_SIZE}
EOF
  ok "StatefulSet 已提交"
}

create_services() {
  info "应用 Services"
  kapply <<EOF
apiVersion: v1
kind: Service
metadata:
  name: flon-headless
  namespace: ${NS}
spec:
  clusterIP: None
  selector: { app: flon-node }
  ports:
    - { name: http, port: ${HTTP_PORT}, targetPort: ${HTTP_PORT} }
    - { name: p2p,  port: ${P2P_PORT},  targetPort: ${P2P_PORT} }
---
apiVersion: v1
kind: Service
metadata:
  name: flon-rpc
  namespace: ${NS}
spec:
  type: ClusterIP
  selector: { app: flon-node }
  ports:
    - { name: http, port: ${HTTP_PORT}, targetPort: ${HTTP_PORT} }
EOF
  ok "Services 已创建/更新"
}

create_ingress_if_needed() {
  if [[ -z "$INGRESS_HOST" ]]; then
    warn "未设置 INGRESS_HOST，跳过 Ingress"
    return
  fi
  info "应用 Ingress: ${INGRESS_HOST}"
  kapply <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flon-rpc
  namespace: ${NS}
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  ingressClassName: nginx
  rules:
  - host: ${INGRESS_HOST}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: flon-rpc
            port:
              number: ${HTTP_PORT}
EOF
  ok "Ingress 已创建/更新"
}

install() {
  ensure_ns
  create_configmap
  create_snapshot_secret_if_needed
  create_statefulset
  create_services
  create_ingress_if_needed
  ok "部署完成。检查状态：kubectl -n ${NS} get pods,sts,svc"
}

uninstall() {
  warn "将删除所有资源及 PVC（数据会丢失）"
  read -r -p "确定删除? 输入 YES 确认: " x
  [[ "$x" == "YES" ]] || { echo "已取消"; exit 0; }

  info "删除 Ingress/Service/StatefulSet/ConfigMap/Secret"
  kdel <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: { name: flon-rpc, namespace: ${NS} }
---
apiVersion: v1
kind: Service
metadata: { name: flon-rpc, namespace: ${NS} }
---
apiVersion: v1
kind: Service
metadata: { name: flon-headless, namespace: ${NS} }
---
apiVersion: apps/v1
kind: StatefulSet
metadata: { name: flon-node, namespace: ${NS} }
---
apiVersion: v1
kind: ConfigMap
metadata: { name: flon-config, namespace: ${NS} }
---
apiVersion: v1
kind: Secret
metadata: { name: flon-bootstrap, namespace: ${NS} }
EOF

  info "删除 PVC"
  kubectl -n "$NS" delete pvc -l app=flon-node --ignore-not-found || true
  ok "卸载完成"
}

status() {
  kubectl -n "$NS" get pods,svc,ingress,cm,secret,sts -o wide
}

restart() {
  kubectl -n "$NS" rollout restart statefulset/flon-node
  ok "已触发滚动重启"
}

logs() {
  local pod
  pod="$(kubectl -n "$NS" get pods -l app=flon-node -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [[ -n "$pod" ]] || { err "找不到 Pod"; exit 1; }
  kubectl -n "$NS" logs -f "$pod" -c nodflon
}

### ========= 主流程 =========
case "$CMD" in
  install)   install ;;
  uninstall) uninstall ;;
  status)    status ;;
  restart)   restart ;;
  logs)      logs ;;
  *) usage; exit 1;;
esac