#!/usr/bin/env bash
# 快速自检：静态检查 + 可选的无头启动验证。
source "$(dirname "${BASH_SOURCE[0]}")/00-env.sh"

APP="${1:-$BUILD_DIR/app}"
[[ -x "$APP/minimax-code" ]] || die "找不到可执行文件: $APP/minimax-code"

FAIL=0
check() { # name, condition
  if eval "$2"; then printf '  \033[1;32mOK\033[0m   %s\n' "$1"
  else printf '  \033[1;31mFAIL\033[0m %s\n' "$1"; FAIL=1; fi
}

log "静态检查 $APP"
check "可执行文件名为 minimax-code（决定 app.isPackaged）" '[[ "$(basename "$APP/minimax-code")" == "minimax-code" ]]'
check "没有残留的 electron 二进制" '[[ ! -e "$APP/electron" ]]'
check "没有 default_app.asar" '[[ ! -e "$APP/resources/default_app.asar" ]]'
check "resources/app.asar 存在" '[[ -f "$APP/resources/app.asar" ]]'
check "resources/resources/mcode-tools 存在" '[[ -d "$APP/resources/resources/mcode-tools" ]]'
check "better_sqlite3.node 是 ELF" 'file -b "$APP/resources/app.asar.unpacked/node_modules/better-sqlite3/build/Release/better_sqlite3.node" 2>/dev/null | grep -q ELF'
check "node-pty pty.node 是 ELF" 'file -b "$APP/resources/app.asar.unpacked/node_modules/node-pty/build/Release/pty.node" 2>/dev/null | grep -q ELF'
check "ripgrep linux 二进制存在" '[[ -x "$APP/resources/app.asar.unpacked/node_modules/@vscode/ripgrep-linux-x64/bin/rg" ]] || npx --yes @electron/asar list "$APP/resources/app.asar" 2>/dev/null | grep -q "ripgrep-linux-x64/bin/rg"'

if [[ "${MCODE_HEADLESS:-0}" == "1" ]]; then
  log "无头启动验证（Xvfb）"
  command -v Xvfb >/dev/null || die "需要 Xvfb: sudo apt install -y xvfb"
  TMPHOME="$(mktemp -d)"
  xvfb-run -a -s "-screen 0 1440x900x24" \
    "$APP/minimax-code" --no-sandbox --disable-dev-shm-usage \
    --user-data-dir="$TMPHOME/profile" > "$TMPHOME/out.log" 2>&1 &
  PID=$!
  sleep 25
  kill $PID 2>/dev/null || true
  if grep -q '"outcome":"ready"' "$TMPHOME/out.log"; then
    log "启动成功（Lifecycle outcome=ready）"
  else
    warn "未看到 ready 标记，日志尾部："
    tail -25 "$TMPHOME/out.log"
    FAIL=1
  fi
  if grep -q 'mcode-tools development resource preparation failed' "$TMPHOME/out.log"; then
    warn "检测到开发模式误判（app.isPackaged=false）"
    FAIL=1
  fi
  rm -rf "$TMPHOME"
fi

(( FAIL == 0 )) && log "自检通过" || die "自检失败"
