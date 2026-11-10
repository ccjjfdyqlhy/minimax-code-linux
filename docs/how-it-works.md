# 原理

## 为什么需要移植

上游 <https://code.minimax.cn/about> 只发布 **macOS (.dmg)** 与 **Windows (.exe)** 安装包，
页面里的 `operatingSystem` 就是 "macOS, Windows"，CDN 上也没有任何 `latest-linux.yml`。

但那个 .exe 本质是一个 Electron 应用（`@mmx-agent/electron`），
Electron 应用 = 一份 Electron 运行时 + 一份 `resources/app.asar`。
所以只要有对应版本的 Linux 版 Electron，就能把同一份应用代码跑起来。

## 步骤

### 1. 取官方安装包（10-fetch.sh）

```
https://filecdn.minimax.chat/public/minimax-agent-prod/release/latest.yml
```

这是 electron-updater 的清单，里面给出当前版本号、安装包文件名和 sha512。
按清单下载 `MiniMax Code Setup <ver>.exe` 并校验 sha512。

### 2. 解包（20-extract.sh）

安装包是 NSIS。`7z x` 之后会得到：

```
$PLUGINSDIR/app-64.7z    ← Electron 应用载荷
$PLUGINSDIR/app-arm64.7z ← arm64 版（不需要）
$R0/Uninstall MiniMax Code.exe
```

`app-64.7z` 解开就是标准的 Electron 打包结构：

```
MiniMax Code.exe     ← win32 Electron 运行时
resources/app.asar   ← 应用代码
resources/app.asar.unpacked/
resources/resources/ ← 嵌套 resources：mcode-tools、abe-broker、pptx-core ...
```

把 `app.asar` 解到 `build/asar/` 里，后面所有补丁都改这个副本。

> **asar 头部偏移的坑**：头部是 `[0:4] payload长度 | [4:8] pickle总长 | [8:12] payload长 | [12:16] JSON长`，
> 数据区从 `16 + jsonLen` 开始。写成 `8 + readUInt32LE(12)` 是最常见的错误，
> 会让每个解出来的文件前多 8 字节垃圾 —— 表现为后续 "无效的 ELF 头"、
> `JSON.parse` 报 `Unexpected token '�'`。见 `scripts/lib/asar-read.js`。
>
> 另外官方包的头部声明了 37 个 unpacked 条目（darwin / win32-arm64 的 prebuild），
> 但 win32-x64 安装包里没有这些文件，`npx @electron/asar extract` 会 ENOENT 中断，
> 所以自己写了解包器：缺的跳过。

### 3. 拉同名 Electron 运行时（30-electron.sh）

从 `MiniMax Code.exe` 里读 UA 字符串得到 `Electron/42.11.16`、`Chrome/148.0.7778.280`，
再用 npm 装 `electron@42.11.16`，并通过二进制镜像下载 linux-x64 运行时。

**必须版本一致**：Electron 的 ABI 与原生模块强绑定（`process.versions.modules`）。

### 4. 补 Linux 原生依赖（40-natives.sh）

Windows 包按 win32 目标打包，三处东西在 Linux 上必须换掉：

| 包 | 问题 | 处理 |
|---|---|---|
| `@vscode/ripgrep` | 主进程启动即 `require.resolve('@vscode/ripgrep-linux-x64/bin/rg')`，缺了直接抛异常退出 | 单独装 `@vscode/ripgrep-linux-x64`（版本跟树内一致） |
| `better-sqlite3` | win32 的 `.node` 是 PE 格式，Linux 上 dlopen 报 "无效的 ELF 头"，本地 Runtime 起不来 | 用 `@electron/rebuild` 针对目标 Electron 重编译 |
| `node-pty` | 同上，终端功能失效 | 同上 |

还有一批 win32-only 包（`node-screenshots-win32-x64-msvc`、`@ubjs/node-win32-x64-msvc`、
`@trycua/cua-driver-win32-x64-msvc`），会尝试装对应的 `*-linux-x64*` 包，
装不上就跳过（对应能力在 Linux 上不可用，不影响主流程）。

### 5. 组装（50-assemble.sh）

**两个必须做对的地方：**

1. **可执行文件必须叫 `minimax-code`。**
   Electron 判断 `app.isPackaged` 的逻辑是
   `basename(process.execPath) !== 'electron' && !process.defaultApp`
   （见 `lib/browser/init.ts` 的 `isPackaged` 实现），另外 `resources/default_app.asar`
   存在时会走默认应用分支。名字还叫 `electron` 的话 `app.isPackaged === false`，
   应用会以为自己跑在开发模式，于是：
   - 跳过打包资源，改去准备开发用的 mcode-tools 资源 → 失败
   - `LocalRuntime` 走 dev 分支，本地文件/终端/工具链全都不可用
   
   日志特征：`Lifecycle init failed: mcode-tools: Error: mcode-tools development resource preparation failed`。

2. **`resources/resources/` 要一起带过去。**
   打包模式下 mcode-tools 的资源路径是 `join(process.resourcesPath, 'resources', 'mcode-tools')`，
   即 `resources/resources/mcode-tools`。少了它连 auth-lease-broker 都起不来。

### 6. 打包（60-package-deb.sh）

标准 FHS：应用进 `/opt/minimax-code`，`/usr/bin/minimax-code` 是启动器
（自动决定要不要加 `--no-sandbox`），`.desktop` 与图标进 `/usr/share`。

## 已知限制

- **自动更新不可用**：electron-updater 只认 exe/dmg，Linux 上拿不到 `latest-linux.yml`。
  升级要重新跑一遍本仓库。
- **部分 Windows 专属能力缺失**：屏幕截图（`node-screenshots`）、CUA 驱动、
  Windows 注册表类工具在 Linux 上没有对应实现。
- **Chromium 沙箱**：deb 的 postinst 会尝试 `chown root + chmod 4755 chrome-sandbox`；
  若失败，启动器自动降级到 `--no-sandbox`（只影响进程隔离，不影响功能）。
- **非官方构建**：上游不提供 Linux 支持，出问题请回到本仓库。
