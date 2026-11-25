#!/usr/bin/env node
// Persistent Roblox Studio bridge.
// Holds StudioMCP.exe alive on ws://localhost:13469/studio so Studio stays attached,
// and exposes a tiny HTTP API for this agent.
//
//   GET  /status                 -> {ok, studios, uptimeSec}
//   POST /tool   {name, arguments}          -> tool result payload
//   POST /rpc    {method, params}           -> raw JSON-RPC result
//   POST /shutdown
//
const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const path = require('path');

// StudioMCP.exe лежит в папке конкретной версии Roblox — ищем самую свежую,
// чтобы мост не отваливался после обновления Studio.
function resolveStudioMcp() {
  if (process.env.STUDIO_MCP_EXE) return process.env.STUDIO_MCP_EXE;
  const base = path.join(process.env.LOCALAPPDATA || '', 'Roblox', 'Versions');
  try {
    const dirs = fs.readdirSync(base)
      .map((name) => ({ name, full: path.join(base, name, 'StudioMCP.exe') }))
      .filter((entry) => fs.existsSync(entry.full))
      .map((entry) => ({ full: entry.full, mtime: fs.statSync(entry.full).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime);
    if (dirs.length) return dirs[0].full;
  } catch (e) { /* нет папки версий */ }
  return 'StudioMCP.exe';
}
const EXE = resolveStudioMcp();
const HTTP_PORT = Number(process.env.BRIDGE_PORT || 8799);
const LOG = path.join(__dirname, 'bridge.log');

const logStream = fs.createWriteStream(LOG, { flags: 'a' });
function log(...a) {
  const line = `[${new Date().toISOString()}] ${a.join(' ')}`;
  console.log(line);
  logStream.write(line + '\n');
}

// ---------- MCP child ----------
let child = null;
let buf = '';
let nextId = 1;
const pending = new Map();
const serverNotifications = [];
let startedAt = Date.now();
let childRestarts = 0;

function startChild() {
  child = spawn(EXE, ['--stdio'], { stdio: ['pipe', 'pipe', 'pipe'] });
  buf = '';
  child.stdout.setEncoding('utf8');
  child.stdout.on('data', (d) => {
    buf += d;
    let i;
    while ((i = buf.indexOf('\n')) >= 0) {
      const line = buf.slice(0, i).trim();
      buf = buf.slice(i + 1);
      if (!line) continue;
      let msg;
      try { msg = JSON.parse(line); } catch (e) { continue; }
      if (msg.id !== undefined && pending.has(msg.id)) {
        pending.get(msg.id).resolve(msg);
        pending.delete(msg.id);
      } else if (msg.method) {
        serverNotifications.push(msg);
        if (serverNotifications.length > 200) serverNotifications.shift();
        log('notification', msg.method, JSON.stringify(msg.params || {}).slice(0, 300));
      }
    }
  });
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', (d) => {
    const s = String(d).trim();
    if (s) log('mcp-stderr', s.slice(0, 500));
  });
  child.on('exit', (code, sig) => {
    log('mcp-child-exit', code, sig);
    for (const [, p] of pending) p.reject(new Error('MCP child exited'));
    pending.clear();
    if (!shuttingDown) {
      childRestarts++;
      setTimeout(() => { log('restarting MCP child'); startChild().catch(() => {}); }, 1000);
    }
  });
  return new Promise((res) => setTimeout(res, 400));
}

function rpc(method, params, timeoutMs = 180000) {
  const id = nextId++;
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => { pending.delete(id); reject(new Error('timeout: ' + method)); }, timeoutMs);
    pending.set(id, {
      resolve: (m) => { clearTimeout(t); resolve(m); },
      reject: (e) => { clearTimeout(t); reject(e); },
    });
    try {
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
    } catch (e) { clearTimeout(t); pending.delete(id); reject(e); }
  });
}

function notify(method, params) {
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method, params }) + '\n');
}

let inited = false;
async function ensureInit() {
  if (inited) return;
  const r = await rpc('initialize', {
    protocolVersion: '2025-06-18',
    capabilities: {},
    clientInfo: { name: 'dsh-bridge', version: '1.0.0' },
  });
  if (r.error) throw new Error('initialize failed: ' + JSON.stringify(r.error));
  notify('notifications/initialized', {});
  inited = true;
  log('initialized', JSON.stringify(r.result && r.result.serverInfo));
}

