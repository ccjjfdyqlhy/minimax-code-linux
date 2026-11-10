#!/usr/bin/env bash
# 解析官方 release 通道的最新版本，下载 Windows 安装包并校验 sha512。
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
require_cmd curl

PIN_VERSION="${MCODE_VERSION:-}"

log "读取官方 release 通道: $RELEASE_BASE/latest.yml"
LATEST_YML="$CACHE_DIR/latest.yml"
curl -fsSL --retry 3 -o "$LATEST_YML" "$RELEASE_BASE/latest.yml" \
  || die "无法读取 latest.yml"

YML_VERSION="$(sed -n 's/^version: *//p' "$LATEST_YML" | head -1)"
EXE_NAME="$(sed -n 's/^ *- *url: *//p' "$LATEST_YML" | head -1)"
EXE_SHA512="$(sed -n 's/^ *sha512: *//p' "$LATEST_YML" | head -1)"

[[ -n "$YML_VERSION" ]] || die "latest.yml 里没有 version"
[[ -n "$EXE_NAME"   ]] || die "latest.yml 里没有安装包文件名"

VERSION="${PIN_VERSION:-$YML_VERSION}"
if [[ -n "$PIN_VERSION" && "$PIN_VERSION" != "$YML_VERSION" ]]; then
  warn "指定版本 $PIN_VERSION 与官方最新 $YML_VERSION 不同，尝试按指定版本构造下载地址"
  EXE_NAME="MiniMax Code Setup $PIN_VERSION.exe"
  EXE_SHA512=""
fi

log "目标版本: $VERSION"
log "安装包: $EXE_NAME"

EXE_CACHE="$CACHE_DIR/$EXE_NAME"
if [[ -f "$EXE_CACHE" ]]; then
  log "使用缓存: $EXE_CACHE"
else
  log "下载安装包（约 570 MB）..."
  curl -fL --retry 3 -C - -o "$EXE_CACHE" "$RELEASE_BASE/$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$EXE_NAME")" \
    || die "下载失败"
fi

if [[ -n "$EXE_SHA512" ]]; then
  log "校验 sha512 ..."
  ACTUAL="$(openssl dgst -sha512 -binary "$EXE_CACHE" | openssl base64 -A)"
  if [[ "$ACTUAL" == "$EXE_SHA512" ]]; then
    log "sha512 匹配"
  else
    die "sha512 不匹配
  期望: $EXE_SHA512
  实际: $ACTUAL"
  fi
else
  warn "无官方 sha512，跳过校验（--version 指定版本时）"
fi

printf '%s\n' "$VERSION" > "$BUILD_DIR/version"
log "版本已记录到 $BUILD_DIR/version"
