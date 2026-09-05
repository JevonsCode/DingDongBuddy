import assert from "node:assert/strict";
import test from "node:test";
import {
  createConnectionController,
  maximumPendingRemoteCandidates,
  maximumQueuedInboundBytes,
  maximumQueuedInboundEntries,
} from "../../docs/app/app-connection.js";
import {
  maximumRelayFrameBytes,
  openEnvelope,
} from "../../docs/app/app-codecs.js";

function replaceGlobal(t, name, value) {
  const previous = Object.getOwnPropertyDescriptor(globalThis, name);
  Object.defineProperty(globalThis, name, { configurable: true, value });
  t.after(() => {
    if (previous) Object.defineProperty(globalThis, name, previous);
    else delete globalThis[name];
  });
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((promiseResolve, promiseReject) => {
    resolve = promiseResolve;
    reject = promiseReject;
  });
  return { promise, resolve, reject };
}

function clearBuffer(message) {
  return new TextEncoder().encode(JSON.stringify(message)).buffer;
}

function cryptoFixture(onDecrypt) {
  return {
    subtle: {
      async importKey() {
        return {};
      },
      async decrypt(...args) {
        return onDecrypt(...args);
      },
    },
  };
}

async function flushMicrotasks(turns = 6) {
  for (let index = 0; index < turns; index += 1) await Promise.resolve();
}

function fixture(t, { onDecrypt = async () => clearBuffer({ type: "welcome" }) } = {}) {
  class Socket extends EventTarget {
    static OPEN = 1;
    static CONNECTING = 0;

    readyState = 1;
    sent = [];

    send(value) {
      this.sent.push(value);
    }

    close() {
      if (this.readyState === 3) return;
      this.readyState = 3;
      this.dispatchEvent(new Event("close"));
    }

    raw(value) {
      this.dispatchEvent(new MessageEvent("message", { data: value }));
    }

    frame(value) {
      this.raw(JSON.stringify(value));
    }
  }

  replaceGlobal(t, "WebSocket", Socket);
  replaceGlobal(t, "crypto", cryptoFixture(onDecrypt));

  const pair = {
    version: 1,
    room: "inbound-bounds-test",
    secret: Buffer.alloc(32, 7).toString("base64url"),
    relay: "http://localhost",
    manualDisconnect: true,
  };
  const session = {
    pair,
    socket: null,
    channel: null,
    peer: null,
    signalKey: null,
    connectionGeneration: 0,
    contentGeneration: 0,
    relayGeneration: 0,
    connecting: false,
    connected: false,
    relayHostPresent: false,
    helloSent: false,
    connectionSuperseded: false,
    items: [],
    downloads: new Map(),
    outgoingRequests: new Set(),
    clipboardRenderRevision: 0,
    remoteCandidates: [],
    reconnectDelayMs: 2400,
  };
  const state = {
    sessions: new Map([[pair.room, session]]),
    identity: { id: "test", name: "test", platform: "test" },
  };
  const toasts = [];
  const received = [];
  let renders = 0;
  const controller = createConnectionController({
    state,
    activeSession: () => session,
    initialReconnectDelayMs: 2400,
    maximumReconnectDelayMs: 30000,
    render() {
      renders += 1;
    },
    savePairings() {},
    notificationPermission: () => "default",
    async sendSettings() {},
    receiveClipboardSnapshot(message) {
      received.push(message);
    },
    upsertClipboardItem() {},
    handleRequestRejected() {},
    receiveAgentEvent() {},
    receiveAgentState() {},
    beginDownload() {},
    receiveDownloadChunk(message) {
      received.push(message);
    },
    finishDownload() {},
    clearDownloads(currentSession) {
      currentSession.downloads.clear();
    },
    showToast(message) {
      toasts.push(message);
    },
  });
  t.after(() => controller.closeConnection(session));
  return { controller, session, toasts, received, get renders() { return renders; } };
}

async function connectedFixture(t, options) {
  const value = fixture(t, options);
  await value.controller.connect();
  value.session.connected = true;
  return value;
}

test("rejects an oversized relay frame before JSON parsing", async (t) => {
  const value = await connectedFixture(t);
  let parsed = false;
  const originalParse = JSON.parse;
  JSON.parse = (...args) => {
    parsed = true;
    return originalParse(...args);
  };
  t.after(() => {
    JSON.parse = originalParse;
  });

  value.session.socket.raw("{".padEnd(maximumRelayFrameBytes + 1, "x"));
  await flushMicrotasks();

  assert.equal(parsed, false);
  assert.equal(value.session.socket, null);
  assert.equal(value.session.connected, false);
  assert.ok(value.renders > 0);
  assert.equal(value.toasts.length, 1);
  assert.match(value.toasts[0], /256 KB/);
});

test("bounds the relay queue by bytes while frame processing is deferred", async (t) => {
  const gate = deferred();
  const value = await connectedFixture(t, {
    onDecrypt: () => gate.promise,
  });
  const payload = "A".repeat(200_000);
  const raw = JSON.stringify({ type: "data", payload });
  const maximumFrames = Math.ceil(maximumQueuedInboundBytes / raw.length);

  for (let index = 0; index < maximumFrames; index += 1) {
    value.session.socket.raw(raw);
  }
  await flushMicrotasks();

  assert.equal(value.session.socket, null);
  assert.equal(value.session.connected, false);
  assert.equal(value.toasts.length, 1);
  assert.match(value.toasts[0], /连接消息过多/);
  gate.resolve(clearBuffer({ type: "welcome" }));
  await flushMicrotasks(16);
});

