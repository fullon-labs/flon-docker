#!/bin/bash
set -eu

source ./env
logfile="/tmp/log.txt"
redis_connect="redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASS"

while IFS=',' read -r ALERT_NAME HEAD_KEY TABLE_NAME CONTAINER_NAME; do
  echo "------------------------------" >> "$logfile"
  echo "[INFO][$(date '+%F %T')] Checking: $ALERT_NAME" >> "$logfile"
  echo "[INFO][$(date '+%F %T')] Table: $TABLE_NAME, Redis Key: $HEAD_KEY, Container: $CONTAINER_NAME" >> "$logfile"

  # 查询数据库获取最新 head
  echo "[INFO][$(date '+%F %T')] Executing SQL: select head from $TABLE_NAME" >> "$logfile"
  new_head=$(docker run --rm --network host -e PGPASSWORD="$PG_PASS" postgres:15 \
    psql -t -A -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" \
    -c "select head from ${TABLE_NAME};" 2>> "$logfile" || echo "")

  # 检查数据库查询是否成功
  if [[ -z "$new_head" ]]; then
    echo "[ERROR][$(date '+%F %T')] Failed to get head from table $TABLE_NAME" >> "$logfile"
    # 发送失败消息
    text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "*'"$ALERT_NAME"' 扫链 head 查询失败，无法获取最新数据，请检查数据库连接或配置*"}'
    curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"
    continue
  fi

  old_head=$($redis_connect GET "$HEAD_KEY" || echo 0)
  alert_status=$($redis_connect GET "$ALERT_NAME" || echo "")

  $redis_connect SET "$HEAD_KEY" "$new_head" > /dev/null

  if [ "$new_head" = "$old_head" ]; then
    if [ -z "$alert_status" ]; then
      $redis_connect SET "$ALERT_NAME" 1 && $redis_connect EXPIRE "$ALERT_NAME" 3600
      echo "[WARN][$(date '+%F %T')] No head change, set alert stage 1" >> "$logfile"
    elif [ "$alert_status" = "1" ]; then
      echo "[ALERT][$(date '+%F %T')] Head still not updated. Restarting container: $CONTAINER_NAME" >> "$logfile"

      text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "*'"$ALERT_NAME"' 扫链 head 无变化，可能异常，请检查*"}'
      curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"

      $redis_connect SET "$ALERT_NAME" 2 && $redis_connect EXPIRE "$ALERT_NAME" 3600
      sleep 3
      docker restart "$CONTAINER_NAME" >> "$logfile" 2>&1
    fi
  else
    if [ "$alert_status" = "2" ]; then
      text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "*'"$ALERT_NAME"' 扫链已恢复正常 ✅*"}'
      curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"
      echo "[INFO][$(date '+%F %T')] $ALERT_NAME 已恢复，通知已发送" >> "$logfile"
    fi
    $redis_connect DEL "$ALERT_NAME" > /dev/null
    echo "[INFO][$(date '+%F %T')] $ALERT_NAME head 正常更新，状态清除" >> "$logfile"
  fi
done < monitors.conf


weekday=$(date '+%u')  # 周一是1，周日是7
hour=$(date '+%H')

if { [ "$weekday" = "1" ] || [ "$weekday" = "4" ]; } && [ "$hour" = "09" ]; then
  text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "✅ 扫链监控任务正常执行中（每周一 & 四例行确认）"}'
  curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"
  echo "[INFO][$(date '+%F %T')] 每周例行确认消息已发送（周一/周四）" >> "$logfile"
fi