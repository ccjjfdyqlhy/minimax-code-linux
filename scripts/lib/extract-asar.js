#!/usr/bin/env node
// 把 .asar 完整解到目录，容忍"头部标记为 unpacked 但文件实际缺失"的情况。
//
// 为什么不用 `npx @electron/asar extract`：官方 Windows 载荷的 asar 头部里
// 声明了一批 unpacked 条目（node-screenshots-win32-arm64-msvc 等），
// 但 win32-x64 安装包里并没有这些文件，asar CLI 会 ENOENT 崩掉、只解出一部分。
//
// 规则：
//   - 普通条目：从 asar 数据区读
//   - unpacked 条目：从 <asar>.unpacked/ 复制；不存在则跳过并告警
'use strict';
const fs = require('fs');
const path = require('path');
const { openAsar, readEntry } = require('./asar-read');

const [asarPath, outDir] = process.argv.slice(2);
if (!asarPath || !outDir) {
  console.error('usage: extract-asar.js <app.asar> <outDir>');
  process.exit(1);
}

const { fd, header, dataOffset } = openAsar(asarPath);
const unpackedRoot = asarPath + '.unpacked';
let written = 0;
const skipped = [];

(function walk(node, rel) {
  if (node.files) {
    for (const name of Object.keys(node.files)) walk(node.files[name], rel ? rel + '/' + name : name);
    return;
  }
  if (node.link !== undefined && node.size === undefined) return;
  const dest = path.join(outDir, rel);
  fs.mkdirSync(path.dirname(dest), { recursive: true });

  if (node.unpacked) {
    const src = path.join(unpackedRoot, rel);
    if (!fs.existsSync(src)) { skipped.push(rel); return; }
    fs.copyFileSync(src, dest);
  } else {
    fs.writeFileSync(dest, readEntry(fd, dataOffset, node));
  }
  if (/\/bin\/[^/]+$/.test('/' + rel)) {
    try { fs.chmodSync(dest, 0o755); } catch {}
  }
  written++;
})(header, '');

fs.closeSync(fd);
console.log('extracted ' + written + ' file(s)');
if (skipped.length) {
  console.log('skipped ' + skipped.length + ' missing unpacked entr(ies), e.g. ' + skipped.slice(0, 2).join(', '));
}
