#!/bin/bash

# 加载 Telegram Bot 配置（需要包含 tgbot 和 chat_id 两个变量）
source ~/.tgbot.env

# 读取 build_report.txt 内容（限制最大行数避免消息过长）
if [ -f ~/build_report.txt ]; then
    TEXT=$(tail -n 20 ~/build_report.txt | sed 's/"/\\"/g')
else
    TEXT="No build_report.txt found"
fi

# 构造 Telegram 消息 JSON
tg_msg=$(jq -nc --arg text "$TEXT" --arg chat_id "$chat_id" '{
  chat_id: $chat_id,
  text: $text,
  parse_mode: "Markdown",
  disable_web_page_preview: true
}')

# 发送 Telegram 消息
curl -s -o /dev/null -X POST -H 'Content-Type: application/json' -d "$tg_msg" "$tgbot"
