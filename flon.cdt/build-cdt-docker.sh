#!/bin/bash
set -e

# 加载自定义环境变量
if [ -f ~/flon.env ]; then
  source ~/flon.env
fi

# 默认参数
CDT_VERSION="${CDT_VERSION:-0.5.0-alpha}"
CDT_BRANCH="${CDT_BRANCH:-main}"
NODE_IMG_HEADER="${NODE_IMG_HEADER:-}"  # 允许为空，不加默认避免误推镜像

# 输出构建信息
echo "========================================"
echo "Building image: ${NODE_IMG_HEADER}floncore/floncdt:${CDT_VERSION}"
echo "Build args:"
echo "  - CDT_VERSION = ${CDT_VERSION}"
echo "  - CDT_BRANCH  = ${CDT_BRANCH}"
echo "========================================"

# 执行构建
docker build \
  --build-arg CDT_VERSION="${CDT_VERSION}" \
  --build-arg CDT_BRANCH="${CDT_BRANCH}" \
  -t "${NODE_IMG_HEADER}floncore/floncdt:${CDT_VERSION}" \
  . --no-cache