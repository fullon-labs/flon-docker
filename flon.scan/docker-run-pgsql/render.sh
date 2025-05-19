#!/bin/bash
set -e

ENV_IN="env"
ENV_RESOLVED=".env.resolved"
TEMPLATE="docker-compose.tpl.yml"
OUTPUT=$1

echo "🔄 Resolving nested .env variables..."

# 读取所有变量，递归展开
eval "$(
  grep -v '^#' "$ENV_IN" | while IFS='=' read -r key val; do
    # 去除空格和引号
    clean_val=$(echo "$val" | sed 's/^["'\'']//;s/["'\'']$//')
    echo "export $key=\"$clean_val\""
  done
)"

# 收集展开后的变量
echo "📝 Writing resolved variables to $ENV_RESOLVED ..."
{
  echo "POSTGRES_USER=$POSTGRES_USER"
  echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
  echo "POSTGRES_PORT=$POSTGRES_PORT"
  echo "POSTGRES_DB=$POSTGRES_DB"
  echo "POSTGRES_CONTAINER_NAME=$POSTGRES_CONTAINER_NAME"
  echo "PG_DATA=$PG_DATA"
} > "$ENV_RESOLVED"

# 渲染 Compose 文件
echo "📦 Generating $OUTPUT from $TEMPLATE ..."
export $(cat "$ENV_RESOLVED" | xargs)
envsubst < "$TEMPLATE" > "$OUTPUT"

echo "✅ Done: $OUTPUT generated."
rm -f "$ENV_RESOLVED"
echo "🗑️  Cleaning up temporary files..."