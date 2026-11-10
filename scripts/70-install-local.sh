#!/usr/bin/env bash
# 不生成 .deb，直接把组装好的应用装到 ~/.local（无需 root）。
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"

APP="$BUILD_DIR/app"
VERSION="$(cat "$BUILD_DIR/version")"
DEST="${MCODE_HOME:-$HOME/.local/share/minimax-code}"
[[ -d "$APP" ]] || die "找不到 $APP（先跑 50-assemble.sh）"

log "安装到 $DEST"
rm -rf "$DEST/app"
mkdir -p "$DEST"
cp -a "$APP" "$DEST/app"
cp "$REPO_ROOT/overlay/icon.png" "$DEST/icon.png" 2>/dev/null || true
chmod 644 "$DEST/icon.png" 2>/dev/null || true

log "写入启动器 ~/.local/bin/minimax-code"
mkdir -p "$HOME/.local/bin"
sed "s#/opt/minimax-code#$DEST/app#g" "$REPO_ROOT/overlay/debian/launcher.sh" > "$HOME/.local/bin/minimax-code"
chmod 755 "$HOME/.local/bin/minimax-code"

log "写入桌面项"
mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"
sed "s#Exec=/opt/minimax-code/minimax-code#Exec=$DEST/app/minimax-code#" \
  "$REPO_ROOT/overlay/debian/minimax-code.desktop" \
  > "$HOME/.local/share/applications/minimax-code.desktop"
chmod 755 "$HOME/.local/share/applications/minimax-code.desktop"
cp "$REPO_ROOT/overlay/icon.png" "$HOME/.local/share/icons/hicolor/256x256/apps/minimax-code.png" 2>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

printf '%s\n' "$VERSION" > "$DEST/version"
log "完成。运行: minimax-code   或从应用菜单打开 MiniMax Code"
log "数据目录: $HOME/.config/MiniMax    日志: $HOME/.cache/minimax-code.log"
