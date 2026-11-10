#!/usr/bin/env bash
# 组装最终的 Linux 应用目录：Electron 运行时 + 重打包的 app.asar + resources。
#
# 两个关键点，缺一个应用就起不来或者功能残缺：
#
#   1. 可执行文件必须叫 minimax-code（不能叫 electron）。
#      Electron 只有在 basename(execPath) != "electron"、且没有 defaultApp 时，
#      才认为 app.isPackaged === true。若被判定成开发模式，应用会跳过本地
#      Runtime 初始化，日志里出现
#      "mcode-tools development resource preparation failed"，登录后功能残缺。
#
#   2. resources/resources/ 这个"嵌套 resources"目录必须一起带过去。
#      打包模式下 mcode-tools 的资源路径是 resourcesPath + "/resources/mcode-tools"。
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
require_cmd node

VERSION="$(cat "$BUILD_DIR/version")"
RUNTIME_DIR="$BUILD_DIR/electron-runtime/node_modules/electron/dist"
WIN_APP="$WORK_WIN32/app"
[[ -d "$RUNTIME_DIR" ]] || die "找不到 Electron 运行时（先跑 30-electron.sh）"
[[ -d "$ASAR_DIR" ]]     || die "找不到解包后的 asar（先跑 20-extract.sh）"

# ---------- 1. 打补丁 ----------
shopt -s nullglob
for p in "$REPO_ROOT"/patches/*.sh; do
  log "应用补丁 $(basename "$p")"
  ( source "$p" )
done
shopt -u nullglob

# ---------- 2. 重新打包 asar ----------
# 原生模块 .node 必须 unpacked（asar 里的 .node 需要运行时解压到临时目录，
# 且 better-sqlite3 这类会因 dlopen 路径问题失败）。
log "重新打包 app.asar（Linux 原生模块 included）"
NEW_ASAR="$BUILD_DIR/app.asar"
rm -f "$NEW_ASAR"
rm -rf "$NEW_ASAR.unpacked"
npx --yes @electron/asar pack "$ASAR_DIR" "$NEW_ASAR" \
  --unpack "**/*.node" --unpack-dir "**/prebuilds" 2>&1 | tail -3
[[ -f "$NEW_ASAR" ]] || die "asar 打包失败"
log "app.asar: $(du -h "$NEW_ASAR" | cut -f1)，unpacked: $(du -sh "$NEW_ASAR.unpacked" 2>/dev/null | cut -f1 || echo '无')"

# ---------- 3. 组装 app 目录 ----------
log "组装 $APP_OUT"
rm -rf "$APP_OUT"
mkdir -p "$APP_OUT"
cp -a "$RUNTIME_DIR/." "$APP_OUT/"

# 关键点 1
mv "$APP_OUT/electron" "$APP_OUT/minimax-code"
rm -f "$APP_OUT/resources/default_app.asar"

# 我们的 asar
rm -f "$APP_OUT/resources/app.asar"
cp "$NEW_ASAR" "$APP_OUT/resources/app.asar"
if [[ -d "$NEW_ASAR.unpacked" ]]; then
  rm -rf "$APP_OUT/resources/app.asar.unpacked"
  cp -a "$NEW_ASAR.unpacked" "$APP_OUT/resources/app.asar.unpacked"
fi

# 关键点 2
if [[ -d "$WIN_APP/resources/resources" ]]; then
  rm -rf "$APP_OUT/resources/resources"
  cp -a "$WIN_APP/resources/resources" "$APP_OUT/resources/resources"
else
  warn "官方载荷里没有 resources/resources/，mcode-tools 集成将不可用"
fi

# 自动更新器初始化需要这个文件（Linux 上实际不会用来自更新）
[[ -f "$WIN_APP/resources/app-update.yml" ]] && \
  cp "$WIN_APP/resources/app-update.yml" "$APP_OUT/resources/app-update.yml"

chmod +x "$APP_OUT/minimax-code" "$APP_OUT/chrome_crashpad_handler" 2>/dev/null || true

log "应用目录就绪: $(du -sh "$APP_OUT" | cut -f1)"
