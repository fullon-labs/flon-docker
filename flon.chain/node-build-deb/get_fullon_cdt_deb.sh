#!/bin/bash

if [ -f ~/flon.env ]; then
    source ~/flon.env
fi
IMG=${NODE_IMG_HEADER}floncore/floncdt:${CDT_VERSION}
package_name="flon.cdt"

bash -x ./get.deb.package.sh $IMG $package_name