#!/bin/bash
set -e

# === 加载环境变量 ===
if [ -f ~/flon.env ]; then
  source ~/flon.env
fi

# === 默认参数 ===
DOCKER_IMG=${DOCKER_IMG:-"floncore/history-tools"}
HISTORY_VERSION=${HISTORY_VERSION:-"0.5.0-alpha"}
BRANCH=${BRANCH:-"master"}
REPO=${REPO:-"https://github.com/fullon-labs/history-tools.git"}
NODE_IMG_HEADER=${NODE_IMG_HEADER:-""}

# === 镜像名 ===
BUILDER_BASE_IMG="history-tools/base-builder"
RUNTIME_BASE_IMG="history-tools/runtime-base"
FINAL_TAG="${NODE_IMG_HEADER}${DOCKER_IMG}:${HISTORY_VERSION}"

echo "======================================"
echo " DOCKER_IMG        = ${DOCKER_IMG}"
echo " HISTORY_VERSION   = ${HISTORY_VERSION}"
echo " BRANCH            = ${BRANCH}"
echo " REPO              = ${REPO}"
echo " FINAL_TAG         = ${FINAL_TAG}"
echo "======================================"

# === Step 0-A: 构建编译 base 镜像 ===
if [[ "$(docker images -q ${BUILDER_BASE_IMG} 2> /dev/null)" == "" ]]; then
  echo "[0A] Building base builder image..."
  docker build -f Dockerfile.base -t ${BUILDER_BASE_IMG} .
else
  echo "[0A] Base builder image already exists."
fi

# === Step 0-B: 构建运行 base 镜像 ===
if [[ "$(docker images -q ${RUNTIME_BASE_IMG} 2> /dev/null)" == "" ]]; then
  echo "[0B] Building runtime base image..."
  docker build -f Dockerfile.runtime.base -t ${RUNTIME_BASE_IMG} .
else
  echo "[0B] Runtime base image already exists."
fi

# === Step 1: 构建 builder 镜像，产出 fill-pg ===
echo "[1/3] Building builder image and compiling fill-pg..."
docker build -f Dockerfile.build -t history-tools/builder \
  --build-arg BRANCH=${BRANCH} \
  --build-arg REPO=${REPO} .

# === Step 2: 提取 fill-pg 可执行文件 ===
echo "[2/3] Extracting fill-pg binary..."
docker create --name extract-container history-tools/builder
docker cp extract-container:/root/history-tools/build/fill-pg ./fill-pg
docker rm extract-container

# === Step 3: 构建最终运行镜像 ===
echo "[3/3] Building runtime image: ${FINAL_TAG}"
docker build -f Dockerfile.runtime -t ${FINAL_TAG} .

# === 可选清理构建产物 ===
rm -f ./fill-pg

echo "✅ Done. Final image built: ${FINAL_TAG}"