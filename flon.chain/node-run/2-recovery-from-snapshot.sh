#!/bin/sh
source node.env

SNAPSHOT=$1

# Check if the snapshot file exists
if [ ! -f "$SNAPSHOT" ]; then
    echo "Snapshot file not found: $SNAPSHOT"
    exit 1
fi

