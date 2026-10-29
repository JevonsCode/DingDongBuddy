// OpenCode's server may serve desktop and terminal clients at the same time.
// Its idle event doesn't identify that surface, so report the generic source.
import { spawn } from 'node:child_process';

function notify(payload) {
  const executable = process.env.DINGDONG_MCP_EXECUTABLE ||
    (process.platform === 'darwin' ? '/Applications/DingDong.app/Contents/MacOS/dingdong-mcp' : '');
  if (!executable) return Promise.resolve();
  return new Promise((resolve) => {
    let done = false;
    const child = spawn(executable, ['--notify-stop', '--source', 'OpenCode'], { stdio: ['pipe', 'ignore', 'ignore'], windowsHide: true });
    const timer = setTimeout(() => { child.kill(); finish(); }, 2000);
    function finish() { if (!done) { done = true; clearTimeout(timer); resolve(); } }
    child.on('error', finish);
    child.on('exit', finish);
    child.stdin.on('error', () => {});
    child.stdin.end(JSON.stringify(payload));
  });
}

export const DingDongPlugin = async ({ directory, client }) => ({
  event: async ({ event }) => {
    if (event.type !== 'session.idle') return;
    const sessionId = event.properties?.sessionID;
    if (typeof sessionId !== 'string' || !sessionId) return;
    try {
      const result = await client.session.get({ path: { id: sessionId } });
      if (!result.data || result.data.id !== sessionId || result.data.parentID) return;
      await notify({ session_id: sessionId, cwd: directory });
    } catch (_) {
      // Do not notify for a session whose parent cannot be verified.
    }
  },
});
