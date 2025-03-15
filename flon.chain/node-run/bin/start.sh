#!/bin/bash

flon=$1
LOGFILE=$flon/logs/node.log
source $flon/bin/start.env
ulimit -c unlimited
ulimit -n 65535
ulimit -s 64000

TIMESTAMP=$(/bin/date +%s)
NEW_LOGFILE="${flon}/logs/${TIMESTAMP}.log" && touch $NEW_LOGFILE

OPTIONS="--data-dir $flon/data --config-dir $flon/conf"
#SNAPSHOT=./data/snapshots/snapshot-023e2079b717ba7fdfa8c183d41082467120781f3274e0b57235c4c3e02acdf4.bin
if [[ ! -f $flon/data/state/shared_memory.bin ]] && [[ -f "$SNAPSHOT" ]]; then
  OPTIONS="$OPTIONS --snapshot ${SNAPSHOT} "
elif [[ ! -f $flon/data/blocks/blocks.index ]]; then
  OPTIONS="$OPTIONS --genesis-json $flon/conf/genesis.json"
fi

trap 'echo "[$(date)]Start Shutdown"; kill $(jobs -p); wait; echo "[$(date)]Shutdown ok"' SIGINT SIGTERM

## launch node program...
fonod $params $OPTIONS >> $NEW_LOGFILE 2>&1 &
#node  $params $OPTIONS --delete-all-blocks >> $NEW_LOGFILE 2>&1 &
#node  $params $OPTIONS --hard-replay-blockchain --truncate-at-block 87380000 >> $NEW_LOGFILE 2>&1 &
echo $! > $flon/node.pid


[[ -f "$LOGFILE" ]] && unlink $LOGFILE
ln -s $NEW_LOGFILE $LOGFILE

# tail -f /dev/null
wait
