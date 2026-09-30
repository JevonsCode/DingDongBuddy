import assert from 'node:assert/strict';
import test from 'node:test';
import { createResumableTransfers } from '../../docs/app/resumable-transfer.js';

test('large files do not send even metadata before a LAN route is verified', async () => {
  let sends = 0;
  const engine = createResumableTransfers({ peer: 'peer', isLan: () => false,
    send: async () => { sends++; }, onChange() {}, onReceived() {} });
  const view = await engine.sendFile({ name: 'large', size: 25 * 1024 * 1024 + 1, lastModified: 1 });
  assert.equal(view.status, 'waiting');
  assert.equal(view.detail, 'waiting_lan');
  assert.equal(sends, 0);
});

test('a checksum mismatch cannot advance progress or complete a file', async () => {
  const replies = [];
  const engine = createResumableTransfers({ peer: 'peer', isLan: () => true,
    send: async (message) => replies.push(message), onChange() {}, onReceived() { assert.fail('must not finish'); } });
  await engine.handle({ type: 'transfer.offer', id: 'test', request: '1', name: 'file', size: 3, fingerprint: 'source' });
  await engine.handle({ type: 'transfer.chunk', id: 'test', request: '2', offset: 0, data: 'AQID', digest: 'invalid' });
  assert.equal(replies.at(-1).error, 'checksum_failed');
  assert.equal(engine.transfers[0].bytes, 0);
});

test('an interrupted upload resumes from receiver-confirmed bytes and finishes once', async () => {
  const content = Uint8Array.from({ length: 32768 * 3 + 19 }, (_, i) => i % 251);
  const file = new File([content], 'sample.bin', { lastModified: 100 });
  let a, b, broken = true, completed = 0, result;
  const offsets = [];
  a = createResumableTransfers({ peer: 'b', isLan: () => true, onChange() {},
    send: async (message) => {
      if (message.type === 'transfer.chunk') {
        offsets.push(message.offset);
        if (broken && offsets.length === 2) throw new Error('connection_lost');
      }
      await b.handle(message);
    }, onReceived() {} });
  b = createResumableTransfers({ peer: 'a', isLan: () => true, onChange() {},
    send: (message) => a.handle(message),
    onReceived: async (blob) => { completed++; result = new Uint8Array(await blob.arrayBuffer()); },
  });
  const view = await a.sendFile(file);
  assert.equal(view.status, 'waiting');
  assert.equal(view.bytes, 32768);
  broken = false;
  await a.control(view.id, 'resume');
  assert.deepEqual(offsets, [0, 32768, 32768, 65536, 98304]);
  assert.equal(view.status, 'completed');
  assert.equal(completed, 1);
  assert.deepEqual(result, content);
});

test('pause preserves confirmed bytes, cancel deletes partial data, and an explicit repeat gets a new ID', async () => {
  const file = new File([new Uint8Array(32768 * 2 + 3)], 'repeat.bin', { lastModified: 200 });
  let sender, receiver, pause = true, completions = 0;
  sender = createResumableTransfers({ peer: 'receiver', isLan: () => true, onChange() {}, onReceived() {},
    async send(message) {
      await receiver.handle(message);
      if (pause && message.type === 'transfer.chunk') {
        pause = false;
        await sender.control(message.id, 'pause');
      }
    } });
  receiver = createResumableTransfers({ peer: 'sender', isLan: () => true, onChange() {},
    send: (message) => sender.handle(message), onReceived() { completions++; } });
  const first = await sender.sendFile(file);
  assert.equal(first.status, 'paused');
  assert.equal(receiver.transfers[0].bytes, 32768);
  await sender.control(first.id, 'resume');
  assert.equal(first.status, 'completed');
  const second = await sender.sendFile(file);
  assert.notEqual(first.id, second.id);
  assert.equal(second.status, 'completed');
  assert.equal(completions, 2);
  await receiver.handle({ type: 'transfer.offer', id: 'cancel-test', request: '1', name: 'cancel', size: 0, fingerprint: 'empty' });
  await receiver.control('cancel-test', 'cancel');
  await receiver.handle({ type: 'transfer.finish', id: 'cancel-test', request: '2' });
  assert.equal(receiver.transfers[0].status, 'cancelled');
  assert.equal(completions, 2);
});

test('failed completion can retry without retransmitting the file', async () => {
  let a, b, tries = 0, chunks = 0;
  a = createResumableTransfers({ peer: 'b', isLan: () => true, onChange() {}, onReceived() {},
    send(message) { if (message.type === 'transfer.chunk') chunks++; return b.handle(message); } });
  b = createResumableTransfers({ peer: 'a', isLan: () => true, onChange() {}, send: (message) => a.handle(message),
    onReceived() { if (++tries === 1) throw new Error('test storage issue'); } });
  const view = await a.sendFile(new File(['real content'], 'file'));
  assert.equal(view.status, 'failed');
  await a.control(view.id, 'resume');
  assert.equal(view.status, 'completed');
  assert.equal(tries, 2);
  assert.equal(chunks, 1);
});
