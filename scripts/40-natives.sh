#!/usr/bin/env bash
# 补齐 Windows 包里没有的 Linux 原生依赖，并针对目标 Electron 重编译原生模块。
#
# 官方 Windows 包按 win32 目标打包，只带 win32 的 prebuild 与 optionalDependencies。
# 在 Linux 上跑必须补：
#   1. @vscode/ripgrep-linux-x64  —— 主进程启动即 require(#rgPath)，缺了直接崩
#   2. better-sqlite3 / node-pty  —— Windows 的 .node 是 PE 格式，必须重编译成 ELF
#      （否则报 "无效的 ELF 头" / "prebuild-install binary not found"）
#   3. 其它 win32-only 原生包    —— 尽力而为替换成 linux 对应包
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"
require_cmd npm node npx make g++ python3

ELECTRON_VER="$(cat "$BUILD_DIR/electron-version")"
UNPACKED="$ASAR_DIR/node_modules"   # 补丁写进解包树，打包时会一起进 asar
mkdir -p "$NATIVE_DIR"

# ---------- helper ----------
# 把 npm 包解到 asar 树里（不装依赖，纯取 prebuild 二进制）
fetch_pkg() {
  local spec="$1" dest="$2"
  local tmp; tmp="$(mktemp -d)"
  ( cd "$tmp" && npm pack --silent --registry "$NPM_REGISTRY" "$spec" >/dev/null 2>&1 ) \
    || { warn "npm pack $spec 失败，跳过"; rm -rf "$tmp"; return 1; }
  local tgz; tgz="$(ls "$tmp"/*.tgz | head -1)"
  [[ -f "$tgz" ]] || { rm -rf "$tmp"; return 1; }
  mkdir -p "$dest"
  tar xzf "$tgz" -C "$tmp"
  cp -a "$tmp/package/." "$dest/"
  rm -rf "$tmp"
}

# ---------- 1. ripgrep ----------
RG_VER="$(node -p "require('$UNPACKED/@vscode/ripgrep/package.json').version" 2>/dev/null || echo "")"
if [[ -n "$RG_VER" ]]; then
  if [[ -d "$UNPACKED/@vscode/ripgrep-linux-x64" ]]; then
    log "ripgrep-linux-x64 已在树内，跳过"
  else
    log "补 @vscode/ripgrep-linux-x64@$RG_VER"
    fetch_pkg "@vscode/ripgrep-linux-x64@$RG_VER" "$UNPACKED/@vscode/ripgrep-linux-x64" \
      || die "无法获取 ripgrep linux 二进制（主进程启动必需）"
    chmod +x "$UNPACKED/@vscode/ripgrep-linux-x64/bin/rg" 2>/dev/null || true
  fi
else
  warn "树内没有 @vscode/ripgrep，跳过"
fi

# ---------- 2. 重编译 native 模块 ----------
BS_VER="$(node -p "require('$UNPACKED/better-sqlite3/package.json').version" 2>/dev/null || echo "")"
PTY_VER="$(node -p "require('$UNPACKED/node-pty/package.json').version" 2>/dev/null || echo "")"

if [[ -n "$BS_VER" || -n "$PTY_VER" ]]; then
  log "为 Electron $ELECTRON_VER 重编译原生模块 (better-sqlite3=$BS_VER node-pty=$PTY_VER)"
  rm -rf "$NATIVE_DIR" && mkdir -p "$NATIVE_DIR"
  ( cd "$NATIVE_DIR"
    npm init -y >/dev/null 2>&1
    SPECS=()
    [[ -n "$BS_VER"  ]] && SPECS+=("better-sqlite3@$BS_VER")
    [[ -n "$PTY_VER" ]] && SPECS+=("node-pty@$PTY_VER")
    npm install --no-audit --no-fund --ignore-scripts --registry "$NPM_REGISTRY" "${SPECS[@]}" 2>&1 | tail -2
    ELECTRON_MIRROR="$ELECTRON_MIRROR/" npx --yes @electron/rebuild \
      -f -v "$ELECTRON_VER" -m . --only better-sqlite3,node-pty 2>&1 | tail -5
  )
  # 覆盖回 asar 树（打包时作为 unpacked 附件输出）
  if [[ -f "$NATIVE_DIR/node_modules/better-sqlite3/build/Release/better_sqlite3.node" ]]; then
    mkdir -p "$UNPACKED/better-sqlite3/build/Release"
    cp "$NATIVE_DIR/node_modules/better-sqlite3/build/Release/better_sqlite3.node" \
       "$UNPACKED/better-sqlite3/build/Release/better_sqlite3.node"
    log "better-sqlite3 -> ELF 已替换"
  else
    die "better-sqlite3 重编译失败"
  fi
  if [[ -f "$NATIVE_DIR/node_modules/node-pty/build/Release/pty.node" ]]; then
    mkdir -p "$UNPACKED/node-pty/build/Release" "$UNPACKED/node-pty/prebuilds/linux-x64"
    cp "$NATIVE_DIR/node_modules/node-pty/build/Release/pty.node" "$UNPACKED/node-pty/build/Release/pty.node"
    cp "$NATIVE_DIR/node_modules/node-pty/build/Release/pty.node" "$UNPACKED/node-pty/prebuilds/linux-x64/pty.node"
    for f in spawn-helper; do
      [[ -f "$NATIVE_DIR/node_modules/node-pty/build/Release/$f" ]] && \
        cp "$NATIVE_DIR/node_modules/node-pty/build/Release/$f" "$UNPACKED/node-pty/build/Release/$f"
    done
    log "node-pty -> ELF 已替换"
  else
    warn "node-pty 重编译失败（终端功能会不可用）"
  fi
else
  warn "树内没有 better-sqlite3/node-pty，跳过重编译"
fi

# ---------- 3. 其它 win32-only 原生包的 linux 对应物（尽力而为） ----------
# 这些包 Windows 版是 .node 预编译，Linux 上加载会失败；能装上 linux 版就装上。
declare -A LINUX_TWINS=(
  ["@ubjs/node-win32-x64-msvc"]="@ubjs/node-linux-x64-gnu"
  ["node-screenshots-win32-x64-msvc"]="node-screenshots-linux-x64-gnu"
)
for win in "${!LINUX_TWINS[@]}"; do
  lin="${LINUX_TWINS[$win]}"
  [[ -d "$UNPACKED/$win" ]] || continue
  winver="$(node -p "require('$UNPACKED/$win/package.json').version" 2>/dev/null || echo "")"
  [[ -n "$winver" ]] || continue
  target="$(dirname "$win")"
  base="$(basename "$lin")"
  if [[ -d "$UNPACKED/$target/$base" ]]; then
    log "$lin 已存在，跳过"
    continue
  fi
  log "尝试补 $lin@$winver"
  fetch_pkg "$lin@$winver" "$UNPACKED/$target/$base" || \
    fetch_pkg "$lin" "$UNPACKED/$target/$base" || \
    warn "  $lin 获取失败（该能力在 Linux 上不可用）"
done

log "原生依赖处理完成"
