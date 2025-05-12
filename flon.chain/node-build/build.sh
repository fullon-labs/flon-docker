#!/bin/bash
if [ -f ~/flon.env ]; then
  source ~/flon.env
fi
# Default values for build parameters
DOCKER_IMG=${DOCKER_IMG:-"floncore/funod"}
FULLON_VERSION=${FULLON_VERSION:-"0.5.0-alpha"}
BRANCH=${BRANCH:-"main"}
LOCAL_PATH=${LOCAL_PATH:-"../../"}
REPO=${REPO:-"https://github.com/fullon-labs/flon-core.git"}
MODE=${MODE:-"git"}

LOCAL_PATH=$(readlink -f "${LOCAL_PATH}")

# Build the Docker image
docker build -t ${NODE_IMG_HEADER}${DOCKER_IMG}:${FULLON_VERSION} \
  --build-arg BRANCH=${BRANCH} \
  --build-arg REPO=${REPO} \
  --build-arg MODE=${MODE} \
  --build-arg LOCAL_PATH=${LOCAL_PATH} \
  --build-arg FULLON_VERSION=${FULLON_VERSION} \
  --no-cache \
  .