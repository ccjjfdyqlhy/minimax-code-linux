#!/usr/bin/env node
// 生成 build/app-meta.json：从解包后的 package.json 与官方 exe 里读元信息。
//
// 两个坑：
//   - 官方 package.json 带 UTF-8 BOM，直接 JSON.parse 会炸
//   - Electron 版本只能从 exe 里的 UA 字符串 "Electron/x.y.z" 里扣出来
'use strict';
const fs = require('fs');
const path = require('path');

const [asarDir, exePath, outPath] = process.argv.slice(2);
if (!asarDir || !outPath) {
  console.error('usage: meta.js <asarDir> <exePath|-> <outJson>');
  process.exit(1);
}

function readJsonLoose(file) {
  const raw = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
  return JSON.parse(raw);
}

const pkg = readJsonLoose(path.join(asarDir, 'package.json'));
const meta = { name: pkg.name, version: pkg.version, electron: null, chrome: null };

if (exePath && exePath !== '-' && fs.existsSync(exePath)) {
  const buf = fs.readFileSync(exePath).toString('latin1');
  const e = buf.match(/Electron\/(\d+\.\d+\.\d+)/);
  const c = buf.match(/Chrome\/(\d+\.\d+\.\d+\.\d+)/);
  if (e) meta.electron = e[1];
  if (c) meta.chrome = c[1];
}

// 兜底：asar 里可能有 electron 版本线索
if (!meta.electron) {
  const candidates = ['dist/main/config/env.js', 'package.json'];
  for (const rel of candidates) {
    const p = path.join(asarDir, rel);
    if (!fs.existsSync(p)) continue;
    const m = fs.readFileSync(p, 'utf8').match(/electron[\"']?\s*[:=]\s*[\"']?(\d+\.\d+\.\d+)/i);
    if (m) { meta.electron = m[1]; break; }
  }
}

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, JSON.stringify(meta, null, 2) + '\n');
console.log('application:', meta.name, meta.version);
console.log('electron:', meta.electron, ' chrome:', meta.chrome);
