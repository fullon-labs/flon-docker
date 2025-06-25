#!/bin/bash
if [ -f ~/flon.env ]; then
  source ~/flon.env
fi

# Default values for build parameters
CDT_VERSION=${CDT_VERSION:-"0.5.0-alpha"}

echo "Building image: ${NODE_IMG_HEADER}floncore/floncdt:${CDT_VERSION}"
echo "Build args: CDT_VERSION=${CDT_VERSION}"

docker build \
  --build-arg CDT_VERSION="${CDT_VERSION}" \
  -t "${NODE_IMG_HEADER}floncore/floncdt:${CDT_VERSION}" \
  . --no-cache