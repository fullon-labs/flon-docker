#!/bin/bash
set -euo pipefail  # 更严格的错误处理

# 配置部分
NOD_DIR="${1:?请指定节点目录作为参数}"
NOD_DIR=$(realpath "$NOD_DIR")    
echo "NOD_DIR: ${NOD_DIR}"
readonly USER_ENV_FILE="$HOME/flon.env"

# 加载环境变量
set -a
if [[ -f "$USER_ENV_FILE" ]]; then
    source "$USER_ENV_FILE"
    FULLON_VERSION="${FULLON_VERSION:-latest}"  # 设置默认值
fi

CONTAINER_NAME=$(basename "$NOD_DIR"| sed 's/\.//g')
SERVICE_NAME=${CONTAINER_NAME}
# 检查 Docker 容器是否已经存在
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo "Docker容器 $CONTAINER_NAME 已经存在。"
    read -p "是否继续？(y/N) " answer
    case "$answer" in
        [yY]|[yY][eE][sS])
            echo "继续操作..."
            ;;
        *)
            echo "操作已取消。"
            exit 1
            ;;
    esac
fi

set +a
# 显示目录并让用户确认
echo "您指定的节点目录是: $NOD_DIR, CONTAINER_NAME: $CONTAINER_NAME"
read -p "确认是否正确？(y/n) " -n 1 -r
echo  # 换行

# 如果用户不输入 'y' 或 'Y'，则退出
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消。"
    exit 1
fi



# 创建目录结构
mkdir -p "${NOD_DIR}"/{bin,conf,data,logs,bin-script}

# 复制文件

if [ -z "$NET" ]; then
    echo "❌ 环境变量 NET 未设置，请设置为 mainnet 或 testnet"
    exit 1
fi

if [ "$NET" == "mainnet" ]; then
    cp -v ./bin/.flonmain.bashrc "$NOD_DIR/bin/.bashrc"
elif [ "$NET" == "testnet" ] || [ "$NET" == "devnet" ]; then
    cp -v ./bin/.flontest.bashrc "$NOD_DIR/bin/.bashrc"
else
    echo "❌ 无效的 NET 值：$NET，应为 'mainnet'、'testnet' 或 'devnet'"
    exit 1
fi

cp -v ./bin/run-wallet.sh "$NOD_DIR/bin/"
cp -v ./config.ini "$NOD_DIR/conf/"
mkdir -p "$NOD_DIR/bin-script/"
cp -vr ./bin-script "$NOD_DIR/"

sed -e "s#\${SERVICE_NAME}#$SERVICE_NAME#" \
    -e "s#\${CONTAINER_NAME}#$CONTAINER_NAME#" \
    -e "s#\${NODE_IMG_HEADER}#$NODE_IMG_HEADER#" \
    -e "s#\${FULLON_VERSION}#$FULLON_VERSION#" \
    -e "s#\${hostname}#$(hostname)#" \
    -e "s#\${host}#$NOD_DIR#" docker-compose.template.yml > docker-compose.yml
cp -v ./docker-compose.yml "$NOD_DIR/docker-compose.yml"

# 检查并创建外部 Docker 网络
if ! docker network inspect flon &>/dev/null; then
    echo "Docker 网络 'flon' 不存在，正在创建..."
    docker network create flon
else
    echo "Docker 网络 'flon' 已存在。"
fi
cd "$NOD_DIR" || exit 1
# 启动Docker容器

# 判断 compose 命令：优先使用 docker compose，再 fallback 到 docker-compose
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ 未检测到 docker compose 或 docker-compose。" >&2
    exit 1
fi

echo "🚀 正在启动 Docker 容器..."

if $COMPOSE_CMD up -d; then
    echo "✅ Docker 容器启动成功"
else
    echo "❌ Docker 容器启动失败" >&2
    exit 1
fi