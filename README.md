# minimax-code-linux

把 **MiniMax Code** 官方桌面端（只有 macOS / Windows 版本）移植到 Linux 的构建脚本。

从官方 Windows 安装包自动提取 Electron 应用载荷，配上同版本 Linux Electron 运行时，
补齐并重编译原生模块，产出可安装的 **.deb** 或直接装到 `~/.local`。

> 上游 <https://code.minimax.cn/about> 不发布 Linux 版本，这是社区非官方构建。

## 快速开始

```bash
# 依赖（Debian/Ubuntu）
sudo apt install -y curl p7zip-full nodejs npm fakeroot dpkg-dev zstd \
                    build-essential python3 openssl

git clone <this-repo> ~/minimax-code-linux
cd ~/minimax-code-linux

# 构建 .deb（自动取官方最新版）
./build.sh

# 构建并直接安装到 ~/.local（不需要 root）
./build.sh --install

# 指定版本
./build.sh --version 3.1.13

# 只组装应用目录，不打包
./build.sh --no-deb

# 构建 + 自检（加 MCODE_HEADLESS=1 会真的无头启动一次）
MCODE_HEADLESS=1 ./build.sh --verify
```

产物：`dist/minimax-code_<version>_amd64.deb`

## 目录结构

```
build.sh                     一键流水线
scripts/
  00-env.sh                  公共变量、依赖检查
  10-fetch.sh                读 latest.yml、下载官方 exe、校验 sha512
  20-extract.sh              解 NSIS -> app-64.7z -> app.asar -> build/asar/
  30-electron.sh             拉同版本 Linux Electron 运行时
  40-natives.sh              补 ripgrep-linux、重编译 better-sqlite3 / node-pty
  50-assemble.sh             打补丁 + 重打包 asar + 组装 app 目录
  60-package-deb.sh          生成 .deb
  70-install-local.sh        装到 ~/.local（免 root）
  90-verify.sh               静态检查 + 可选无头启动验证
  lib/asar-read.js           asar 容器读取（含头部偏移说明）
  lib/extract-asar.js        容错解包器
  lib/meta.js                读版本 / Electron 版本
patches/                     额外补丁（按文件名顺序在打包前执行）
overlay/
  icon.png                   图标
  debian/                     control.in、.desktop、启动器、postinst、prerm
docs/how-it-works.md         原理与踩过的坑
```

## 安装产物

```bash
sudo apt install ./dist/minimax-code_3.1.13_amd64.deb
minimax-code            # 或从应用菜单打开 "MiniMax Code"
```

- 程序：`/opt/minimax-code`
- 启动器：`/usr/bin/minimax-code`（自动处理 `--no-sandbox` / `--disable-dev-shm-usage`）
- 数据：`~/.config/MiniMax`
- 日志：`~/.cache/minimax-code.log`

卸载：

```bash
sudo apt remove minimax-code
rm -rf ~/.config/MiniMax ~/.cache/minimax-code.log
```

## 环境变量

| 变量 | 作用 | 默认 |
|---|---|---|
| `MCODE_VERSION` | 指定版本 | 官方 latest.yml |
| `MCODE_CACHE` | 缓存目录（安装包） | `./.cache` |
| `MCODE_DIST` | 产物目录 | `./dist` |
| `NPM_REGISTRY` | npm 源 | npmmirror |
| `ELECTRON_MIRROR` | Electron 二进制镜像 | npmmirror |
| `MCODE_HEADLESS` | 设为 1 时 verify 会真的无头启动 | 0 |

## 官方更新了怎么办

直接重跑 `./build.sh`。脚本每次都会重新读 `latest.yml`，只有版本变了才会重新下载。

如果新版本引入了 Linux 特有的问题，在 `patches/` 里加一个 `NNN-xxx.sh`，
见 [patches/README.md](patches/README.md)。

## 原理与坑

详细说明见 [docs/how-it-works.md](docs/how-it-works.md)，包括：

- asar 头部的 8 字节偏移陷阱
- 为什么可执行文件必须叫 `minimax-code`（`app.isPackaged` 判定）
- 为什么必须带 `resources/resources/` 这一层嵌套目录
- 三个必须换掉的 win32 原生依赖

## 许可与声明

本仓库只包含构建脚本，不包含任何 MiniMax 的代码或二进制。
构建所需的安装包与 npm 依赖均从官方源下载，版权归各自所有者。
这是非官方项目，与 MiniMax 无关。
