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

    export POSTGRES_PORT="${prefix}${POSTGRES_PORT}"
    export NODE_PORT="${prefix}${NODE_PORT}"
    
    log "Network ports configured: POSTGRES_PORT=${POSTGRES_PORT}, NODE_PORT=${NODE_PORT}"
}

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
POSTGRES_CONTAINER_NAME=${POSTGRES_CONTAINER_NAME}
SCAN_CONTAINER_NAME=${SCAN_CONTAINER_NAME}
PG_DATA=${PG_DATA}
SCAN_WORK_PATH=${SCAN_WORK_PATH}

PG_HOST=${PG_HOST}
POSTGRES_DB=${POSTGRES_DB:-flonscan}

# Service Configuration
HISTORY_TOOLS_IMAGE=${NODE_IMG_HEADER}${HISTORY_TOOLS_IMAGE}:${HISTORY_VERSION}

FILL_TABLES=${FILL_TABLES}
EOF

    log "Generated environment file: ${output_file}"
}

start_services() {
    # 切换工作目录
    cd "${SCAN_WORK_PATH}" || error "Failed to change directory to ${SCAN_WORK_PATH}"
    log "Preparing Docker service startup script in ${SCAN_WORK_PATH}"

    # 创建 PostgreSQL 数据目录并设置权限
    if [ -n "${PG_DATA}" ]; then
        sudo mkdir -p "${PG_DATA}"
        sudo chown -R "$(whoami):$(whoami)" "${PG_DATA}"
    else
        error "PG_DATA is not set"
    fi

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

    # 配置网络（你需实现 configure_network 函数）
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
    mkdir -p "${PG_DATA}"

    # 生成环境变量文件（你需实现 generate_env_file 函数）
    generate_env_file
    cp start.sh "${SCAN_WORK_PATH}/bin/"
    cp docker-compose.yaml "${SCAN_HOME_PATH}/"
    sudo chmod +x "${SCAN_WORK_PATH}/bin/start.sh"

    # 启动服务（你需实现 start_services 函数）
    start_services "$@"

    # 修改 PostgreSQL 配置
    POSTGRES_CONF="${PG_DATA}/postgresql.conf"
    if [ -f "$POSTGRES_CONF" ]; then
        echo "[INFO] Modifying PostgreSQL max_connections in ${POSTGRES_CONF}"
        sudo sed -i 's/^max_connections = .*/max_connections = 500/' "$POSTGRES_CONF"
    else
        echo "[WARN] PostgreSQL config not found at: $POSTGRES_CONF"
    fi

    # 打印部署完成日志
    log "Deployment completed successfully"
}


main "$@"