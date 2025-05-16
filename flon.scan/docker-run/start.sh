#!/bin/bash
source ./config/scan.env

echo "[$(date)] Waiting for nodeos service..."
while ! nc -z ${NODE_HOST} ${NODE_PORT}; do
  sleep 1
done

echo "[$(date)] Waiting for PostgreSQL..."
export PGPASSWORD=$POSTGRES_PASSWORD
until psql -U $POSTGRES_USER -h $PG_HOST -d $POSTGRES_DB -c 'SELECT 1' >/dev/null 2>&1; do
  sleep 1
done

trap 'echo "[$(date)] Start Shutdown"; kill $(jobs -p); wait; echo "[$(date)] Shutdown ok"' SIGINT SIGTERM

echo "[$(date)] Checking if fill_status table exists..."
if psql -U "$POSTGRES_USER" -h "$PG_HOST" -d "$POSTGRES_DB" -tAc "SELECT 1 FROM information_schema.tables WHERE table_schema='chain' AND table_name='fill_status'" | grep -q 1; then
  echo "[$(date)] Table exists, skipping create table..."
  fill-pg --fill-connect-to="${NODE_HOST}:${NODE_PORT}" --config-dir "${SCAN_WORK_PATH}/config" --fill-table "${FILL_TABLES}" >> "${SCAN_WORK_PATH}/logs/fill-pg.log" 2>&1 &
else
  echo "[$(date)] Table does not exist, will create tables..."
  fill-pg --fill-connect-to="${NODE_HOST}:${NODE_PORT}" --config-dir "${SCAN_WORK_PATH}/config" --fpg-create --fill-table "${FILL_TABLES}" >> "${SCAN_WORK_PATH}/logs/fill-pg.log" 2>&1 &
fi

# 等待后台 fill-pg 完成

echo "[$(date)] fill-pg startup completed. log: ${SCAN_WORK_PATH}/logs/fill-pg.log"
wait