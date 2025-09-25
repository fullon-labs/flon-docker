#!/usr/bin/env bash
set -euo pipefail

source ~/flon.env 2>/dev/null || true
source ./conf.env 2>/dev/null || true
# 必填参数
OSS_ENDPOINT="${ALI_OSS_ENDPOINT:-oss-cn-hongkong-internal.aliyuncs.com}"
OSS_REGION="${ALI_OSS_REGION:-cn-hongkong}"   # 或 oss-cn-hongkong
OSS_BUCKET="${ALI_OSS_BUCKET:-flon-test}"
OSS_PREFIX="${ALI_OSS_PREFIX:-snapshots}"
OSS_ACCESS_KEY_ID="${ALI_OSS_ACCESS_KEY:-}"
OSS_ACCESS_KEY_SECRET="${ALI_OSS_ACCESS_SECRET:-}"

FILE="${1:-}"
if [[ -z "$FILE" ]]; then
  echo "用法: $0 <snapshot_file_or_dir>"
  exit 1
fi
[[ -f "$FILE" ]] || { echo "文件不存在: $FILE" >&2; exit 1; }

BASENAME="$(basename "$FILE")"
OSS_KEY="${OSS_PREFIX%/}/${BASENAME}"

echo "[INFO] 上传到 oss://${OSS_BUCKET}/${OSS_KEY}"

ossutil cp -f -u \
  -e "$OSS_ENDPOINT" \
  --region "$OSS_REGION" \
  -i "$OSS_ACCESS_KEY_ID" \
  -k "$OSS_ACCESS_KEY_SECRET" \
  "$FILE" \
  "oss://$OSS_BUCKET/$OSS_KEY"

echo "[DONE] URL: https://${OSS_BUCKET}.${OSS_ENDPOINT}/${OSS_KEY}"
~