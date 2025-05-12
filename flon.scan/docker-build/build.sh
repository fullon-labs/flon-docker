#!/bin/bash
if [ -f ~/flon.env ]; then
  source ~/flon.env
fi
# Default values for build parameters
DOCKER_IMG=${DOCKER_IMG:-"floncore/history-tools"}
HISTORY_VERSION=${HISTORY_VERSION:-"0.5.0-alpha"}
BRANCH=${BRANCH:-"master"}
REPO=${REPO:-"https://github.com/fullon-labs/history-tools.git"}

# Build the Docker image
docker build -t ${NODE_IMG_HEADER}${DOCKER_IMG}:${HISTORY_VERSION} \
  --build-arg BRANCH=${BRANCH} \
  --build-arg REPO=${REPO} \
  --no-cache \
  .