test("bounds the decrypted inbound queue by count and releases the old epoch budget", async (t) => {
  const gate = deferred();
  const value = await connectedFixture(t, {
    onDecrypt: () => gate.promise,
  });
  const payload = "A".repeat(40);
  const frame = JSON.stringify({ type: "data", payload });

  value.session.socket.raw(frame);
  await flushMicrotasks();
  const oldQueue = value.session.incomingQueue;
  for (let index = 1; index < maximumQueuedInboundEntries; index += 1) {
    value.session.socket.raw(frame);
    await flushMicrotasks();
  }
  assert.equal(oldQueue.count, maximumQueuedInboundEntries);
  const pending = value.session.incomingMessages;

  value.session.socket.raw(frame);
  await flushMicrotasks();

  assert.equal(value.session.socket, null);
  assert.equal(value.session.connected, false);
  assert.equal(value.toasts.length, 1);
  assert.match(value.toasts[0], /连接消息过多/);
  assert.ok([...oldQueue.entries].some((entry) => entry.payload === null));
  gate.resolve(clearBuffer({ type: "welcome" }));
  await pending;
  assert.equal(oldQueue.count, 0);
  assert.equal(oldQueue.bytes, 0);
  assert.equal(oldQueue.entries.size, 0);
});

test("bounds the decrypted inbound queue by bytes while crypto is deferred", async (t) => {
  const gate = deferred();
  const value = await connectedFixture(t, {
    onDecrypt: () => gate.promise,
  });
  const payload = "A".repeat(200_000);
  const frame = JSON.stringify({ type: "data", payload });
  const safeEntries = Math.floor((maximumQueuedInboundBytes - 1) / payload.length);

  value.session.socket.raw(frame);
  await flushMicrotasks();
  const oldQueue = value.session.incomingQueue;
  for (let index = 1; index < safeEntries; index += 1) {
    value.session.socket.raw(frame);
    await flushMicrotasks();
  }
  assert.equal(oldQueue.count, safeEntries);
  assert.ok(oldQueue.bytes < maximumQueuedInboundBytes);
  const pending = value.session.incomingMessages;

  value.session.socket.raw(frame);
  await flushMicrotasks();

  assert.equal(value.session.socket, null);
  assert.equal(value.session.connected, false);
  assert.equal(value.toasts.length, 1);
  assert.match(value.toasts[0], /连接消息过多/);
  gate.resolve(clearBuffer({ type: "welcome" }));
  await pending;
  assert.equal(oldQueue.count, 0);
  assert.equal(oldQueue.bytes, 0);
});

test("bounds pending remote ICE candidates and closes the session on overflow", async (t) => {
  class Candidate {
    constructor(value) {
      Object.assign(this, value);
    }
  }
  replaceGlobal(t, "RTCIceCandidate", Candidate);
  const value = await connectedFixture(t, {
    onDecrypt: async () =>
      clearBuffer({
        type: "candidate",
        candidate: "candidate:1 1 UDP 1 192.0.2.1 9 typ host",
        sdpMid: "0",
        sdpMLineIndex: 0,
      }),
  });
  const frame = JSON.stringify({ type: "signal", payload: "A".repeat(40) });

  for (let index = 0; index < maximumPendingRemoteCandidates; index += 1) {
    value.session.socket.raw(frame);
    await value.session.relayFrames;
  }
  assert.equal(value.session.remoteCandidates.length, maximumPendingRemoteCandidates);

  value.session.socket.raw(frame);
  await flushMicrotasks();
  assert.equal(value.session.socket, null);
  assert.equal(value.session.connected, false);
  assert.equal(value.toasts.length, 1);
  assert.match(value.toasts[0], /连接消息过多/);
});

test("accepts a normal encrypted chunk under the inbound limits", async (t) => {
  const value = await connectedFixture(t, {
    onDecrypt: async () =>
      clearBuffer({
        type: "file.chunk",
        transferId: "transfer-1",
        index: 0,
        data: "AQID",
      }),
  });
  value.session.socket.frame({ type: "data", payload: "A".repeat(40) });
  await value.session.relayFrames;
  await value.session.incomingMessages;

  assert.equal(value.session.socket.readyState, WebSocket.OPEN);
  assert.equal(value.received.length, 1);
  assert.equal(value.received[0].transferId, "transfer-1");
  assert.equal(value.toasts.length, 0);
});

test("rejects oversized encrypted envelopes before crypto", async (t) => {
  let decryptCalled = false;
  replaceGlobal(
    t,
    "crypto",
    cryptoFixture(async () => {
      decryptCalled = true;
      return clearBuffer({ type: "welcome" });
    }),
  );

  await assert.rejects(
    openEnvelope("A".repeat(maximumRelayFrameBytes + 1), {}),
    (error) => error?.code === "relay-frame-too-large",
  );
  assert.equal(decryptCalled, false);
});
