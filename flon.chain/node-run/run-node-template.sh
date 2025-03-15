#!/bin/bash

[ ! -f ./node.env ] && echo "Error: node.env file not found. Exiting..." && exit 1

set -a
source ./node.env
set +a

# Define destination directories
DEST_HOME="${NODE_HOME}/flon_${NET}_${container_id}"
DEST_CONF="${DEST_HOME}/conf/config.ini"

# Create necessary directories
mkdir -p "$DEST_HOME"/{conf,data,logs}

# Copy files to destination
cp -r ./bin "$DEST_HOME/" && \
cp ./genesis.json "$DEST_HOME/conf/" && \
cp ./conf/base.ini "$DEST_CONF"

# Append node configuration to config.ini
append_config() {
    echo -e "\n#### $1" >> "$DEST_CONF"
    cat "$2" >> "$DEST_CONF"
}

# Replace placeholders in config.ini
sed -i "s/agent_name/${agent_name}/g" "$DEST_CONF"
sed -i "s/p2p_server_address/${p2p_server_address}/g" "$DEST_CONF"
sed -i "s/P2P_PORT/${P2P_PORT}/g" "$DEST_CONF"

# Add p2p peer addresses if they exist
if [ -n "${p2p_peer_addresses}" ]; then
    for peer in "${p2p_peer_addresses[@]}"; do
        echo "p2p-peer-address = $peer" >> "$DEST_CONF"
    done
fi

# Append plugin configurations if enabled
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
    append_config "Block producer plugin conf:" "./conf/plugin_bp.ini"
    for producer_name in "${producer_names[@]}"; do
        echo "producer-name = $producer_name" >> "$DEST_CONF"
    done
    for signature_provider in "${signature_providers[@]}"; do
        echo "signature-provider = $signature_provider" >> "$DEST_CONF"
    done
fi

# Create Docker network and start containers
docker network create flon || echo "Docker network 'flon' already exists or failed to create."
docker-compose --env-file ./node.env up -d

# Open firewall ports
open_port() {
    sudo iptables -I INPUT -p tcp -m tcp --dport "$1" -j ACCEPT
}

open_port "${RPC_PORT}"
open_port "${P2P_PORT}"
open_port "${HIST_WS_PORT}"

echo "Setup completed successfully!"