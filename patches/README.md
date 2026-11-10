# patches/

`50-assemble.sh` 在重打包 asar 之前，会按文件名顺序执行本目录下所有 `*.sh`。

每个补丁都在 `set -e` 子 shell 里运行，可以修改 `$ASAR_DIR`（解包后的应用树），
也可以往 `$APP_OUT` 里塞文件。可用变量：

- `$ASAR_DIR`  解包后的 app.asar 目录（改这里 = 改应用逻辑）
- `$APP_OUT`   最终应用目录（Electron 运行时 + resources）
- `$WIN_APP`   官方 Windows 载荷解包目录（只读参考）
- `$BUILD_DIR` 构建工作区

## 什么时候需要写补丁

官方升级后如果出现 Linux 上特有的问题（平台判断写死、Windows 专属 API、
原生依赖缺失等），在这里加一个 `NNN-描述.sh` 即可，不用改主流程。

## 示例

```bash
# 10-disable-windows-only-feature.sh
FILE="$ASAR_DIR/dist/main/modules/foo/index.js"
if [[ -f "$FILE" ]]; then
  sed -i 's/process.platform === "win32" ? enable() : disable()/disable()/' "$FILE"
fi
```

注意：改 `dist/` 下的文件是改编译产物，官方换版本后可能失效，
所以每个补丁都应该自带「找不到目标就跳过」的判断，而不是硬失败。
