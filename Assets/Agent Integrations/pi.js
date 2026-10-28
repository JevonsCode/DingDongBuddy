// Optional Pi extension. It only invokes the local DingDong notifier; it does
// not change Pi settings or send a prompt to a model.
import { spawn } from 'node:child_process';

function notify(action, payload) {
  const executable = process.env.DINGDONG_MCP_EXECUTABLE ||
    (process.platform === 'darwin' ? '/Applications/DingDong.app/Contents/MacOS/dingdong-mcp' : '');
  if (!executable) return Promise.resolve();
  return new Promise((resolve) => {
    let done = false;
    const child = spawn(executable, [action, '--source', 'Pi'], { stdio: ['pipe', 'ignore', 'ignore'], windowsHide: true });
    const timer = setTimeout(() => { child.kill(); finish(); }, 2000);
    function finish() { if (!done) { done = true; clearTimeout(timer); resolve(); } }
    child.on('error', finish);
    child.on('exit', finish);
    child.stdin.on('error', () => {});
    child.stdin.end(JSON.stringify(payload));
  });
}

function session(ctx) {
  const id = ctx.sessionManager.getSessionId();
  return {
    cwd: ctx.cwd,
    ...(ctx.sessionManager.getSessionFile() && typeof id === 'string' ? { session_id: id } : {}),
  };
}

export default function (pi) {
  let pending;
  const endEvent = process.env.DINGDONG_PI_END_EVENT === 'agent_end' ? 'agent_end' : 'agent_settled';
  pi.on('session_start', async (event, ctx) => {
    const reason = event.reason || 'startup';
    if (reason === 'startup' || reason === 'resume') {
      await notify('--acknowledge-session-start', { ...session(ctx), hook_event_name: 'SessionStart', source: reason });
    }
  });
  pi.on('session_switch', async (event, ctx) => {
    if (event.reason === 'resume') {
      await notify('--acknowledge-session-start', { ...session(ctx), hook_event_name: 'SessionStart', source: 'resume' });
    }
  });
  pi.on('agent_end', async (event, ctx) => {
    const assistant = [...(event.messages || [])].reverse().find((message) => message.role === 'assistant');
    if (assistant?.stopReason === 'aborted') { pending = undefined; return; }
    const text = Array.isArray(assistant?.content)
      ? assistant.content.filter((part) => part.type === 'text').map((part) => part.text).join('\n')
      : '';
    pending = { ...session(ctx), ...(text ? { last_assistant_message: text } : {}) };
    if (endEvent === 'agent_end') { await notify('--notify-stop', pending); pending = undefined; }
  });
  if (endEvent === 'agent_settled') {
    pi.on('agent_settled', async () => {
      if (pending) { const payload = pending; pending = undefined; await notify('--notify-stop', payload); }
    });
  }
}
