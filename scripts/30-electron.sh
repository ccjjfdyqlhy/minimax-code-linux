#!/usr/bin/env bash
# 获取与官方 Windows 包完全同版本的 Linux Electron 运行时。
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
require_cmd npm node

ELECTRON_VER="$(node -p "require('$BUILD_DIR/app-meta.json').electron || ''")"
[[ -n "$ELECTRON_VER" ]] || die "无法从安装包中识别 Electron 版本"

RUNTIME_DIR="$BUILD_DIR/electron-runtime"
if [[ -x "$RUNTIME_DIR/node_modules/electron/dist/electron" ]] \
   && [[ "$(cat "$RUNTIME_DIR/node_modules/electron/dist/version" 2>/dev/null)" == "$ELECTRON_VER" ]]; then
  log "Electron $ELECTRON_VER 运行时已存在"
else
  log "安装 Electron $ELECTRON_VER (linux-x64) ..."
  rm -rf "$RUNTIME_DIR" && mkdir -p "$RUNTIME_DIR"
  ( cd "$RUNTIME_DIR"
    npm init -y >/dev/null 2>&1
    npm install --no-audit --no-fund --registry "$NPM_REGISTRY" "electron@$ELECTRON_VER" 2>&1 | tail -3
    # npm 只装了包装器，二进制要单独拉；用 npmmirror 的二进制镜像
    if [[ ! -x node_modules/electron/dist/electron ]]; then
      ELECTRON_MIRROR="$ELECTRON_MIRROR/" node node_modules/electron/install.js
    fi
  )
fi

[[ -x "$RUNTIME_DIR/node_modules/electron/dist/electron" ]] || die "Electron 运行时安装失败"
log "Electron 运行时: $("$RUNTIME_DIR/node_modules/electron/dist/electron" --version 2>/dev/null || echo "$ELECTRON_VER")"
printf '%s\n' "$ELECTRON_VER" > "$BUILD_DIR/electron-version"
