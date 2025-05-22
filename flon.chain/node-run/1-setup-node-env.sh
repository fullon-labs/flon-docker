#!/bin/bash

# Load environment variables
if [ -f ~/flon.env ]; then
    source ~/flon.env
fi
source ./conf.env

if [ "$NET" == "devnet" ]; then
    source ./$NET/conf.bp.env
else
    if ${bp_plugin}; then
        if [ ! -f ~/conf.bp.env ]; then
            echo -e "\e[31mPlease copy the conf.bp.env file to your home directory: ~/conf.bp.env\e[0m"
            exit 1
        fi
        
        source ~/conf.bp.env
    fi
fi

# Define configuration directory
if [ -z "$node_name" ]; then
    echo "❌ Error: node_name is not set" >&2
    exit 1
fi

CONF_DIR=~/.${node_name}

if [ -d "$CONF_DIR" ]; then
    echo -e "\e[31mConfiguration directory already exists. Please check it first: $CONF_DIR\e[0m"
    exit 1
fi

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
    cp -r ./bin                 "$CONF_DIR/"
}

copy_configs

# Write to node.env file
write_node_env() {
    cat <<EOF >> "$CONF_DIR/node.env"
NET=$NET
FULLON_VERSION=$FULLON_VERSION
node_name=$node_name
NODE_HOME=$NODE_HOME
NODE_WORK_PATH=\$NODE_HOME/\$node_name
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
NODE_IMG_HEADER=$NODE_IMG_HEADER
EOF
}

write_node_env

# Copy and set up the run script
cp ./run-node-template.sh "$CONF_DIR/run.sh"
chmod +x "$CONF_DIR/run.sh"
