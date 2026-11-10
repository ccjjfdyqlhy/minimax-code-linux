#!/bin/sh
# MiniMax Code 启动器。
#
# 两个必要的兜底：
#   --no-sandbox  — 若 chrome-sandbox 没有 root:root + setuid 权限，Chromium 会拒绝启动。
#   --disable-dev-shm-usage — 容器/小 /dev/shm 环境里避免渲染进程崩溃。
set -e
APP=/opt/minimax-code
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$LOG_DIR" 2>/dev/null || true

ARGS="--disable-dev-shm-usage"
if [ ! -u "$APP/chrome-sandbox" ] || [ "$(stat -c %U "$APP/chrome-sandbox" 2>/dev/null)" != "root" ]; then
  ARGS="$ARGS --no-sandbox"
fi

exec "$APP/minimax-code" $ARGS "$@" >> "$LOG_DIR/minimax-code.log" 2>&1
