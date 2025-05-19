#!/bin/bash
set -euo pipefail  # 启用严格模式
# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

# 网络配置
configure_network() {
    case "${NET}" in
        "mainnet") 
            prefix=""
            ;;
        "testnet")
            prefix="1"
            ;;
        "devnet")
            prefix="2"
            ;;
        *) 
            error "Unsupported network type: ${NET}"
            ;;
    esac

    export NODE_PORT="${prefix}${NODE_PORT}"
    export POSTGRES_PORT="${prefix}${POSTGRES_PORT}"
    
    log "Network ports configured: NODE_PORT=${NODE_PORT}"
}

# 生成环境文件

# 生成环境文件
generate_env_file() {
    local output_file="${SCAN_WORK_PATH}/config/scan.env"
    
cat <<EOF > "${output_file}"
# Auto-generated configuration - $(date '+%Y-%m-%d %H:%M:%S')
# Network Configuration
NET=${NET}
HISTORY_VERSION=${HISTORY_VERSION}

# Port Configuration
NODE_PORT=${NODE_PORT}
NODE_HOST=${NODE_HOST}

# Database Configuration
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_PORT=${POSTGRES_PORT}
SCAN_CONTAINER_NAME=${SCAN_CONTAINER_NAME}
SCAN_WORK_PATH=${SCAN_WORK_PATH}

PG_HOST=${PG_HOST}
POSTGRES_DB=${POSTGRES_DB:-flonscan}
PG_PORT=${POSTGRES_PORT}
# Service Configuration
HISTORY_TOOLS_IMAGE=${NODE_IMG_HEADER}${HISTORY_TOOLS_IMAGE}:${HISTORY_VERSION}

FILL_TABLES=${FILL_TABLES}
EOF

    log "Generated environment file: ${output_file}"
}


start_services() {

    # 加载 Docker Compose 环境变量
    local ENV_FILE="${SCAN_WORK_PATH}/config/scan.env"
    if [ ! -f "${ENV_FILE}" ]; then
        error "Environment file not found: ${ENV_FILE}"
    fi
    source "${ENV_FILE}"

    # 写入 start-docker.sh 文件
    local START_SCRIPT="${SCAN_HOME_PATH}/start-docker.sh"
    cat > "${START_SCRIPT}" <<EOF
#!/bin/bash
cd "${SCAN_HOME_PATH}" || exit 1
docker-compose --env-file="${ENV_FILE}" up -d
EOF

   local STOP_SCRIPT="${SCAN_HOME_PATH}/stop-docker.sh"
    cat > "${STOP_SCRIPT}" <<EOF
#!/bin/bash
cd "${SCAN_HOME_PATH}" || exit 1
docker-compose --env-file="${ENV_FILE}" down
EOF

    chmod +x "${START_SCRIPT}"
    chmod +x "${STOP_SCRIPT}"

    log "Docker startup script written to: ${START_SCRIPT}"
    log "Now starting Docker services via ${START_SCRIPT}"
    "${START_SCRIPT}" || error "Failed to start services via ${START_SCRIPT}"
}

open_port() {
    if [[ "$(uname)" == "Linux" ]]; then
        sudo iptables -I INPUT -p tcp -m tcp --dport "$1" -j ACCEPT
    fi
}

main() {
    # 加载环境变量
    [ -f ~/flon.env ] && source ~/flon.env
    [ -f ./env ] && source ./env

    # 检查关键变量是否设置
    : "${SCAN_WORK_PATH:?SCAN_WORK_PATH is not set}"
    : "${SCAN_CONTAINER_NAME:?SCAN_CONTAINER_NAME is not set}"
    : "${NET:?NET is not set}"

    # 输出调试信息
    echo "[INFO] SCAN_WORK_PATH=${SCAN_WORK_PATH}"
    echo "[INFO] SCAN_CONTAINER_NAME=${SCAN_CONTAINER_NAME}"
    echo "[INFO] NET=${NET}"
    
    configure_network

    echo "[INFO] Checking if Docker network 'flon' exists..."
    docker network inspect flon >/dev/null 2>&1 || {
        echo "[INFO] Network 'flon' not found. Creating it..."
        docker network create flon
    }

    # 创建工作目录结构
    echo "[INFO] Creating directories under ${SCAN_WORK_PATH}..."
    sudo mkdir -p "${SCAN_HOME_PATH}"
    sudo chown -R "$(whoami):$(whoami)" "${SCAN_HOME_PATH}"
    mkdir -p "${SCAN_WORK_PATH}/config"
    mkdir -p "${SCAN_WORK_PATH}/logs"
    mkdir -p "${SCAN_WORK_PATH}/bin"

    # 生成环境变量文件（你需实现 generate_env_file 函数）
    generate_env_file
    cp ./start.sh "${SCAN_WORK_PATH}/bin/"
    cp docker-compose.yaml "${SCAN_HOME_PATH}/"
    sudo chmod +x "${SCAN_WORK_PATH}/bin/start.sh"

    # 启动服务（你需实现 start_services 函数）
    start_services "$@"

    open_port ${POSTGRES_PORT}

    # 打印部署完成日志
    log "Deployment completed successfully"
}


main "$@"