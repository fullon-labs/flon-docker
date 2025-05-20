#!bin/sh

#docker exec -it fuwal bash

cd /opt/contracts/
apt update
apt install -y git
curl -o flon.cdt.deb https://flon-test.oss-cn-hongkong.aliyuncs.com/deb/flon.cdt_0.5.0-1_amd64.deb

git clone https://github.com/fullon-labs/toolkit.contracts.git
git clone https://github.com/fullon-labs/flon.contracts.git

apt install -y libssl-dev libboost-all-dev libgmp3-dev libbz2-dev libreadline-dev libncurses5-dev libusb-1.0-0-dev libudev-dev libusb-dev libusb-1.0-0
apt install libcurl4-gnutls-dev cmake -y
apt install -y g++ libz3-dev

cd /opt/contracts/
dpkg -i flon.cdt.deb


