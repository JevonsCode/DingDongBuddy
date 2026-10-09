import { bytesToBase64, base64UrlDecode } from './app-codecs.js?shell=45';
import { openTransferSink, relayFileLimit } from './file-transfer-storage.js?shell=45';
const chunkBytes = 32768;
const terminal = (view) => ['completed', 'cancelled'].includes(view.status);
const digest = async (bytes) => [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
  .map((byte) => byte.toString(16).padStart(2, '0')).join('');
const fingerprintOf = (file) => `${file.size}:${file.lastModified || 0}`;

export function createResumableTransfers({ peer, send, isLan, onChange, onReceived,
  openSink = openTransferSink, acceptOffer = () => true, replyTimeoutMs = 20000 }) {
  const outgoing = new Map(), incoming = new Map(), views = new Map(), replies = new Map();
  let disposed = false, sequence = 0;
  const operations = new Map();
  async function serial(id, operation) {
    const next = (operations.get(id) || Promise.resolve()).catch(() => {}).then(operation);
    operations.set(id, next);
    try { return await next; } finally { if (operations.get(id) === next) operations.delete(id); }
  }
  const changed = () => {
    if (disposed) return;
    const finished = [...views.values()].filter(terminal);
    for (const view of finished.slice(0, Math.max(0, finished.length - 20))) {
      views.delete(view.id); outgoing.delete(view.id); incoming.delete(view.id);
    }
    onChange();
  };
  function advance(view, bytes) {
    const now = Date.now(), elapsed = now - view.sampleAt;
    if (bytes < view.bytes) view.bytesPerSecond = 0;
    if (elapsed >= 400) {
      const speed = Math.max(0, bytes - view.sampleBytes) * 1000 / elapsed;
      view.bytesPerSecond = view.bytesPerSecond ? view.bytesPerSecond * .65 + speed * .35 : speed;
      view.sampleAt = now; view.sampleBytes = bytes;
    }
    view.bytes = bytes;
  }
  function viewFor(id, name, size, sending, itemId) {
    return { id, name, size, sending, itemId, status: 'preparing', detail: '', bytes: 0,
      lan: false, bytesPerSecond: 0, sampleAt: Date.now(), sampleBytes: 0 };
  }
  async function request(view, message) {
    const requestId = `${Date.now()}-${++sequence}`;
    const key = `${view.id}:${requestId}`;
    let timer;
    const promise = new Promise((resolve, reject) => {
      replies.set(key, { resolve, reject });
      timer = setTimeout(() => reject(new Error('connection_lost')), replyTimeoutMs);
    });
    promise.catch(() => {});
    try {
      await send({ ...message, id: view.id, request: requestId, lanOnly: view.size > relayFileLimit });
      const response = await promise;
      if (response.error) throw new Error(response.error);
      return response;
    } finally { clearTimeout(timer); replies.delete(key); }
  }
  async function sendFile(file, { itemId } = {}) {
    if (disposed) throw new Error('closed');
    const fingerprint = fingerprintOf(file);
    const existing = [...outgoing.values()].find((item) => item.file.name === file.name && item.fingerprint === fingerprint && !terminal(item.view));
    const id = crypto.randomUUID();
    if (existing && !terminal(existing.view)) { await run(existing, true); return existing.view; }
    if ([...outgoing.values()].filter((item) => !terminal(item.view)).length >= 3) throw new Error('too_many_transfers');
    const view = viewFor(id, file.name, file.size, true, itemId);
    const item = { view, file, fingerprint, stopped: false, running: false };
    outgoing.set(id, item); views.set(id, view); changed();
    await run(item, true);
    return view;
  }
  async function run(item, explicitResume = false) {
    if (disposed || item.running || terminal(item.view)) return;
    item.running = true; item.stopped = false;
    const view = item.view;
    try {
      view.status = 'preparing'; view.detail = ''; view.bytesPerSecond = 0; changed();
      view.lan = await isLan();
      if (view.size > relayFileLimit && !view.lan) throw new Error('waiting_lan');
      if (fingerprintOf(item.file) !== item.fingerprint) throw new Error('source_changed');
      const ready = await request(view, { type: 'transfer.offer', name: view.name,
        size: view.size, fingerprint: item.fingerprint, itemId: view.itemId, resume: explicitResume });
      if (!Number.isSafeInteger(ready.offset) || ready.offset < 0 || ready.offset > view.size ||
        (ready.offset !== view.size && ready.offset % chunkBytes !== 0)) throw new Error('invalid_offset');
      if (item.stopped) return;
      advance(view, ready.offset); view.status = 'transferring'; changed();
      while (view.bytes < view.size) {
        if (item.stopped || disposed) return;
        const bytes = new Uint8Array(await item.file.slice(view.bytes, view.bytes + chunkBytes).arrayBuffer());
        if (!bytes.length) throw new Error('source_changed');
        const next = view.bytes + bytes.length;
        const ack = await request(view, { type: 'transfer.chunk', offset: view.bytes,
          data: bytesToBase64(bytes), digest: await digest(bytes) });
        if (item.stopped || disposed) return;
        if (ack.offset !== next) throw new Error('invalid_offset');
        advance(view, next); changed();
      }
      if (item.stopped || disposed) return;
      view.status = 'verifying'; changed();
      const done = await request(view, { type: 'transfer.finish' });
      if (item.stopped || disposed) return;
      if (!done.done) throw new Error('incomplete');
      view.status = 'completed'; view.bytesPerSecond = 0;
    } catch (error) {
      if (!item.stopped && !disposed) {
        const known = ['waiting_lan', 'paused', 'source_changed', 'invalid_offset', 'incomplete',
          'checksum_failed', 'storage_error', 'storage_unsupported', 'too_many_transfers', 'cancelled', 'restart_required'];
        const code = known.includes(error.message) ? error.message : 'connection_lost';
        view.status = ['waiting_lan', 'connection_lost'].includes(code) ? 'waiting' : code === 'paused' ? 'paused' : 'failed';
        view.detail = code; view.bytesPerSecond = 0;
      }
    } finally { item.running = false; changed(); }
  }
  const reply = (message, fields) => send({ type: 'transfer.reply', id: message.id, request: message.request, ...fields });
  async function handle(message) {
    if (disposed || typeof message.id !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(message.id)) return;
    if (message.type === 'transfer.reply') {
      replies.get(`${message.id}:${message.request}`)?.resolve(message); return;
    }
    if (message.type === 'transfer.control') { await control(message.id, message.action, true); return; }
    if (typeof message.request !== 'string' || message.request.length > 128) return;
    await serial(message.id, async () => {
    try {
      if (message.type === 'transfer.offer') await offer(message);
      else if (message.type === 'transfer.chunk') await chunk(message);
      else if (message.type === 'transfer.finish') await finish(message);
    } catch (error) {
      const code = ['waiting_lan', 'paused', 'invalid_metadata', 'source_changed', 'invalid_chunk',
        'checksum_failed', 'invalid_offset', 'incomplete', 'restart_required', 'too_many_transfers',
        'storage_unsupported', 'cancelled'].includes(error.message) ? error.message : 'storage_error';
      const view = views.get(message.id);
      if (view && !terminal(view)) {
        view.status = code === 'waiting_lan' ? 'waiting' : code === 'paused' ? 'paused' : 'failed';
        view.detail = code; changed();
      }
      await reply(message, { error: code }).catch(() => {});
    }
    });
  }
  async function offer(message) {
    const { id, name, size, fingerprint, itemId } = message;
    if (!Number.isSafeInteger(size) || size < 0 || typeof name !== 'string' || !name.length ||
      name.length > 512 || typeof fingerprint !== 'string' || fingerprint.length > 256) throw new Error('invalid_metadata');
    if (!await acceptOffer(message)) throw new Error('invalid_metadata');
    const lan = await isLan();
    if (size > relayFileLimit && !lan) throw new Error('waiting_lan');
    let item = incoming.get(id);
    if (item && (item.fingerprint !== fingerprint || item.view.size !== size)) throw new Error('source_changed');
    if (item?.view.status === 'cancelled') throw new Error('cancelled');
    if (item?.view.status === 'paused' && !message.resume) throw new Error('paused');
    if (!item) {
      if ([...incoming.values()].filter((value) => !terminal(value.view)).length >= 3) throw new Error('too_many_transfers');
      const key = await digest(new TextEncoder().encode(`${peer}:${id}`));
      const sink = await openSink({ key, size, fingerprint });
      const view = viewFor(id, name, size, false, itemId);
      view.bytes = sink.offset;
      item = { view, sink, fingerprint };
      incoming.set(id, item); views.set(id, view);
    }
    if (!terminal(item.view)) { item.view.status = 'transferring'; item.view.detail = ''; }
    item.view.lan = lan; changed();
    await reply(message, { offset: item.view.bytes });
  }
  async function chunk(message) {
    const item = incoming.get(message.id);
    if (!item) throw new Error('restart_required');
    const view = item.view;
    if (view.status === 'paused') throw new Error('paused');
    if (terminal(view)) throw new Error('cancelled');
    if (view.size > relayFileLimit && !await isLan()) throw new Error('waiting_lan');
    if (typeof message.data !== 'string' || message.data.length > Math.ceil(chunkBytes * 4 / 3) + 4 ||
      !Number.isSafeInteger(message.offset)) throw new Error('invalid_chunk');
    const bytes = base64UrlDecode(message.data);
    if (!bytes.length || bytes.length > chunkBytes || message.offset < 0 ||
      message.offset + bytes.length > view.size || await digest(bytes) !== message.digest) throw new Error('checksum_failed');
    if (message.offset === view.bytes) {
      await item.sink.write(view.bytes, bytes);
      advance(view, view.bytes + bytes.length); view.status = 'transferring'; changed();
    } else if (message.offset + bytes.length !== view.bytes || item.lastOffset !== message.offset || item.lastDigest !== message.digest) throw new Error('invalid_offset');
    item.lastOffset = message.offset; item.lastDigest = message.digest;
    await reply(message, { offset: view.bytes });
  }
  async function finish(message) {
    const item = incoming.get(message.id);
    if (!item) throw new Error('restart_required');
    const view = item.view;
    if (view.status === 'completed') { await reply(message, { done: true }); return; }
    if (view.status === 'paused') throw new Error('paused');
    if (view.status === 'cancelled') throw new Error('cancelled');
    if (view.size > relayFileLimit && !await isLan()) throw new Error('waiting_lan');
    if (view.bytes !== view.size) throw new Error('incomplete');
    view.status = 'verifying'; changed();
    const file = await item.sink.file();
    if (file.size !== view.size) throw new Error('incomplete');
    await onReceived(file, view);
    view.status = 'completed'; view.bytesPerSecond = 0; changed();
    await reply(message, { done: true });
  }
  async function control(id, action, remote = false) {
    const view = views.get(id);
    if (!view || terminal(view) || !['pause', 'resume', 'cancel'].includes(action)) return;
    const receiver = incoming.get(id);
    if (receiver) {
      await serial(id, async () => {
        if (terminal(view)) return;
        view.status = action === 'cancel' ? 'cancelled' : action === 'pause' ? 'paused' : 'waiting';
        view.detail = ''; view.bytesPerSecond = 0;
        if (action === 'cancel') await receiver.sink.remove(); else await receiver.sink.checkpoint();
      });
      changed();
      if (!remote) await send({ type: 'transfer.control', id, action }).catch(() => {});
      return;
    }
    const item = outgoing.get(id);
    if (action === 'resume') {
      if (item) {
        if (remote) void run(item, true); else await run(item, true);
      } else {
        view.status = 'waiting';
        if (!remote) await send({ type: 'transfer.control', id, action });
      }
    } else {
      if (item) item.stopped = true;
      view.status = action === 'cancel' ? 'cancelled' : 'paused'; view.detail = ''; view.bytesPerSecond = 0;
      for (const [key, pending] of replies) if (key.startsWith(`${id}:`)) pending.reject(new Error('paused'));
      const receiver = incoming.get(id);
      if (receiver) {
        if (action === 'cancel') await receiver.sink.remove();
        else await receiver.sink.checkpoint();
      }
      if (!remote) await send({ type: 'transfer.control', id, action }).catch(() => {});
    }
    changed();
  }
  function retryWaiting() {
    for (const item of outgoing.values()) if (item.view.status === 'waiting') void run(item);
  }
  async function suspend() {
    for (const pending of replies.values()) pending.reject(new Error('connection_lost'));
    for (const item of incoming.values()) if (!terminal(item.view)) {
      if (item.view.status !== 'paused') item.view.status = 'waiting';
      item.view.bytesPerSecond = 0;
      await serial(item.view.id, () => item.sink.checkpoint()).catch(() => { item.view.status = 'failed'; item.view.detail = 'storage_error'; });
    }
    changed();
  }
  async function dispose({ remove = false } = {}) {
    disposed = true;
    for (const item of outgoing.values()) item.stopped = true;
    await suspend();
    if (remove) for (const item of incoming.values()) await serial(item.view.id, () => item.sink.remove()).catch(() => {});
  }
  return { sendFile, handle, control, retryWaiting, suspend, dispose,
    get transfers() { return [...views.values()].reverse(); } };
}
