#!/bin/bash

if [ -f ~/flon.env ]; then
  source ~/flon.env
else 
  echo "Error: ~/flon.env file not found!"
  exit 1
fi
IMAGE_NAME="floncore/history-tools"

bash -x ../../commtool/docker_upload.sh $GITHUB_USERNAME ${NODE_IMG_HEADER}${IMAGE_NAME} $HISTORY_VERSION