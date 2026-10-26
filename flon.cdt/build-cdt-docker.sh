#!/bin/bash
set -e

# CI must supply release inputs explicitly so the build agent's user-level
# flon.env cannot silently replace the requested tag or image version.
FLON_LOAD_USER_ENV="${FLON_LOAD_USER_ENV:-true}"
if [ "${FLON_LOAD_USER_ENV}" = "true" ] && [ -f ~/flon.env ]; then
  source ~/flon.env
fi

# 默认参数
CDT_VERSION="${CDT_VERSION:-0.5.0-alpha}"
CDT_BRANCH="${CDT_BRANCH:-main}"
NODE_IMG_HEADER="${NODE_IMG_HEADER:-}"  # 允许为空，不加默认避免误推镜像
TARGET_PLATFORM="${TARGET_PLATFORM:-}"

# 输出构建信息
echo "========================================"
echo "Building image: ${NODE_IMG_HEADER}floncore/floncdt:${CDT_VERSION}"
echo "Build args:"
echo "  - CDT_VERSION = ${CDT_VERSION}"
echo "  - CDT_BRANCH  = ${CDT_BRANCH}"
echo "  - PLATFORM    = ${TARGET_PLATFORM:-native}"
echo "========================================"

# 执行构建
build_args=(
  --build-arg "CDT_VERSION=${CDT_VERSION}"
  --build-arg "CDT_BRANCH=${CDT_BRANCH}"
  -t "${NODE_IMG_HEADER}floncore/floncdt:${CDT_VERSION}"
  --no-cache
  .
)

if [ -n "${TARGET_PLATFORM}" ]; then
  docker buildx build --platform "${TARGET_PLATFORM}" --load "${build_args[@]}"
else
  docker build "${build_args[@]}"
fi
