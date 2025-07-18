#!/bin/bash
set -e

# === 加载环境变量 ===
if [ -f ~/flon.env ]; then
  source ~/flon.env
fi

# === 默认变量 ===
DOCKER_IMG=${DOCKER_IMG:-"floncore/funod"}
FULLON_VERSION=${FULLON_VERSION:-"0.5.0-alpha"}
BRANCH=${FULLON_BRANCH:-"main"}
REPO=${REPO:-"https://github.com/fullon-labs/flon-core.git"}
MODE=${MODE:-"git"}
LOCAL_PATH=${LOCAL_PATH:-"../../"}
NODE_IMG_HEADER=${NODE_IMG_HEADER:-""}
BUILDER_BASE_IMG="fullon/base:builder"
RUNTIME_BASE_IMG="fullon/runtime-base"

LOCAL_PATH=$(readlink -f "${LOCAL_PATH}")

echo "======================================"
echo " DOCKER_IMG       = ${DOCKER_IMG}"
echo " FULLON_VERSION   = ${FULLON_VERSION}"
echo " BRANCH           = ${BRANCH}"
echo " MODE             = ${MODE}"
echo " LOCAL_PATH       = ${LOCAL_PATH}"
echo " REPO             = ${REPO}"
echo "======================================"

# === Step 0-A: 构建 builder base 镜像 ===
if [[ "$(docker images -q ${BUILDER_BASE_IMG} 2> /dev/null)" == "" ]]; then
  echo "[0A] Building base builder image..."
  docker build -f Dockerfile.base -t ${BUILDER_BASE_IMG} .
else
  echo "[0A] Builder base image already exists: ${BUILDER_BASE_IMG}"
fi

# === Step 0-B: 构建 runtime base 镜像 ===
if [[ "$(docker images -q ${RUNTIME_BASE_IMG} 2> /dev/null)" == "" ]]; then
  echo "[0B] Building runtime base image..."
  docker build -f Dockerfile.runtime.base -t ${RUNTIME_BASE_IMG} .
else
  echo "[0B] Runtime base image already exists: ${RUNTIME_BASE_IMG}"
fi

# === Step 1: 编译 .deb 包 ===
echo "[1/4] Building .deb package using Dockerfile.build..."
docker build -f Dockerfile.build -t fullon/builder \
  --build-arg BRANCH=${BRANCH} \
  --build-arg REPO=${REPO} \
  --build-arg MODE=${MODE} \
  --build-arg LOCAL_PATH=${LOCAL_PATH} \
  --build-arg FULLON_VERSION=${FULLON_VERSION} .

# === Step 2: 提取 .deb 包 ===
echo "[2/4] Exporting .deb from builder..."
CONTAINER_ID=$(docker create fullon/builder)
docker cp ${CONTAINER_ID}:/fullon.install.deb ./fullon.install.deb
docker rm ${CONTAINER_ID}

# === Step 3: 构建最终运行镜像 ===
echo "[3/4] Building final runtime image..."
docker build -f Dockerfile.runtime -t ${NODE_IMG_HEADER}${DOCKER_IMG}:${FULLON_VERSION} .

# 清理临时 .deb 文件
rm -f ./fullon.install.deb

echo "✅ Done. Final image: ${NODE_IMG_HEADER}${DOCKER_IMG}:${FULLON_VERSION}"