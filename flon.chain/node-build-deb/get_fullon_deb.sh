
if [ -f ~/flon.env ]; then
    source ~/flon.env
fi
IMG=${NODE_IMG_HEADER}floncore/funod:${FULLON_VERSION}
package_name="flon-core"
bash -x ./get.deb.package.sh $IMG $package_name
