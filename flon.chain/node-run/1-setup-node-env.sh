#!/bin/bash

# Load environment variables
source ./conf.env
source ./"$NET"/conf.bp.env

# Define configuration directory
CONF_DIR=~/.flon_"${NET}"_"${container_id}"
mkdir -p "$CONF_DIR"/conf
echo "Configuration directory: $CONF_DIR"

# Set ports based on network type
set_ports() {
    local prefix=$1
    P2P_PORT="${prefix}${P2P_PORT}"
    RPC_PORT="${prefix}${RPC_PORT}"
    HIST_WS_PORT="${prefix}${HIST_WS_PORT}"
}

case "$NET" in
    "mainnet")
        # Mainnet uses default ports
        ;;
    "testnet")
        set_ports "1"  # Testnet port prefix is 1
        ;;
    "devnet")
        set_ports "2"  # Devnet port prefix is 2
        ;;
    *)
        echo "Unknown network type: $NET"
        exit 1
        ;;
esac

# Check if node.env file already exists
if [ -f "$CONF_DIR/node.env" ]; then
    echo "Error: node.env file already exists. Please check it first."
    exit 1
fi

# Copy configuration files
copy_configs() {
    cp ./"$NET"/genesis.json    "$CONF_DIR/"
    cp ./docker-compose.yml     "$CONF_DIR/"
    cp ./conf_template/*    "$CONF_DIR"/conf/
    cp ./"$NET"/node.ini        "$CONF_DIR"/conf/
    cp -r ./bin                 "$CONF_DIR/"
}

copy_configs

# Write to node.env file
write_node_env() {
    cat <<EOF >> "$CONF_DIR/node.env"
NET=$NET
NODE_IMG_VER=$NODE_IMG_VER
container_id=$container_id
NODE_HOME=$NODE_HOME
agent_name=$agent_name
p2p_server_address=$p2p_server_address
p2p_peer_addresses=(${p2p_peer_addresses[*]})
P2P_PORT=$P2P_PORT
RPC_PORT=$RPC_PORT
HIST_WS_PORT=$HIST_WS_PORT
trace_plugin=$trace_plugin
state_plugin=$state_plugin
history_plugin=$history_plugin
bp_plugin=$bp_plugin
signature_providers=(${signature_providers[*]})
producer_names=(${producer_names[*]})
EOF
}

write_node_env

# Copy and set up the run script
cp ./run-node-template.sh "$CONF_DIR/run.sh"
chmod +x "$CONF_DIR/run.sh"
