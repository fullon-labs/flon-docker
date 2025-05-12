#! /bin/bash

NODE_HOME=$1

WALLDIR=$NODE_HOME
DATDIR=$WALLDIR/data
CONFDIR=$WALLDIR/conf
LOGDIR=$WALLDIR/logs

TIMESTAMP=$(/bin/date +%s)
NEW_LOG="flon-wal-$TIMESTAMP.log"

#apt update && apt install -y libusb-1.0-0

fuwal --config-dir ./conf -d ./data --unix-socket-path ./fuwal.sock >> $LOGDIR/$NEW_LOG 2>&1 &

echo $! > $DATDIR/wallet.pid
unlink $LOGDIR/flon-wal.log
ln -s /opt/flon/logs/$NEW_LOG /opt/flon/logs/flon-wal.log
tail -f /dev/null
