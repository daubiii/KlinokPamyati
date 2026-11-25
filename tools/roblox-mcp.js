#!/usr/bin/env node
// roblox-mcp.js — MCP-сервер (stdio) для Claude Code в VS Code.
//
// Зачем: Roblox Studio отдаёт свои инструменты через StudioMCP.exe, но у него
// нет постоянного подключения — Studio «прилипает» к процессу только пока тот
// живёт. Этот файл:
//   1) поднимает фоновый мост (tools/studio-bridge.js), если он не запущен;
//   2) говорит с Claude Code по MCP через stdio;
//   3) проксирует tools/list и tools/call в мост по HTTP (127.0.0.1:8799),
//      подставляя studio_id автоматически.
//
// Подключение (файл .mcp.json в корне проекта):
//   { "mcpServers": { "roblox-studio": { "command": "node",
//     "args": ["C:\\...\\KlinokPamyati\\tools\\roblox-mcp.js"] } } }
//
// Зависимостей нет — только стандартная библиотека Node.
'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');

const PORT = Number(process.env.BRIDGE_PORT || 8799);
const BRIDGE = path.join(__dirname, 'studio-bridge.js');
const LOG = path.join(__dirname, 'mcp.log');
const PROTOCOL = '2024-11-05';

function log(...args) {
  const line = `[${new Date().toISOString()}] ${args.join(' ')}`;
  try {
    fs.appendFileSync(LOG, line + '\n');
  } catch (e) {
    /* лог не критичен */
  }
}

function request(method, urlPath, body, timeoutMs = 600000) {
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

async function bridgeAlive() {
  try {
    const status = await request('GET', '/status', undefined, 4000);
    return status && status.ok === true ? status : null;
  } catch (e) {
    return null;
  }
}

let bridgeChild = null;

async function ensureBridge() {
  const existing = await bridgeAlive();
  if (existing) return existing;

  log('мост не отвечает, запускаю', BRIDGE);
  bridgeChild = spawn(process.execPath, [BRIDGE], { cwd: __dirname, stdio: 'ignore', detached: true });
  bridgeChild.unref();

  for (let attempt = 1; attempt <= 30; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 700));
    const status = await bridgeAlive();
    if (status) {
      log('мост поднялся, попытка', attempt);
      return status;
    }
  }
  log('мост не поднялся за 21 с');
  return null;
}

// ===== JSON-RPC по stdio =====

function send(message) {
  process.stdout.write(JSON.stringify(message) + '\n');
}

function sendResult(id, result) {
  send({ jsonrpc: '2.0', id, result });
}

function sendError(id, code, message) {
  send({ jsonrpc: '2.0', id, error: { code, message } });
}

function textResult(text, isError = false) {
  return { content: [{ type: 'text', text: String(text) }], isError };
}

async function listTools() {
  const status = await ensureBridge();
  if (!status) {
    return {
      tools: [
        {
          name: 'bridge_status',
          description: 'Состояние моста Roblox Studio (диагностика подключения).',
          inputSchema: { type: 'object', properties: {} },
        },
      ],
    };
  }
  const response = await request('POST', '/rpc', { method: 'tools/list', params: {} }, 30000);
  const tools = (response && response.result && response.result.tools) || [];
  tools.push({
    name: 'bridge_status',
    description: 'Состояние моста: какие окна Studio подключены, сколько живёт мост.',
    inputSchema: { type: 'object', properties: {} },
  });
  return { tools };
}

async function callTool(name, args) {
  const status = await ensureBridge();
  if (!status) {
    return textResult(
      'Мост Roblox Studio не поднялся. Проверь, что Studio открыта и в Assistant включён MCP-сервер.',
      true
    );
  }

  if (name === 'bridge_status') {
    return textResult(JSON.stringify(status, null, 2));
  }

  const studios = status.studios || [];
  if (!studios.length) {
    return textResult(
      'Studio не подключена к мосту: открой нужный плейс и включи в нём MCP (Assistant → … → Manage MCP Servers).',
      true
    );
  }

  const payload = Object.assign({}, args || {});
  if (!payload.studio_id) payload.studio_id = studios[0].id;

  const response = await request('POST', '/tool', { name, arguments: payload, timeoutMs: 600000 });
  if (response && response.error) {
    const message = typeof response.error === 'string' ? response.error : JSON.stringify(response.error);
    return textResult(message, true);
  }
  if (response && response.data !== undefined) {
    return textResult(typeof response.data === 'string' ? response.data : JSON.stringify(response.data, null, 2));
  }
  if (response && response.text !== undefined) {
    return textResult(response.text, response.isError === true);
  }
  return textResult(JSON.stringify(response, null, 2));
}

async function handle(message) {
  const { id, method, params } = message;

  if (method === 'initialize') {
    sendResult(id, {
      protocolVersion: PROTOCOL,
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: 'roblox-studio-bridge', version: '1.0.0' },
    });
    return;
  }

  if (method === 'notifications/initialized' || method === 'notifications/cancelled') {
    return;
  }

  if (method === 'ping') {
    sendResult(id, {});
    return;
  }

  if (method === 'tools/list') {
    try {
      sendResult(id, await listTools());
    } catch (e) {
      sendError(id, -32603, 'tools/list: ' + String((e && e.message) || e));
    }
    return;
  }

  if (method === 'tools/call') {
    const name = params && params.name;
    const args = (params && params.arguments) || {};
    try {
      sendResult(id, await callTool(name, args));
    } catch (e) {
      sendResult(id, textResult('Ошибка вызова ' + name + ': ' + String((e && e.message) || e), true));
    }
    return;
  }

  if (id !== undefined) {
    sendError(id, -32601, 'Неизвестный метод: ' + String(method));
  }
}

let buffer = '';

process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  let index;
  while ((index = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, index).trim();
    buffer = buffer.slice(index + 1);
    if (!line) continue;
    let message;
    try {
      message = JSON.parse(line);
    } catch (e) {
      log('не разобрал строку', line.slice(0, 200));
      continue;
    }
    Promise.resolve(handle(message)).catch((e) => log('ошибка обработки', String(e && e.message)));
  }
});

process.stdin.on('end', () => {
  if (bridgeChild) {
    try {
      bridgeChild.kill();
    } catch (e) {
      /* уже закрыт */
    }
  }
  process.exit(0);
});

log('roblox-mcp запущен, порт моста', PORT);
