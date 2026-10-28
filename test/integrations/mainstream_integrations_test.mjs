import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, chmod, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { test } from 'node:test';

async function loadAsset(file) {
  const source = await readFile(resolve(file), 'utf8');
  return import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
}

test('Pi and OpenCode integrations send bounded, correctly attributed events', async () => {
  const temp = await mkdtemp(join(tmpdir(), 'dingdong-agent-test-'));
  const fake = join(temp, 'notifier');
  const capture = join(temp, 'events.jsonl');
  const previous = { ...process.env };
  try {
    await writeFile(fake, `#!/usr/bin/env node\nlet chunks=''; process.stdin.on('data', c => chunks += c); process.stdin.on('end', () => require('node:fs').appendFileSync(process.env.DINGDONG_TEST_CAPTURE, JSON.stringify({args:process.argv.slice(2), input:JSON.parse(chunks)})+'\\n'));\n`);
    await chmod(fake, 0o755);
    process.env.DINGDONG_MCP_EXECUTABLE = fake;
    process.env.DINGDONG_TEST_CAPTURE = capture;
    const pi = await loadAsset('Assets/Agent Integrations/pi.js');
    const handlers = new Map();
    pi.default({ on(name, fn) { handlers.set(name, fn); } });
    const ctx = { cwd: '/workspace', sessionManager: {
      getSessionId: () => 'a45cce14-b0be-4aea-a8f9-e88195674770',
      getSessionFile: () => '/workspace/session.jsonl',
    }};
    await handlers.get('session_start')({ reason: 'resume' }, ctx);
    await handlers.get('agent_end')({ messages: [{ role: 'assistant', content: [{ type: 'text', text: '完成 Pi 任务。' }] }] }, ctx);
    await handlers.get('agent_settled')({}, ctx);

    const opencode = await loadAsset('Assets/Agent Integrations/opencode.js');
    const plugin = await opencode.DingDongPlugin({ directory: '/workspace', client: {
      session: { get: async ({ path }) => ({ data: { id: path.id } }) },
    }});
    await plugin.event({ event: { type: 'session.idle', properties: { sessionID: 'ses_test' } } });
    const events = (await readFile(capture, 'utf8')).trim().split('\n').map(JSON.parse);
    assert.equal(events.length, 3);
    assert.deepEqual(events[0].args, ['--acknowledge-session-start', '--source', 'Pi']);
    assert.equal(events[0].input.session_id, ctx.sessionManager.getSessionId());
    assert.deepEqual(events[1].args, ['--notify-stop', '--source', 'Pi']);
    assert.equal(events[1].input.last_assistant_message, '完成 Pi 任务。');
    assert.equal(events[1].input.cwd, '/workspace');
    assert.deepEqual(events[2].args, ['--notify-stop', '--source', 'OpenCode']);
    assert.equal(events[2].input.session_id, 'ses_test');

    const subagent = await opencode.DingDongPlugin({ directory: '/workspace', client: {
      session: { get: async () => ({ data: { id: 'child', parentID: 'parent' } }) },
    }});
    await subagent.event({ event: { type: 'session.idle', properties: { sessionID: 'child' } } });
    assert.equal((await readFile(capture, 'utf8')).trim().split('\n').length, 3);
  } finally {
    process.env = previous;
    await rm(temp, { recursive: true, force: true });
  }
});
