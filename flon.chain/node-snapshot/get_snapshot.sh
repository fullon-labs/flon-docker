#!/usr/bin/env bash
# get_snapshot.sh
# 触发快照 -> 拉容器快照 -> (可选)压缩 -> 输出本地路径

set -euo pipefail
source ~/flon.env 2>/dev/null || true
source ./conf.env 2>/dev/null || true

### ===== 基本配置（可用环境变量覆盖） =====
NODE_HTTP="${NODE_HTTP:-http://127.0.0.1:18889}"
SNAP_API_PATH="${SNAP_API_PATH:-/v1/producer/create_snapshot}"

DOCKER_INSTANCE="${DOCKER_INSTANCE:-funod_testnet2}"
# 修正默认容器内路径（去掉 blocks）
SNAP_SRC_IN_CONTAINER="${SNAP_SRC_IN_CONTAINER:-/opt/flon/data/snapshots}"

WORKDIR="${WORKDIR:-/tmp}"
TS="$(date -u +%Y%m%d_%H%M%S)"
LOCAL_DIR="${LOCAL_DIR:-${WORKDIR}/snapshot_${TS}}"

# 压缩：1=启用（若系统有 zstd），0=关闭
ENABLE_ZSTD="${ENABLE_ZSTD:-1}"

log(){ echo "[$(date +%H:%M:%S)] $*"; }
err(){ echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; }
need(){ command -v "$1" >/dev/null 2>&1 || { err "Need command: $1"; exit 1; }; }

need curl
need docker
HAS_ZSTD=0; command -v zstd >/dev/null 2>&1 && HAS_ZSTD=1

### 1) 触发快照
log "POST ${NODE_HTTP}${SNAP_API_PATH}"
HTTP_CODE=$(curl -sS -o "${WORKDIR}/create_snapshot_resp.json" -w "%{http_code}" -X POST "${NODE_HTTP}${SNAP_API_PATH}" || true)

if [[ "${HTTP_CODE}" != "200" && "${HTTP_CODE}" != "201" ]]; then
  err "create_snapshot 返回 ${HTTP_CODE}"
  cat "${WORKDIR}/create_snapshot_resp.json" || true
  echo "可能原因：端口错误 / 未加载 producer_api_plugin / 网关未转发 / 节点未就绪"
  exit 1
fi

SNAPSHOT_NAME=""
if command -v jq >/dev/null 2>&1; then
  SNAPSHOT_NAME=$(jq -r '.snapshot_name // empty' "${WORKDIR}/create_snapshot_resp.json")
else
  SNAPSHOT_NAME=$(grep -oE '"snapshot_name"\s*:\s*"[^"]+"' "${WORKDIR}/create_snapshot_resp.json" | sed 's/.*"snapshot_name"\s*:\s*"\([^"]*\)".*/\1/')
fi
log "create_snapshot 响应：$(cat "${WORKDIR}/create_snapshot_resp.json")"
[[ -n "$SNAPSHOT_NAME" ]] && log "快照文件（宿主机路径）: $SNAPSHOT_NAME"

# 给节点落盘时间（必要时调大）
sleep 5

### 2) 从容器或宿主机拷出快照
TMP_PULL_DIR="${WORKDIR}/snapshots_pull_${TS}"
mkdir -p "${TMP_PULL_DIR}"

# 先尝试从容器路径拷
log "尝试从容器拷贝: ${DOCKER_INSTANCE}:${SNAP_SRC_IN_CONTAINER} -> ${TMP_PULL_DIR}/"
if docker cp "${DOCKER_INSTANCE}:${SNAP_SRC_IN_CONTAINER}" "${TMP_PULL_DIR}/" >/dev/null 2>&1; then
  SRC_DIR="${TMP_PULL_DIR}/snapshots"
else
  # 回退：若拿到了宿主机路径，则从宿主机目录拷
  if [[ -n "${SNAPSHOT_NAME}" ]]; then
    HOST_DIR="$(dirname "${SNAPSHOT_NAME}")"
    log "容器路径不可用，尝试从宿主机目录拷贝: ${HOST_DIR}"
    mkdir -p "${TMP_PULL_DIR}/snapshots"
    # 复制所有 .bin（可能包含多个）
    cp -f "${HOST_DIR}/"*.bin "${TMP_PULL_DIR}/snapshots/" 2>/dev/null || true
  fi
  SRC_DIR="${TMP_PULL_DIR}/snapshots"
fi

[[ -d "${SRC_DIR}" ]] || { err "未找到快照目录（容器与宿主机路径都不可用）"; exit 1; }

# 找最新 .bin
shopt -s nullglob
mapfile -t BIN_FILES < <(ls -t "${SRC_DIR}"/*.bin 2>/dev/null || true)
shopt -u nullglob
[[ ${#BIN_FILES[@]} -gt 0 ]] || { err "未发现 .bin 快照文件"; exit 1; }
LATEST_BIN="${BIN_FILES[0]}"
log "最新快照文件：${LATEST_BIN}"

# 落到目标目录
mkdir -p "${LOCAL_DIR}"
cp -f "${SRC_DIR}/"*.bin "${LOCAL_DIR}/"
log "快照已保存到：${LOCAL_DIR}"

### 3) 可选压缩
FINAL_FILE="${LOCAL_DIR}/$(basename "${LATEST_BIN}")"
if [[ "$ENABLE_ZSTD" == "1" && "$HAS_ZSTD" -eq 1 ]]; then
  log "压缩为 .zst（zstd -19）"
  OUT="${FINAL_FILE}.zst"
  zstd -T0 -19 "${FINAL_FILE}" -o "${OUT}"
  FINAL_FILE="${OUT}"
else
  [[ "$ENABLE_ZSTD" == "1" ]] && log "未安装 zstd，跳过压缩（brew install zstd）"
fi

echo
echo "================= SNAPSHOT READY ================="
echo "LOCAL_DIR : ${LOCAL_DIR}"
echo "SNAPSHOT  : ${FINAL_FILE}"
echo "================================================="