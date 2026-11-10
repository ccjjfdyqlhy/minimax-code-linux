#!/usr/bin/env bash
# 一键构建：官方 Windows 安装包 -> Linux .deb
#
#   ./build.sh                    自动取官方最新版
#   ./build.sh --version 3.1.13   指定版本
#   ./build.sh --install          打完直接装到 ~/.local（无需 root）
#   ./build.sh --no-deb           只组装应用目录，不打包
#   ./build.sh --verify           构建后跑自检（静态检查；加 MCODE_HEADLESS=1 做无头启动）
#
# 环境变量：
#   MCODE_CACHE   缓存目录（默认 ./.cache，安装包与 npm 缓存都在这里）
#   MCODE_DIST    产物目录（默认 ./dist）
#   NPM_REGISTRY  npm 源（默认 npmmirror）
#   ELECTRON_MIRROR  Electron 二进制镜像
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/00-env.sh
source "$HERE/scripts/00-env.sh"

DO_INSTALL=0
DO_DEB=1
DO_VERIFY=0
while (( $# )); do
  case "$1" in
    --version) MCODE_VERSION="${2:?}"; export MCODE_VERSION; shift 2 ;;
    --install) DO_INSTALL=1; shift ;;
    --no-deb)  DO_DEB=0; shift ;;
    --verify)  DO_VERIFY=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
done

START=$(date +%s)

bash "$HERE/scripts/10-fetch.sh"
bash "$HERE/scripts/20-extract.sh"
bash "$HERE/scripts/30-electron.sh"
bash "$HERE/scripts/40-natives.sh"
bash "$HERE/scripts/50-assemble.sh"

if (( DO_VERIFY )); then bash "$HERE/scripts/90-verify.sh"; fi

if (( DO_DEB )); then
  bash "$HERE/scripts/60-package-deb.sh"
fi

if (( DO_INSTALL )); then
  bash "$HERE/scripts/70-install-local.sh"
fi

log "全部完成，用时 $(( ($(date +%s) - START) / 60 )) 分 $(( ($(date +%s) - START) % 60 )) 秒"
if (( DO_DEB )); then log "产物: $DIST_DIR/${PKG_NAME}_$(cat "$BUILD_DIR/version")_${ARCH}.deb"; fi
