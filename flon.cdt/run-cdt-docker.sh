
#!/bin/bash
if [ -f ~/flon.env ]; then
  source ~/flon.env
fi

docker run -d --name flon-build -v ~/fuwal:/opt/flon ${NODE_IMG_HEADER}floncore/floncdt:$CDT_VERSION tail -f /dev/null