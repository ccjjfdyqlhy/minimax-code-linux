#!/usr/bin/env bash
# 解包官方 Windows 安装包（NSIS），取出 Electron 应用载荷。
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
require_cmd 7z node

VERSION="$(cat "$BUILD_DIR/version")"
EXE_CACHE="$CACHE_DIR/MiniMax Code Setup $VERSION.exe"
[[ -f "$EXE_CACHE" ]] || die "找不到安装包: $EXE_CACHE（先跑 10-fetch.sh）"

log "[1/3] 解开 NSIS 外壳 -> $WORK_WIN32"
rm -rf "$WORK_WIN32" && mkdir -p "$WORK_WIN32"
7z x -y -o"$WORK_WIN32" "$EXE_CACHE" >/dev/null 2>&1 || true

APP_7Z="$WORK_WIN32/\$PLUGINSDIR/app-64.7z"
[[ -f "$APP_7Z" ]] || die "安装包里没有 app-64.7z —— 官方可能换了打包方式（见 docs/how-it-works.md）"

log "[2/3] 解开 Electron 载荷 (app-64.7z)"
rm -rf "$WORK_WIN32/app" && mkdir -p "$WORK_WIN32/app"
7z x -y -o"$WORK_WIN32/app" "$APP_7Z" >/dev/null

[[ -f "$WORK_WIN32/app/resources/app.asar" ]] || die "载荷里没有 resources/app.asar"

log "[3/3] 解包 app.asar -> $ASAR_DIR"
rm -rf "$ASAR_DIR"
node "$REPO_ROOT/scripts/lib/extract-asar.js" "$WORK_WIN32/app/resources/app.asar" "$ASAR_DIR"

log "读取版本元信息"
node "$REPO_ROOT/scripts/lib/meta.js" "$ASAR_DIR" "$WORK_WIN32/app/MiniMax Code.exe" "$BUILD_DIR/app-meta.json"

ELECTRON_VER="$(node -p "require('$BUILD_DIR/app-meta.json').electron || ''")"
[[ -n "$ELECTRON_VER" ]] || die "无法从安装包中识别 Electron 版本（见 docs/how-it-works.md）"
log "目标 Electron: $ELECTRON_VER"