// ---------- helpers ----------
let imgSeq = 0;
function toolText(msg) {
  if (!msg) return { error: 'no response' };
  if (msg.error) return { error: msg.error };
  const res = msg.result || {};
  const content = res.content || [];
  const parts = content.filter((c) => c.type === 'text').map((c) => c.text);
  const text = parts.join('\n');
  const images = [];
  for (const c of content) {
    if (c.type === 'image' && c.data) {
      const dir = path.join(__dirname, 'shots');
      try {
        fs.mkdirSync(dir, { recursive: true });
        const ext = (c.mimeType || 'image/png').includes('jpeg') ? 'jpg' : 'png';
        const file = path.join(dir, `shot-${Date.now()}-${++imgSeq}.${ext}`);
        fs.writeFileSync(file, Buffer.from(c.data, 'base64'));
        images.push(file);
        log('image saved', file, fs.statSync(file).size, 'bytes');
      } catch (e) {
        log('image save failed', String(e.message || e));
      }
    }
  }
  let parsed;
  try { parsed = JSON.parse(text); } catch (e) { parsed = undefined; }
  return { isError: !!res.isError, text, data: parsed, images };
}

async function listStudios() {
  await ensureInit();
  const r = toolText(await rpc('tools/call', { name: 'list_roblox_studios', arguments: {} }));
  const arr = (r.data && r.data.studios) || [];
  return arr;
}

// ---------- HTTP API ----------
const server = http.createServer(async (req, res) => {
  const send = (code, obj) => {
    const body = JSON.stringify(obj);
    res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body) });
    res.end(body);
  };
  let body = '';
  req.on('data', (c) => { body += c; });
  req.on('end', async () => {
    try {
      if (req.method === 'GET' && req.url === '/status') {
        let studios = [];
        let err;
        try { studios = await listStudios(); } catch (e) { err = String(e.message || e); }
        return send(200, { ok: !err, studios, err, uptimeSec: Math.round((Date.now() - startedAt) / 1000), childRestarts });
      }
      if (req.method === 'POST' && req.url === '/tool') {
        const { name, arguments: args, timeoutMs } = JSON.parse(body || '{}');
        if (!name) return send(400, { error: 'name required' });
        await ensureInit();
        const msg = await rpc('tools/call', { name, arguments: args || {} }, timeoutMs || 180000);
        return send(200, toolText(msg));
      }
      if (req.method === 'POST' && req.url === '/rpc') {
        const { method, params, timeoutMs } = JSON.parse(body || '{}');
        await ensureInit();
        return send(200, await rpc(method, params || {}, timeoutMs || 120000));
      }
      if (req.method === 'POST' && req.url === '/shutdown') {
        shuttingDown = true;
        try { child.stdin.end(); child.kill(); } catch (e) {}
        send(200, { ok: true });
        setTimeout(() => process.exit(0), 200);
        return;
      }
      send(404, { error: 'not found', paths: ['GET /status', 'POST /tool', 'POST /rpc', 'POST /shutdown'] });
    } catch (e) {
      send(500, { error: String((e && e.message) || e) });
    }
  });
});

let shuttingDown = false;
process.on('SIGINT', () => { shuttingDown = true; try { child.kill(); } catch (e) {} process.exit(0); });
process.on('SIGTERM', () => { shuttingDown = true; try { child.kill(); } catch (e) {} process.exit(0); });

(async () => {
  log('bridge starting; spawning StudioMCP.exe');
  await startChild();
  server.listen(HTTP_PORT, '127.0.0.1', () => log('bridge HTTP listening on http://127.0.0.1:' + HTTP_PORT));
  await ensureInit().catch((e) => log('init error', String(e.message || e)));
  // wait for Studio to attach
  for (let i = 0; i < 24; i++) {
    const s = await listStudios().catch(() => []);
    if (s.length) { log('studio attached:', JSON.stringify(s)); break; }
    await new Promise((r) => setTimeout(r, 2500));
  }
})();
