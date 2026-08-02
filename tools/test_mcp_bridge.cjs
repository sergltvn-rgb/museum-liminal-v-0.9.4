const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const projectPath = path.resolve(__dirname, '..');
const wrapperPath = path.join(projectPath, 'bypass-wrapper.cjs');

function request(id, method, params) {
  return JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n';
}

async function main() {
  const wrapperSource = fs.readFileSync(wrapperPath, 'utf8');
  if (!wrapperSource.includes('godot-initialize-forwarded')) {
    throw new Error('wrapper does not forward MCP initialize to the Godot child');
  }
  const child = spawn(process.execPath, [wrapperPath], {
    cwd: projectPath,
    env: { ...process.env, GWR_PROJECT_PATH: projectPath },
    stdio: ['pipe', 'pipe', 'pipe'],
    windowsHide: true,
  });
  const cleanup = () => {
    if (process.platform === 'win32') {
      spawnSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
    } else {
      child.kill('SIGTERM');
    }
  };

  const responses = new Map();
  let buffer = '';
  child.stderr.on('data', () => {});
  child.stdout.on('data', (chunk) => {
    buffer += chunk.toString();
    for (const line of buffer.split('\n').slice(0, -1)) {
      if (!line.trim()) continue;
      try {
        const message = JSON.parse(line);
        if (message.id !== undefined) responses.set(String(message.id), message);
      } catch (_) {}
    }
    buffer = buffer.slice(buffer.lastIndexOf('\n') + 1);
  });

  child.stdin.write(request(1, 'initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'bridge-test', version: '1.0' },
  }));
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} }) + '\n');
  child.stdin.write(request(2, 'tools/call', {
    name: 'get_godot_version',
    arguments: {},
  }));

  const deadline = Date.now() + 12000;
  while (Date.now() < deadline && !responses.has('2')) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  if (!responses.has('2')) {
    cleanup();
    throw new Error('Godot MCP bridge did not answer get_godot_version after initialize');
  }
  const response = responses.get('2');
  if (response.error || response.result?.isError) {
    cleanup();
    throw new Error(`Godot MCP returned an error: ${JSON.stringify(response)}`);
  }

  child.stdin.write(request(3, 'tools/call', {
    name: 'invoke_project',
    arguments: {
      projectPath,
      scene: 'res://scenes/FirstMuseumMap.tscn',
    },
  }));
  const runDeadline = Date.now() + 15000;
  while (Date.now() < runDeadline && !responses.has('3')) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  child.stdin.write(request(4, 'tools/call', { name: 'terminate_project', arguments: {} }));
  cleanup();
  if (!responses.has('3')) {
    throw new Error('Godot MCP bridge did not answer invoke_project');
  }
  const runResponse = responses.get('3');
  if (runResponse.error || runResponse.result?.isError) {
    throw new Error(`Godot invoke_project returned an error: ${JSON.stringify(runResponse)}`);
  }
  console.log('MCP bridge handshake: PASS');
}

main().catch((error) => {
  console.error(`MCP bridge handshake: FAIL - ${error.message}`);
  process.exitCode = 1;
});
