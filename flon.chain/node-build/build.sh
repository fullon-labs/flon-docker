#!/bin/bash
source $1
# Default values for build parameters
DOCKER_IMG=${DOCKER_IMG:-"fullon/fonod"}
VERSION=${VERSION:-"0.5.0-alpha"}
BRANCH=${BRANCH:-"main"}
LOCAL_PATH=${LOCAL_PATH:-"../../"}
REPO=${REPO:-"https://github.com/fullon-labs/flon-core.git"}
MODE=${MODE:-"git"}

# Build the Docker image
docker build -t ${DOCKER_IMG}:${VERSION} \
  --build-arg BRANCH=${BRANCH} \
  --build-arg REPO=${REPO} \
  --build-arg MODE=${MODE} \
  --no-cache \
  $@ .