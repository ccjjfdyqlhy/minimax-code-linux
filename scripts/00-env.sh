#!/usr/bin/env bash
# 公共变量与前置检查。所有脚本都 source 这个文件。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${MCODE_CACHE:-$REPO_ROOT/.cache}"
BUILD_DIR="$REPO_ROOT/build"
DIST_DIR="${MCODE_DIST:-$REPO_ROOT/dist}"

# 工作目录分层：
#   $WORK_WIN32   官方 Windows 安装包解出来的原始目录（只读参考）
#   $ASAR_DIR     app.asar 解包后的可修改副本（我们打补丁的地方）
#   $APP_OUT      最终组装好的 Linux 应用目录（= Electron 运行时 + resources）
WORK_WIN32="$BUILD_DIR/win32-app"
ASAR_DIR="$BUILD_DIR/asar"
APP_OUT="$BUILD_DIR/app"
NATIVE_DIR="$BUILD_DIR/native"
META_FILE="$BUILD_DIR/build-meta.json"

PKG_NAME="minimax-code"
ARCH="amd64"
RELEASE_BASE="https://filecdn.minimax.chat/public/minimax-agent-prod/release"
ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://registry.npmmirror.com/-/binary/electron}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

need() {
  local missing=()
  for c in "$@"; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
  if (( ${#missing[@]} )); then
    die "缺少依赖命令: ${missing[*]}
  Debian/Ubuntu 安装: sudo apt install -y curl p7zip-full unzip nodejs npm fakeroot dpkg-dev zstd"
  fi
}

require_cmd() { need "$@"; }

mkdir -p "$CACHE_DIR" "$BUILD_DIR" "$DIST_DIR"
