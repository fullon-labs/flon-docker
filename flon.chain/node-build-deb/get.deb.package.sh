#!/bin/bash
# deb-repack-push.sh - 使用 Docker 打包 .deb 并上传 OSS，同时生成报告

set -euo pipefail

# 日志文件
LOG_FILE="$HOME/build_deploy_report.log"
REPORT_FILE="$HOME/build_report.txt"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 加载环境变量
if [ -f ~/flon.env ]; then
    source ~/flon.env
fi

# 参数
IMG=$1
package_name=$2
DEB_PATH=$(realpath ~/deb)

# 检查参数
if [ -z "$IMG" ] || [ -z "$package_name" ]; then
    echo "Usage: $0 <image-name> <package-name>"
    log "Error: Missing required parameters (image-name or package-name)"
    exit 1
fi

log "Starting process to repackage .deb and upload to OSS..."

# 清理旧 deb 目录
log "Cleaning up previous deb directory..."
rm -rf "$DEB_PATH"
mkdir -p "$DEB_PATH"

# Docker 中执行打包命令
cmds='
set -e
echo "deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse" > /etc/apt/sources.list && \
echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
echo "deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse" >> /etc/apt/sources.list && \
apt update && apt install -y dpkg-repack && \
mkdir -p /packages && cd /packages && \
dpkg-repack '${package_name}'
'

log "Running Docker container to repackage .deb package..."
docker run -it --rm -v "${DEB_PATH}:/packages" "$IMG" bash -c "$cmds" || {
    log "Error: Docker command failed during .deb packaging"
    echo "Error: Docker command failed"
    exit 1
}

log "Successfully repacked .deb package: $package_name"

# 上传到 OSS
log "Uploading .deb packages to OSS..."
ossutil cp -f "$DEB_PATH"/* oss://flon-test/deb/ || {
    log "Error: Failed to upload .deb packages to OSS"
    echo "Error: Upload failed"
    exit 1
}

log "Successfully uploaded .deb packages to OSS."

# 获取上传后的最新文件名
latest_file=$(ls -t "$DEB_PATH"/* | head -n 1)
if [ -n "$latest_file" ]; then
    deb_file_name=$(basename "$latest_file")
    http_url="https://flon-test.oss-cn-hongkong.aliyuncs.com/deb/$deb_file_name"
    echo "Download URL: $http_url"
    log "Latest .deb package download URL: $http_url"
else
    log "Error: No .deb package found"
    exit 1
fi

# === 写入 build_report.txt ===
IMAGE_TAG="$IMG"
PACKAGE="$package_name"

NEW_REPORT=$(
cat <<EOF
Image: $IMAGE_TAG (deb: $PACKAGE)
Target: $http_url
Time: $(date '+%Y-%m-%d %H:%M:%S')
EOF
)

# 去重追加
if ! grep -q "Image: $IMAGE_TAG (deb: $PACKAGE)" "$REPORT_FILE" 2>/dev/null; then
    echo -e "\n$NEW_REPORT" >> "$REPORT_FILE"
    log "Appended new report to build_report.txt"
else
    log "Skipped duplicate entry in build_report.txt"
fi

log "Process completed successfully. All tasks done!"
