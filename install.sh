#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

CONFIG_DIR="${HOME}/.openclaw"
CONFIG_FILE="${CONFIG_DIR}/openclaw.json"

log_info() { echo -e "${GREEN}[INFO] $1${PLAIN}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${PLAIN}"; }
log_error() { echo -e "${RED}[ERROR] $1${PLAIN}"; }

install_openclaw_local() {
    log_info "安装 OpenClaw（本地用户模式）"
    mkdir -p "${HOME}/openclaw-bin"
    npm install openclaw@latest --prefix "${HOME}/openclaw-bin"
    if [ ! -f "${HOME}/openclaw-bin/bin/openclaw" ]; then
        log_error "OpenClaw 安装失败"
        exit 1
    fi
    echo 'export PATH=$HOME/openclaw-bin/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
    log_info "OpenClaw 安装完成"
}

configure_openclaw() {
    mkdir -p "${CONFIG_DIR}"

    if command -v openssl >/dev/null 2>&1; then
        GATEWAY_TOKEN=$(openssl rand -hex 16)
    else
        GATEWAY_TOKEN=$(date +%s%N | sha256sum | head -c 32)
    fi

    echo -e "${CYAN}选择 API 类型:${PLAIN}"
    echo "1. Anthropic"
    echo "2. OpenAI 兼容"
    read -p "输入选项 [1/2]: " api_choice

    read -p "Telegram Bot Token: " bot_token
    read -p "Telegram Admin ID: " admin_id

    if [ "$api_choice" == "1" ]; then
        read -p "Anthropic API Key: " api_key
        MODEL="anthropic/claude-sonnet-4-5-20261022"
        cat > "${CONFIG_FILE}" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": { "mode": "token", "token": "${GATEWAY_TOKEN}" }
  },
  "env": { "ANTHROPIC_API_KEY": "${api_key}" },
  "agents": { "defaults": { "model": { "primary": "${MODEL}" } } },
  "tools": { "allow": ["exec","process","read","write","edit","web_search","web_fetch","cron"] },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${bot_token}",
      "dmPolicy": "pairing",
      "allowFrom": ["${admin_id}"]
    }
  }
}
EOF
    else
        read -p "Base URL: " base_url
        read -p "API Key: " api_key
        read -p "模型名称: " model_name
        cat > "${CONFIG_FILE}" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": { "mode": "token", "token": "${GATEWAY_TOKEN}" }
  },
  "agents": {
    "defaults": {
      "model": { "primary": "openai-compat/${model_name}" },
      "elevatedDefault": "full"
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "openai-compat": {
        "baseUrl": "${base_url}",
        "apiKey": "${api_key}",
        "api": "openai-completions",
        "models": [{ "id": "${model_name}", "name": "${model_name}" }]
      }
    }
  },
  "tools": { "allow": ["exec","process","read","write","edit","web_search","web_fetch","cron"] },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${bot_token}",
      "dmPolicy": "pairing",
      "allowFrom": ["${admin_id}"]
    }
  }
}
EOF
    fi

    log_info "配置文件已生成: ${CONFIG_FILE}"
}

start_openclaw() {
    log_info "启动 OpenClaw（前台模式）"
    openclaw gateway --verbose
}

show_menu() {
    clear
    echo -e "${CYAN}OpenClaw 非 root 管理脚本${PLAIN}"
    echo "1. 安装 OpenClaw"
    echo "2. 配置 OpenClaw"
    echo "3. 启动 OpenClaw"
    echo "0. 退出"
    read -p "选择: " choice

    case "$choice" in
        1) install_openclaw_local ;;
        2) configure_openclaw ;;
        3) start_openclaw ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

while true; do
    show_menu
done
