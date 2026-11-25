#!/usr/bin/env node
// capture.js — делает скриншот Studio через мост и сохраняет его в файл.
//
//   node tools\capture.js [имя-файла]
//
// Мост возвращает изображения в поле images (base64), а CLI их не сохраняет.
// Этот скрипт сохраняет и печатает путь.
'use strict';

const fs = require('fs');
const http = require('http');
const path = require('path');

const PORT = Number(process.env.BRIDGE_PORT || 8799);
const OUT_DIR = path.join(__dirname, '..', 'docs', 'shots');

function request(method, urlPath, body, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? null : Buffer.from(JSON.stringify(body));
    const req = http.request(
      {
        host: '127.0.0.1',
        port: PORT,
        path: urlPath,
        method,
        headers: data ? { 'Content-Type': 'application/json', 'Content-Length': data.length } : {},
      },
      (res) => {
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
      }
    );
    req.on('error', reject);
    req.setTimeout(timeoutMs, () => req.destroy(new Error('timeout')));
    if (data) req.write(data);
    req.end();
  });
}

(async () => {
  const status = await request('GET', '/status');
  const studio = (status.studios && status.studios[0]) || null;
  if (!studio) {
    console.log('Studio не подключена к мосту');
    process.exit(1);
  }

  const name = process.argv[2] || 'shot-' + Date.now();
  const response = await request('POST', '/tool', {
    name: 'screen_capture',
    arguments: { capture_id: 'ScreenCapture_2', studio_id: studio.id },
    timeoutMs: 120000,
  });

  if (response.error) {
    console.log('ошибка: ' + JSON.stringify(response.error).slice(0, 300));
    process.exit(1);
  }

  const images = response.images || [];
  if (!images.length) {
    console.log('мост не вернул изображение (text: ' + String(response.text || '').slice(0, 200) + ')');
    process.exit(1);
  }

  // Мост может вернуть либо путь к уже сохранённому файлу, либо base64.
  if (typeof images === 'string') {
    console.log(images);
    process.exit(0);
  }

  fs.mkdirSync(OUT_DIR, { recursive: true });
  let index = 0;
  for (const image of images) {
    index += 1;
    const raw = image.data || image.base64 || image.image || image;
    if (typeof raw !== 'string') {
      console.log('неизвестный формат изображения: ' + JSON.stringify(Object.keys(image)));
      continue;
    }
    // Уже сохранённый файл: мост возвращает путь.
    if (/\.(jpe?g|png)$/i.test(raw)) {
      console.log(raw);
      continue;
    }
    const buffer = Buffer.from(raw, 'base64');
    const isPng = buffer[0] === 0x89 && buffer[1] === 0x50;
    const ext = isPng ? '.png' : '.jpg';
    const file = path.join(OUT_DIR, `${name}${images.length > 1 ? '-' + index : ''}${ext}`);
    fs.writeFileSync(file, buffer);
    console.log(file + '  (' + Math.round(buffer.length / 1024) + ' КБ)');
  }
  process.exit(0);
})().catch((error) => {
  console.log('ошибка: ' + String((error && error.message) || error));
  process.exit(1);
});
