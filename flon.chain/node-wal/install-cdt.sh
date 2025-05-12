#!bin/sh
cd ~/fuwal

curl -o flon.cdt.deb https://flon-test.oss-cn-hongkong.aliyuncs.com/deb/flon.cdt_0.3.2-alpha_amd64.deb

mkdir contracts
git clone https://github.com/fullon-labs/toolkit.contracts.git
git clone https://github.com/fullon-labs/flon.contracts.git

docker exec -it fuwal bash

apt update
apt install -y libssl-dev libboost-all-dev libgmp3-dev libbz2-dev libreadline-dev libncurses5-dev libusb-1.0-0-dev libudev-dev libusb-dev libusb-1.0-0
apt install libcurl4-gnutls-dev cmake -y
apt install -y g++ libz3-dev

cd /opt/flon
dpkg -i flon.cdt.deb


