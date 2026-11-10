'use strict';
// asar 容器读取工具。
//
// 头部布局（实测官方 Electron 42 产出的包）：
//   [0:4]   pickle payload 长度（固定 4）
//   [4:8]   头部 pickle 总长度
//   [8:12]  头部 pickle 的 payload 长度
//   [12:16] JSON 头长度  ← 这个才是 JSON 的长度
//   [16:16+jsonLen] JSON 头
//   紧接其后是文件数据区
//
// 所以：jsonLen = readUInt32LE(12)，dataOffset = 16 + jsonLen。
// 常见错误写法 `8 + readUInt32LE(12)` 会让数据区整体前移 8 字节，
// 解出来的每个文件都带 8 字节垃圾前缀 —— 表现为
// "无效的 ELF 头"、JSON 解析失败、.node 加载崩溃。
const fs = require('fs');

function openAsar(asarPath) {
  const fd = fs.openSync(asarPath, 'r');
  const sizeBuf = Buffer.alloc(16);
  fs.readSync(fd, sizeBuf, 0, 16, 0);
  const jsonLen = sizeBuf.readUInt32LE(12);
  if (!Number.isFinite(jsonLen) || jsonLen <= 0 || jsonLen > 64 * 1024 * 1024) {
    fs.closeSync(fd);
    throw new Error('不是有效的 asar 文件: ' + asarPath);
  }
  const headerBuf = Buffer.alloc(jsonLen);
  fs.readSync(fd, headerBuf, 0, jsonLen, 16);
  const header = JSON.parse(headerBuf.toString('utf8').replace(/\0+$/, ''));
  return { fd, header, dataOffset: 16 + jsonLen };
}

function readEntry(fd, dataOffset, node) {
  const size = node.size | 0;
  if (size <= 0) return Buffer.alloc(0);
  const buf = Buffer.alloc(size);
  fs.readSync(fd, buf, 0, size, dataOffset + parseInt(node.offset, 10));
  return buf;
}

module.exports = { openAsar, readEntry };
