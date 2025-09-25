#!/usr/bin/env bash
# make_and_upload_snapshot.sh
# 触发快照 -> 拉容器快照 -> (可选)压缩 -> 上传到阿里云 OSS


set -euo pipefail
source ~/flon.env || true
source ./conf.env


### ======= 基本配置（可用环境变量覆盖） =======
NODE_HTTP="${NODE_HTTP:-http://127.0.0.1:18889}"
SNAP_API_PATH="${SNAP_API_PATH:-/v1/producer/create_snapshot}"

DOCKER_INSTANCE="${DOCKER_INSTANCE:-funod_testnet2}"
SNAP_SRC_IN_CONTAINER="${SNAP_SRC_IN_CONTAINER:-/opt/flon/data/blocks/snapshots}"

WORKDIR="${WORKDIR:-/tmp}"
TS="$(date -u +%Y%m%d_%H%M%S)"
LOCAL_DIR="${LOCAL_DIR:-${WORKDIR}/snapshot_${TS}}"

# 压缩：1=启用（若系统有 zstd），0=关闭
ENABLE_ZSTD="${ENABLE_ZSTD:-1}"

# OSS 参数（使用 ossutil）
OSS_ENDPOINT="${OSS_ENDPOINT:-oss-cn-hongkong.aliyuncs.com}"   # 例：oss-cn-hongkong.aliyuncs.com
OSS_BUCKET="${OSS_BUCKET:-flon-test}"                          # 例：你的 bucket 名
OSS_PREFIX="${OSS_PREFIX:-snapshots}"                          # 例：上传到 bucket/snapshots/ 下

# 认证（任选其一）
# 方式A：使用环境变量传密钥
OSS_ACCESS_KEY_ID="${OSS_ACCESS_KEY_ID:-}"
OSS_ACCESS_KEY_SECRET="${OSS_ACCESS_KEY_SECRET:-}"
OSS_STS_TOKEN="${OSS_STS_TOKEN:-}"  # 可选
# 方式B：已通过 'ossutil config' 写到 ~/.ossutilconfig，则可不填上面三项

### ======= 工具探测 =======
need(){ command -v "$1" >/dev/null 2>&1 || { echo "Need command: $1" >&2; exit 1; }; }
need curl
need docker
OSSUTIL_BIN=""
if command -v ossutil >/dev/null 2>&1; then OSSUTIL_BIN="ossutil"; fi
if command -v ossutil64 >/dev/null 2>&1; then OSSUTIL_BIN="ossutil64"; fi
[[ -n "$OSSUTIL_BIN" ]] || { echo "Need ossutil/ossutil64 (https://help.aliyun.com/zh/oss/developer-reference/ossutil)" >&2; exit 1; }
HAS_ZSTD=0; command -v zstd >/dev/null 2>&1 && HAS_ZSTD=1

log(){ echo "[$(date +%H:%M:%S)] $*"; }
err(){ echo "[$(date +%H:%M:%S)] ERROR: $*" >&2; }

build_oss_args(){
  # 若提供了 AK/SK，则用命令行参数，不依赖本地配置文件
  if [[ -n "$OSS_ACCESS_KEY_ID" && -n "$OSS_ACCESS_KEY_SECRET" ]]; then
    if [[ -n "$OSS_STS_TOKEN" ]]; then
      echo "-e $OSS_ENDPOINT -i $OSS_ACCESS_KEY_ID -k $OSS_ACCESS_KEY_SECRET -t $OSS_STS_TOKEN"
    else
      echo "-e $OSS_ENDPOINT -i $OSS_ACCESS_KEY_ID -k $OSS_ACCESS_KEY_SECRET"
    fi
  else
    # 使用默认配置文件 (~/.ossutilconfig)
    echo "-e $OSS_ENDPOINT"
  fi
}

oss_url(){
  # 形成 https 直链： https://<bucket>.<endpoint>/<key>
  local key="$1"
  echo "https://${OSS_BUCKET}.${OSS_ENDPOINT}/${key}"
}

### ======= 1) 触发快照 =======
log "POST ${NODE_HTTP}${SNAP_API_PATH}"
HTTP_CODE=$(curl -sS -o "${WORKDIR}/create_snapshot_resp.json" -w "%{http_code}" -X POST "${NODE_HTTP}${SNAP_API_PATH}" || true)
if [[ "${HTTP_CODE}" != "200" ]]; then
  err "create_snapshot 返回 ${HTTP_CODE}"
  cat "${WORKDIR}/create_snapshot_resp.json" || true
  echo "可能原因：端口错误 / 未加载 producer_api_plugin / 网关未转发 / 节点未就绪"
  exit 1
fi
log "快照创建请求已发送"
sleep 5  # 给节点落盘时间，可按需调大

### ======= 2) 从容器拷出快照目录 =======
TMP_PULL_DIR="${WORKDIR}/snapshots_pull_${TS}"
mkdir -p "${TMP_PULL_DIR}"
log "docker cp ${DOCKER_INSTANCE}:${SNAP_SRC_IN_CONTAINER} -> ${TMP_PULL_DIR}/"
docker cp "${DOCKER_INSTANCE}:${SNAP_SRC_IN_CONTAINER}" "${TMP_PULL_DIR}/" >/dev/null

[[ -d "${TMP_PULL_DIR}/snapshots" ]] || { err "容器内未找到 snapshots 目录：${SNAP_SRC_IN_CONTAINER}"; exit 1; }

# 找最新的 .bin
shopt -s nullglob
mapfile -t BIN_FILES < <(ls -t "${TMP_PULL_DIR}/snapshots"/*.bin 2>/dev/null || true)
shopt -u nullglob
[[ ${#BIN_FILES[@]} -gt 0 ]] || { err "未发现 .bin 快照文件"; exit 1; }
LATEST_BIN="${BIN_FILES[0]}"
log "最新快照文件：${LATEST_BIN}"

# 移到目标目录
mkdir -p "${LOCAL_DIR}"
mv "${TMP_PULL_DIR}/snapshots"/* "${LOCAL_DIR}/"
rm -rf "${TMP_PULL_DIR}"
log "快照已保存到：${LOCAL_DIR}"

### ======= 3) 可选压缩 =======
UPLOAD_FILE="${LATEST_BIN}"
if [[ "$ENABLE_ZSTD" == "1" && "$HAS_ZSTD" -eq 1 ]]; then
  log "压缩为 .zst（使用 zstd -19）"
  OUT="${LATEST_BIN}.zst"
  zstd -T0 -19 "${LATEST_BIN}" -o "${OUT}"
  UPLOAD_FILE="${OUT}"
else
  [[ "$ENABLE_ZSTD" == "1" ]] && log "未安装 zstd，跳过压缩（brew install zstd）"
fi

### ======= 4) 上传到 OSS =======
BASENAME="$(basename "${UPLOAD_FILE}")"
OSS_KEY="${OSS_PREFIX%/}/${BASENAME}"
OSS_ARGS="$(build_oss_args)"

log "上传到 OSS：oss://${OSS_BUCKET}/${OSS_KEY}"
# -f 覆盖同名   -u 断点续传   --meta 可追加元数据
$OSSUTIL_BIN cp -f -u ${OSS_ARGS} "${UPLOAD_FILE}" "oss://${OSS_BUCKET}/${OSS_KEY}"

FINAL_URL="$(oss_url "${OSS_KEY}")"
log "上传成功：${FINAL_URL}"

echo
echo "================= RESULT ================="
echo "Local  : ${UPLOAD_FILE}"
echo "OSS URL: ${FINAL_URL}"
echo "=========================================="