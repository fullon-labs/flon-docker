#!/bin/bash
source ./config/scan.env
echo "========================================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for nodeos service..."
echo "     Host : ${NODE_HOST}"
echo "     Port : ${NODE_PORT}"
while ! nc -z ${NODE_HOST} ${NODE_PORT}; do
  sleep 1
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for PostgreSQL..."
export PGPASSWORD=$POSTGRES_PASSWORD
echo "===> Connecting to PostgreSQL..."
echo "     Host     : $PG_HOST"
echo "     Port     : $PG_PORT"
echo "     User     : $POSTGRES_USER"
echo "     Database : $POSTGRES_DB (✔Database exists.)"

until psql -U $POSTGRES_USER -h $PG_HOST -p "$PG_PORT" -d $POSTGRES_DB -c 'SELECT 1' >/dev/null 2>&1; do
  sleep 1
done

trap 'echo "[$(date '+%Y-%m-%d %H:%M:%S')] Start Shutdown"; kill $(jobs -p); wait; echo "[$(date '+%Y-%m-%d %H:%M:%S')] Shutdown ok"' SIGINT SIGTERM

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking if fill_status table exists..."
if psql -U "$POSTGRES_USER" -h "$PG_HOST" -p "$PG_PORT" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM information_schema.tables WHERE table_schema='chain' AND table_name='fill_status'" | grep -q 1; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Table exists, skipping create table..."
  fill-pg --fill-connect-to="${NODE_HOST}:${NODE_PORT}" --config-dir "${SCAN_WORK_PATH}/config" --fill-table "${FILL_TABLES}" >> "${SCAN_WORK_PATH}/logs/fill-pg.log" 2>&1 &
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Table does not exist, will create tables..."
  fill-pg --fill-connect-to="${NODE_HOST}:${NODE_PORT}" --config-dir "${SCAN_WORK_PATH}/config" --fpg-create --fill-table "${FILL_TABLES}" >> "${SCAN_WORK_PATH}/logs/fill-pg.log" 2>&1 &
fi

# 等待后台 fill-pg 完成

echo "[$(date '+%Y-%m-%d %H:%M:%S')] fill-pg startup completed. log: ${SCAN_WORK_PATH}/logs/fill-pg.log"
wait