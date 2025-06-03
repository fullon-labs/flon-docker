#!/bin/bash
set -eu

source ./env
logfile="/tmp/log.txt"
redis_connect="redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASS"

> "$logfile"  # 清空日志，每次执行前

while IFS=',' read -r ALERT_NAME HEAD_KEY TABLE_NAME CONTAINER_NAME; do
  echo "------------------------------" >> "$logfile"
  echo "[INFO][$(date '+%F %T')] Checking: $ALERT_NAME" >> "$logfile"
  echo "[INFO][$(date '+%F %T')] Table: $TABLE_NAME, Redis Key: $HEAD_KEY, Container: $CONTAINER_NAME" >> "$logfile"

  # 查询数据库获取最新 head
  echo "[INFO][$(date '+%F %T')] Executing SQL: select head from $TABLE_NAME" >> "$logfile"
  new_head=$(docker run --rm --network host -e PGPASSWORD="$PG_PASS" postgres:15 \
    psql -t -A -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" \
    -c "select head from ${TABLE_NAME};" 2>> "$logfile" || echo "")

  if [[ -z "$new_head" ]]; then
    echo "[ERROR][$(date '+%F %T')] Failed to get head from table $TABLE_NAME" >> "$logfile"
    text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "*'"$ALERT_NAME"' 扫链 head 查询失败，无法获取最新数据，请检查数据库连接或配置*"}'
    curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"
    continue
  fi

  old_head=$($redis_connect GET "$HEAD_KEY" || echo 0)
  alert_status=$($redis_connect GET "$ALERT_NAME" || echo "")

  echo "[DEBUG][$(date '+%F %T')] new_head=$new_head, old_head=$old_head, alert_status=$alert_status" >> "$logfile"

  $redis_connect SET "$HEAD_KEY" "$new_head" > /dev/null

  if [ "$new_head" = "$old_head" ]; then
    if [ -z "$alert_status" ]; then
      $redis_connect SET "$ALERT_NAME" 1
      $redis_connect EXPIRE "$ALERT_NAME" 3600
      $redis_connect SET "$ALERT_NAME:count" 1
      $redis_connect EXPIRE "$ALERT_NAME:count" 3600
      echo "[WARN][$(date '+%F %T')] No head change, set alert stage 1, count=1" >> "$logfile"
    else
      restart_count=$($redis_connect GET "$ALERT_NAME:count" || echo 0)

      if [ "$restart_count" -le 3 ]; then
        new_count=$((restart_count + 1))
        $redis_connect SET "$ALERT_NAME" 2
        $redis_connect SET "$ALERT_NAME:count" "$new_count"
        $redis_connect EXPIRE "$ALERT_NAME" 3600
        $redis_connect EXPIRE "$ALERT_NAME:count" 3600

        echo "[ALERT][$(date '+%F %T')] Head still not updated. Restarting container: $CONTAINER_NAME (attempt $new_count)" >> "$logfile"
        text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "*'"$ALERT_NAME"' 扫链 head 无变化，尝试第 '"$new_count"' 次重启容器*"}'
        curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"

        sleep 3
        if docker restart "$CONTAINER_NAME" >> "$logfile" 2>&1; then
          echo "[INFO][$(date '+%F %T')] 容器 $CONTAINER_NAME 重启成功" >> "$logfile"
        else
          echo "[ERROR][$(date '+%F %T')] 容器 $CONTAINER_NAME 重启失败，请检查" >> "$logfile"
        fi
     else
        last_notify=$($redis_connect GET "$ALERT_NAME:last_notify" || echo 0)
        now_ts=$(date +%s)

        if (( now_ts - last_notify >= 10800 )); then  # 10800 秒 = 3 小时
          $redis_connect SET "$ALERT_NAME:last_notify" "$now_ts"
          $redis_connect EXPIRE "$ALERT_NAME:last_notify" 10800

          echo "[ERROR][$(date '+%F %T')] Head still not updated. Retry limit reached (>$restart_count), sending periodic reminder." >> "$logfile"
          text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "*'"$ALERT_NAME"' 扫链容器重启已超过 3 次，停止重启，请人工检查 🚨*"}'
          curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"
        else
          echo "[INFO][$(date '+%F %T')] 超过3次后提醒间隔未到，跳过通知" >> "$logfile"
        fi
      fi
    fi
  else
    # 恢复正常，清除状态
    if [ "$alert_status" = "2" ]; then
      text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "*'"$ALERT_NAME"' 扫链已恢复正常 ✅*"}'
      curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"
      echo "[INFO][$(date '+%F %T')] $ALERT_NAME 已恢复，通知已发送" >> "$logfile"
    fi
    $redis_connect DEL "$ALERT_NAME" > /dev/null
    $redis_connect DEL "$ALERT_NAME:count" > /dev/null
    $redis_connect DEL "$ALERT_NAME:last_notify" > /dev/null
    echo "[INFO][$(date '+%F %T')] $ALERT_NAME head 正常更新，状态清除" >> "$logfile"
  fi
done < ./monitors.conf

# 每周一/四 09:00 例行执行确认
weekday=$(date '+%u')  # 1=周一, 4=周四
hour=$(date '+%H')
minute=$(date '+%M')  # ✅ 加上这行
hostname=$(hostname)

if { [ "$weekday" = "1" ] || [ "$weekday" = "4" ]; } && [ "$hour" = "09" ] && [ "$minute" = "00" ]; then
  text='{"parse_mode": "markdown","chat_id": '"$CHAT_ID"',"text": "✅ ['$hostname'] 扫链监控任务正常执行中（每周一 & 四例行确认）"}'
  curl -s -X POST -H 'Content-Type: application/json' -d "$text" "$TG_BOT" >> "$logfile"
  echo "[INFO][$(date '+%F %T')] 每周例行确认消息已发送（周一/周四） hostname=$hostname" >> "$logfile"
fi