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
main() {


    [ -f ./env ] && source ./env

    # 检查关键变量是否设置
    : "${NET:?NET is not set}"

    # 输出调试信息
    echo "[INFO] PG_HOME_PATH=${PG_HOME_PATH}"
    echo "[INFO] NET=${NET}"

    echo "[INFO] Checking if Docker network 'flon' exists..."
    docker network inspect flon >/dev/null 2>&1 || {
        echo "[INFO] Network 'flon' not found. Creating it..."
        docker network create flon
    }

    # 创建工作目录结构
    echo "[INFO] Creating directories under ${PG_HOME_PATH}..."
    sudo mkdir -p "${PG_HOME_PATH}"
    sudo chown -R "$(whoami):$(whoami)" "${PG_HOME_PATH}"
    mkdir -p "${PG_DATA}"

    bash -x ./render.sh ${PG_HOME_PATH}/docker-compose.yml
    cd ${PG_HOME_PATH} || exit 1

    docker-compose up -d
    sleep 5

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