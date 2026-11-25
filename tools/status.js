#!/usr/bin/env node
// status.js — состояние связки: поднимает мост, если он не запущен,
// и печатает, какие окна Studio подключены.
//
//   node tools/status.js
//
// Код выхода: 0 — Studio подключена, 1 — нет.
'use strict';

const { spawn } = require('child_process');
const http = require('http');
const path = require('path');

const PORT = Number(process.env.BRIDGE_PORT || 8799);
const BRIDGE = path.join(__dirname, 'studio-bridge.js');

function get(pathname) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: '127.0.0.1', port: PORT, path: pathname, method: 'GET' }, (res) => {
      let out = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        out += chunk;
      });
      res.on('end', () => {
        try {
          resolve(JSON.parse(out));
        } catch (e) {
          resolve({ raw: out });
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(4000, () => req.destroy(new Error('timeout')));
    req.end();
  });
}

async function main() {
  let status = null;
  try {
    status = await get('/status');
  } catch (e) {
    status = null;
  }

  if (!status) {
    console.log('мост не запущен — поднимаю');
    const child = spawn(process.execPath, [BRIDGE], { cwd: __dirname, stdio: 'ignore', detached: true });
    child.unref();
    for (let attempt = 1; attempt <= 25; attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 700));
      try {
        status = await get('/status');
        if (status) break;
      } catch (e) {
        /* ждём дальше */
      }
    }
  }

  if (!status || !status.ok) {
    console.log('МОСТ НЕ ОТВЕЧАЕТ — смотри tools/bridge.log');
    process.exit(1);
  }

  const studios = status.studios || [];
  console.log('мост: ok, живёт ' + Math.round(status.uptimeSec) + ' с');
  if (!studios.length) {
    console.log('STUDIO НЕ ПОДКЛЮЧЕНА — открой плейс и включи MCP в Assistant');
    process.exit(1);
  }
  for (const studio of studios) {
    console.log('Studio: ' + studio.name + ' (' + studio.id + ')');
  }
  process.exit(0);
}

main().catch((error) => {
  console.log('ошибка: ' + String((error && error.message) || error));
  process.exit(1);
});
