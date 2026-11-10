#!/usr/bin/env bash
# 把组装好的应用目录打成 .deb。
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
require_cmd dpkg-deb fakeroot

APP="$BUILD_DIR/app"
VERSION="$(cat "$BUILD_DIR/version")"
[[ -d "$APP" ]] || die "找不到 $APP（先跑 50-assemble.sh）"

STAGE="$BUILD_DIR/deb/$PKG_NAME"
DEB="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"

log "准备 deb 目录树"
rm -rf "$BUILD_DIR/deb"
mkdir -p "$STAGE/DEBIAN" \
         "$STAGE/opt/$PKG_NAME" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/256x256/apps" \
         "$STAGE/usr/share/doc/$PKG_NAME"

cp -a "$APP/." "$STAGE/opt/$PKG_NAME/"

# ---- 图标 ----
if [[ -f "$REPO_ROOT/overlay/icon.png" ]]; then
  cp "$REPO_ROOT/overlay/icon.png" "$STAGE/usr/share/icons/hicolor/256x256/apps/$PKG_NAME.png"
fi

# ---- .desktop ----
cp "$REPO_ROOT/overlay/debian/$PKG_NAME.desktop" "$STAGE/usr/share/applications/$PKG_NAME.desktop"

# ---- /usr/bin 启动器 ----
cp "$REPO_ROOT/overlay/debian/launcher.sh" "$STAGE/usr/bin/$PKG_NAME"
chmod 755 "$STAGE/usr/bin/$PKG_NAME"

# ---- DEBIAN/control ----
INSTALLED=$(du -sk "$STAGE/opt" | cut -f1)
sed -e "s/@VERSION@/$VERSION/" -e "s/@INSTALLED_SIZE@/$INSTALLED/" \
  "$REPO_ROOT/overlay/debian/control.in" > "$STAGE/DEBIAN/control"

install -m 755 "$REPO_ROOT/overlay/debian/postinst" "$STAGE/DEBIAN/postinst"
install -m 755 "$REPO_ROOT/overlay/debian/prerm"    "$STAGE/DEBIAN/prerm"

# ---- 文档 ----
{
  echo "MiniMax Code $VERSION — unofficial Linux build"
  echo
  echo "生成时间: $(date -Is)"
  echo "Electron: $(cat "$BUILD_DIR/electron-version" 2>/dev/null || echo '?')"
  echo "上游安装包: MiniMax Code Setup $VERSION.exe (filecdn.minimax.chat)"
  echo
  echo "这是社区移植版。上游只发布 macOS 与 Windows 安装包。"
} > "$STAGE/usr/share/doc/$PKG_NAME/BUILD-INFO.txt"

# ---- 压缩 ----
log "压缩 .deb（数百 MB，zstd，需要几分钟）"
mkdir -p "$DIST_DIR"
fakeroot dpkg-deb --root-owner-group -Zzstd --build "$STAGE" "$DEB"

log "完成: $DEB ($(du -h "$DEB" | cut -f1))"
dpkg-deb -I "$DEB" | sed -n '1,12p'
