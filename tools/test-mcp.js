// test-mcp.js — проверка MCP-сервера tools/roblox-mcp.js без Claude:
// запускает его как Claude Code (stdio), шлёт initialize / tools/list / tools/call.
'use strict';
const { spawn } = require('child_process');
const path = require('path');

const SERVER = path.join(__dirname, 'roblox-mcp.js');
const child = spawn(process.execPath, [SERVER], { stdio: ['pipe', 'pipe', 'pipe'] });

let out = '';
child.stdout.setEncoding('utf8');
child.stdout.on('data', (chunk) => {
  out += chunk;
  let index;
  while ((index = out.indexOf('\n')) >= 0) {
    const line = out.slice(0, index).trim();
    out = out.slice(index + 1);
    if (!line) continue;
    let message;
    try {
      message = JSON.parse(line);
    } catch (e) {
      console.log('НЕ JSON:', line.slice(0, 200));
      continue;
    }
    if (message.id === 1) {
      console.log('initialize ->', JSON.stringify(message.result && message.result.serverInfo));
    } else if (message.id === 2) {
      const tools = (message.result && message.result.tools) || [];
      console.log('tools/list ->', tools.length, 'инструментов:', tools.slice(0, 12).map((t) => t.name).join(', '));
      child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'bridge_status', arguments: {} } }) + '\n');
    } else if (message.id === 3) {
      const text = (message.result && message.result.content && message.result.content[0] && message.result.content[0].text) || '';
      console.log('tools/call bridge_status ->', text.slice(0, 300).replace(/\n/g, ' '));
      child.stdin.end();
      setTimeout(() => child.kill(), 300);
    }
  }
});

child.stderr.setEncoding('utf8');
child.stderr.on('data', (chunk) => console.log('stderr:', String(chunk).slice(0, 300)));

child.stdin.write(JSON.stringify({
  jsonrpc: '2.0',
  id: 1,
  method: 'initialize',
  params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'test', version: '1.0.0' } },
}) + '\n');

setTimeout(() => {
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} }) + '\n');
}, 1500);

setTimeout(() => {
  console.log('таймаут проверки');
  child.kill();
  process.exit(1);
}, 30000);
