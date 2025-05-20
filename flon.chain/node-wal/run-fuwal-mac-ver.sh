

git clone git@github.com:fullon-labs/flon-docker.git




cd flon-docker
cp ./flon.env ~/flon.env
#修改 ~/flon.evn set NET mainnet
#NET=mainnet

mkdir -p ~/.fuwal
cd flon-docker/flon.chain/node-wal
./run-fuwal.sh ~/.fuwal


# 也可以执行一下命令运行 Docker 容器
cd ~/.fuwal
docker run -d \
  --name fuwal \
  --workdir /opt/flon \
  --entrypoint ./bin/run-wallet.sh \
  -v "$(pwd)":/opt/flon \
  -v "$(pwd)/bin/.bashrc":/root/.bashrc \
  -v "$(pwd)/bin-script":/root/bin \
  -v /Users/joss/code/workspace:/workspace \
  ghcr.io/fullon-labs/floncore/funod:0.5.0 \
  .