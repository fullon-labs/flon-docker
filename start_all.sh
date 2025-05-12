#!/bin/bash

# Set log file location
HOME_DIR=$HOME
LOG_FILE="$HOME/start_all.log"

PROJECT_DIR=$HOME_DIR/flon-docker


cd $PROJECT_DIR/flon.chain/node-run
# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
# Start of process
./1-setup-node-env.sh >> "$LOG_FILE" 2>&1 || { log "Error: 1-setup-node-env.sh failed"; exit 1; }   

sleep 1
cd $PROJECT_DIR/.funod_testnet
bash -x ./run.sh >> "$LOG_FILE" 2>&1 || { log "Error: run.sh failed"; exit 1; }

sleep 1

cd $PROJECT_DIR/flon.chain/node-wal
bash -x ./run-fuwal.sh $PROJECT_DIR/fuwal >> "$LOG_FILE" 2>&1 || { log "Error: run.sh failed"; exit 1; }

sleep 1

#安装扫链
cd $PROJECT_DIR/flon.scan/docker-run
bash -x ./run.sh >> "$LOG_FILE" 2>&1 || { log "Error: run.sh failed"; exit 1; }
