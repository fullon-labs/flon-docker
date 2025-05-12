#!/bin/bash

# 设置错误退出模式
set -e  # 启用错误退出，如果任何命令失败则脚本会立刻退出

# 错误输出函数
err() {
    echo "$(tput setaf 1)ERROR: $1$(tput sgr0)"
    exit 1
}

# 检查端口是否被占用，如果已占用，提示用户是否继续
check_port_with_prompt() {
    local port=$1
    if sudo netstat -tulnp | grep -q ":$port "; then
        echo -e "\033[31mERROR: Port $port is already in use.\033[0m" >&2
        read -p "Do you want to continue anyway? (y/N) " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                echo "Continuing despite port conflict..."
                return 0
                ;;
            *)
                echo "Aborting..."
                exit 1
                ;;
        esac
    fi
}

# 检查 Docker 容器是否已经存在
check_docker_exists() {
    container_name=$1
    if docker ps -a | grep -q "$container_name"; then
        echo "Docker container $container_name already exists."
        read -p "Do you want to continue anyway? (y/N) " answer
        case "$answer" in
            [yY]|[yY][eE][sS])
                echo "Continuing despite container conflict..."
                return 0
                ;;
            *)
                echo "Aborting..."
                exit 1
                ;;
        esac
    fi
}

# 确保 node.env 文件存在
[ ! -f ./node.env ] && err "Error: node.env file not found."

# 加载环境变量
set -a
source ./node.env
set +a

# 检查端口是否被占用
check_port_with_prompt "${RPC_PORT}"
check_port_with_prompt "${P2P_PORT}"
check_port_with_prompt "${HIST_WS_PORT}"

# 检查 Docker 容器是否已经存在
check_docker_exists ${node_name}

# 定义目标配置文件路径
DEST_CONF="${NODE_WORK_PATH}/conf/config.ini"

# 创建必要的目录
echo "Creating necessary directories..."
sudo mkdir -p "$NODE_WORK_PATH"
sudo chown -R "$USER":"$USER" "$NODE_WORK_PATH"
mkdir -p "$NODE_WORK_PATH"/{conf,data,logs}

# 复制文件到目标目录
echo "Copying necessary files..."
cp -r ./bin "$NODE_WORK_PATH/" && \
cp ./genesis.json "$NODE_WORK_PATH/conf/" && \
cp ./conf/base.ini "$DEST_CONF"

# 替换 config.ini 文件中的占位符
append_config() {
    echo -e "\n#### $1" >> "$DEST_CONF"
    cat "$2" >> "$DEST_CONF"
}

echo "Replacing placeholders in config.ini..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i "" "s/{{agent-name}}/${agent_name}/g" "$DEST_CONF"
    sed -i "" "s/{{p2p_server_address}}/${p2p_server_address}/g" "$DEST_CONF"
    sed -i "" "s/{{P2P_PORT}}/${P2P_PORT}/g" "$DEST_CONF"
else
    sed -i "s/{{agent-name}}/${agent_name}/g" "$DEST_CONF"
    sed -i "s/{{p2p-server-address}}/${p2p_server_address}/g" "$DEST_CONF"
    sed -i "s/{{P2P_PORT}}/${P2P_PORT}/g" "$DEST_CONF"
fi

# 添加 p2p 节点地址
if [ -n "${p2p_peer_addresses}" ]; then
    for peer in "${p2p_peer_addresses[@]}"; do
        echo "p2p-peer-address = $peer" >> "$DEST_CONF"
    done
fi

# 添加插件配置
if [ "${trace_plugin}" == "true" ]; then
    append_config "Trace plugin conf:" "./conf/plugin_trace.ini"
fi

if [ "${history_plugin}" == "true" ]; then
    append_config "History plugin conf:" "./conf/plugin_history.ini"
fi

if [ "${state_plugin}" == "true" ]; then
    append_config "State plugin conf:" "./conf/plugin_state.ini"
fi

if [ "${bp_plugin}" == "true" ]; then
    # 检查 producer_names 是否设置
    if [ ${#producer_names[@]} -eq 0 ]; then
        err "Error: bp_plugin is enabled but no producer_names are set."
    fi

    # 检查 signature_providers 是否设置
    if [ ${#signature_providers[@]} -eq 0 ]; then
        err "Error: bp_plugin is enabled but no signature_providers are set."
    fi

    append_config "Block producer plugin conf:" "./conf/plugin_bp.ini"
    
    for producer_name in "${producer_names[@]}"; do
        echo "producer-name = $producer_name" >> "$DEST_CONF"
    done
    for signature_provider in "${signature_providers[@]}"; do
        echo "signature-provider = $signature_provider" >> "$DEST_CONF"
    done
fi

# 创建 Docker 网络并启动容器
sleep 3

docker network create flon || echo "Docker network 'flon' already exists or failed to create."

# 启动 Docker 容器
echo "Starting Docker containers with docker-compose..."
echo "PORT_MAPPING: $PORT_MAPPING"
docker-compose --env-file ./node.env up -d

# 开放防火墙端口
open_port() {
    if [[ "$(uname)" == "Linux" ]]; then
        sudo iptables -I INPUT -p tcp -m tcp --dport "$1" -j ACCEPT
    fi
}

open_port "${RPC_PORT}"
open_port "${P2P_PORT}"
open_port "${HIST_WS_PORT}"

echo "Setup completed successfully!"
