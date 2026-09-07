import assert from "node:assert/strict";
import test from "node:test";
import { createContentTransferController } from "../../docs/app/app-content-transfer.js";

function replaceGlobal(t, name, value) {
  const previous = Object.getOwnPropertyDescriptor(globalThis, name);
  Object.defineProperty(globalThis, name, { configurable: true, value });
  t.after(() => {
    if (previous) Object.defineProperty(globalThis, name, previous);
    else delete globalThis[name];
  });
}

test("unreadable selected files keep the selection and offer a translated recovery", async (t) => {
  const file = testFile("unreadable.bin", [1]);
  file.slice = () => ({
    async arrayBuffer() { throw new DOMException("Platform detail", "NotReadableError"); },
  });
  const fixture = transferFixture(t, { selectedFile: file });
  await fixture.controller.sendComposerContent();
  assert.equal(fixture.session.selectedFile, file);
  assert.equal(fixture.session.sending, false);
  assert.deepEqual(fixture.toasts, ["无法读取这个文件，请重新选择后发送"]);
});

test("failed download activation immediately releases its Blob URL", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const revoked = [];
  replaceGlobal(t, "URL", {
    createObjectURL() { return "blob:synthetic-download"; },
    revokeObjectURL(url) { revoked.push(url); },
  });
  replaceGlobal(t, "document", {
    createElement() { throw new Error("Activation failed"); },
  });
  const fixture = transferFixture(t);
  fixture.controller.beginDownload({ transferId: "empty", name: "empty.txt", size: 0 }, fixture.session);
  fixture.controller.finishDownload("empty", fixture.session);
  assert.deepEqual(revoked, ["blob:synthetic-download"]);
  assert.deepEqual(fixture.toasts, ["无法保存文件，请重新下载"]);
  t.mock.timers.tick(30_001);
  assert.equal(revoked.length, 1);
});

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((promiseResolve, promiseReject) => {
    resolve = promiseResolve;
    reject = promiseReject;
  });
  return { promise, resolve, reject };
}

async function flushMicrotasks(turns = 8) {
  for (let index = 0; index < turns; index += 1) await Promise.resolve();
}

function testFile(name, values) {
  const data = Uint8Array.from(values);
  return {
    name,
    type: "application/octet-stream",
    size: data.byteLength,
    slice(start, end) {
      const chunk = data.slice(start, end);
      return { arrayBuffer: async () => chunk.buffer };
    },
  };
}

function gatedFile(name, values) {
  const data = Uint8Array.from(values);
  let release;
  return {
    file: {
      name,
      type: "application/octet-stream",
      size: data.byteLength,
      slice() {
        return {
          arrayBuffer: () =>
            new Promise((resolve) => {
              release = () => resolve(data.buffer);
            }),
        };
      },
    },
    releaseChunk() {
      assert.ok(release, "the transfer should be reading its first chunk");
      release();
    },
  };
}

function transferFixture(t, options = {}) {
  const sent = [];
  const toasts = [];
  const clearSelectedFileCalls = [];
  const input = {
    value: options.inputValue || "",
    style: {},
    scrollHeight: 0,
  };
  const session = {
    pair: { room: "room-a", hostName: "Test computer" },
    connected: options.connected ?? true,
    sending: false,
    selectedFile: options.selectedFile || null,
    draftText: options.draftText ?? input.value,
    items: options.items || [],
    outgoingRequests: new Set(),
    downloads: new Map(),
    connectionGeneration: 1,
    contentGeneration: 1,
    channel: options.channel || null,
    socket: options.socket || null,
  };
  const sendButton = {
    disabled: false,
    textContent: "发送",
    setAttribute() {},
  };
  const elements = {
    "message-input": input,
    "send-button": sendButton,
    "file-input": { value: "" },
  };
  const controller = createContentTransferController({
    elements,
    fileActions: options.fileActions,
    maximumFileBytes: 25 * 1024 * 1024,
    maximumClipboardTextBytes: 128 * 1024,
    maximumClipboardItemBytes: 256 * 1024,
    fileChunkBytes: options.fileChunkBytes || 4,
    maximumConcurrentDownloads: 3,
    maximumEncodedFileChunkLength: 1024,
    downloadIdleTimeoutMs: options.downloadIdleTimeoutMs || 100,
    activeSession: () => session,
    sessionIsActive: (candidate) => candidate === session,
    renderClipboard() {},
    renderAgentEvents() {},
    updateAppBadge() {},
    notifyAgentCompletion() {},
    sendMessage:
      options.sendMessage ||
      (async (message, context) => {
        sent.push({ message, context });
      }),
    currentSessionContext:
      options.currentSessionContext ||
      ((candidate) => ({
        key: candidate.pair.room,
        connectionGeneration: candidate.connectionGeneration,
        contentGeneration: candidate.contentGeneration,
      })),
    clearSelectedFile:
      options.clearSelectedFile ||
      (() => {
        clearSelectedFileCalls.push(true);
        session.selectedFile = null;
      }),
    resizeComposerInput() {},
    updateSendButton() {
      sendButton.disabled =
        !session.connected ||
        session.sending ||
        (!session.selectedFile && !input.value.trim());
      sendButton.textContent = session.sending ? "发送中…" : "发送";
    },
    showToast: options.showToast || ((message) => toasts.push(message)),
  });
  t.after(() => {
    session.downloads.clear();
  });
  return {
    controller,
    elements,
    session,
    sent,
    toasts,
    clearSelectedFileCalls,
  };
}

test("repeated file clicks send one request and route its complete bytes to preview only", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const token = {};
  const previews = [];
  const fixture = transferFixture(t, { fileActions: {
    openPreview: () => token,
    showPreview: (...args) => previews.push(args),
    saveFile: assert.fail,
    failPreview: assert.fail,
    closePreview() {},
  } });
  const item = { id: "image", fileName: "photo.png", fileSize: 4 };
  await fixture.controller.requestFile(item, fixture.session, { preview: true });
  await fixture.controller.requestFile(item, fixture.session);
  assert.equal(fixture.sent.length, 1);
  fixture.controller.beginDownload({ transferId: "image-transfer", itemId: item.id, name: item.fileName, size: 4 }, fixture.session);
  fixture.controller.receiveDownloadChunk({ transferId: "image-transfer", index: 0, data: "AQIDBA" }, fixture.session);
  fixture.controller.finishDownload("image-transfer", fixture.session);
  assert.equal(previews.length, 1);
  assert.equal(previews[0][0], token);
  assert.equal(previews[0][1].size, 4);
  assert.equal(fixture.session.fileRequests.size, 0);
  t.mock.timers.tick(1000);
});

test("missing file responses time out, unlock retry, and disconnect clears pending requests", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const fixture = transferFixture(t);
  const item = { id: "missing", fileName: "missing.txt" };
  await fixture.controller.requestFile(item, fixture.session);
  t.mock.timers.tick(101);
  assert.equal(fixture.session.fileRequests.size, 0);
  assert.match(fixture.toasts.at(-1), /电脑未返回文件/);
  await fixture.controller.requestFile(item, fixture.session);
  fixture.controller.clearDownloads(fixture.session);
  assert.equal(fixture.session.fileRequests.size, 0);
  const count = fixture.toasts.length;
  t.mock.timers.tick(101);
  assert.equal(fixture.toasts.length, count);
});

test("a late preview after request timeout keeps its cancelled intent and never auto-saves", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const token = { cancelled: false };
  const seen = [];
  const fixture = transferFixture(t, { fileActions: {
    openPreview: () => token,
    showPreview: (intent) => seen.push(intent),
    saveFile: assert.fail,
    failPreview() {},
    closePreview() {},
  } });
  const item = { id: "late", fileName: "late.png", fileSize: 0 };
  await fixture.controller.requestFile(item, fixture.session, { preview: true });
  t.mock.timers.tick(101);
  assert.equal(token.cancelled, true);
  fixture.controller.beginDownload({ transferId: "late-transfer", itemId: item.id, name: item.fileName, size: 0 }, fixture.session);
  fixture.controller.finishDownload("late-transfer", fixture.session);
  assert.equal(seen[0], token);
  assert.equal(seen[0].cancelled, true);
});

test("a second composer send is ignored while the first is in flight", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const gate = deferred();
  const fixture = transferFixture(t, {
    inputValue: "first draft",
    sendMessage: async (message) => {
      fixture.sent.push({ message });
      await gate.promise;
    },
  });

  const first = fixture.controller.sendComposerContent();
  await flushMicrotasks();
  const second = fixture.controller.sendComposerContent();

  assert.equal(fixture.sent.length, 1);
  assert.equal(fixture.session.sending, true);
  assert.equal(fixture.elements["send-button"].disabled, true);
  gate.resolve();
  await Promise.all([first, second]);
  assert.equal(fixture.sent.length, 1);
  assert.equal(fixture.session.sending, false);
  assert.equal(fixture.toasts.length, 1);
});

test("a new typed draft survives completion of the earlier text send", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const gate = deferred();
  const fixture = transferFixture(t, {
    inputValue: "old draft",
    sendMessage: async (message) => {
      fixture.sent.push({ message });
      await gate.promise;
    },
  });

  const sending = fixture.controller.sendComposerContent();
  await flushMicrotasks();
  fixture.elements["message-input"].value = "new draft";
  fixture.session.draftText = "new draft";
  gate.resolve();
  await sending;

  assert.equal(fixture.elements["message-input"].value, "new draft");
  assert.equal(fixture.session.draftText, "new draft");
  assert.equal(fixture.sent.length, 1);
});

test("a replacement selected file survives completion of the earlier file send", async (t) => {
  const startGate = deferred();
  const firstFile = testFile("first.bin", [1, 2]);
  const replacement = testFile("replacement.bin", [3, 4]);
  const fixture = transferFixture(t, {
    selectedFile: firstFile,
    sendMessage: async (message) => {
      fixture.sent.push({ message });
      if (message.type === "file.start") await startGate.promise;
    },
  });

  const sending = fixture.controller.sendComposerContent();
  await flushMicrotasks();
  assert.deepEqual(
    fixture.sent.map(({ message }) => message.type),
    ["file.start"],
  );
  fixture.session.selectedFile = replacement;
  startGate.resolve();
  await sending;

  assert.strictEqual(fixture.session.selectedFile, replacement);
  assert.equal(fixture.clearSelectedFileCalls.length, 0);
  assert.deepEqual(
    fixture.sent.map(({ message }) => message.type),
    ["file.start", "file.chunk", "file.end"],
  );
});

test("a file send aborts instead of switching transports after file.start", async (t) => {
  const channel = { readyState: "open", bufferedAmount: 0 };
  const sent = [];
  const fixture = transferFixture(t, {
    selectedFile: testFile("transport-switch.bin", [1, 2]),
    channel,
    sendMessage: async (message) => {
      sent.push(message);
      if (message.type === "file.start") {
        channel.readyState = "closed";
        return { kind: "channel", target: channel };
      }
    },
  });

  await fixture.controller.sendComposerContent();

  assert.deepEqual(sent.map(({ type }) => type), ["file.start"]);
  assert.equal(fixture.session.selectedFile.name, "transport-switch.bin");
  assert.equal(fixture.session.sending, false);
  assert.deepEqual(fixture.toasts, ["连接传输已经变化，请重新发送文件"]);
});

test("sending a file leaves the typed draft untouched", async (t) => {
  const fixture = transferFixture(t, {
    inputValue: "keep typing this",
    selectedFile: testFile("attachment.bin", [1, 2]),
  });

  await fixture.controller.sendComposerContent();

  assert.equal(fixture.elements["message-input"].value, "keep typing this");
  assert.equal(fixture.session.draftText, "keep typing this");
  assert.equal(fixture.session.selectedFile, null);
  assert.equal(fixture.clearSelectedFileCalls.length, 1);
});

test("a failed text send leaves the composer retryable", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let attempts = 0;
  const fixture = transferFixture(t, {
    inputValue: "retry me",
    sendMessage: async (message) => {
      attempts += 1;
      fixture.sent.push({ message });
      if (attempts === 1) throw new Error("synthetic send failure");
    },
  });

  await fixture.controller.sendComposerContent();
  assert.equal(fixture.session.sending, false);
  assert.equal(fixture.elements["message-input"].value, "retry me");
  assert.equal(fixture.toasts.length, 1);

  await fixture.controller.sendComposerContent();
  assert.equal(attempts, 2);
  assert.equal(fixture.elements["message-input"].value, "");
  assert.equal(fixture.session.draftText, "");
  assert.equal(fixture.toasts.length, 2);
});

test("an idle incomplete download is removed with its accumulated transfer state", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const fixture = transferFixture(t, { downloadIdleTimeoutMs: 50 });
  const transferId = "download-idle";

  fixture.controller.beginDownload(
    { transferId, size: 8, name: "incomplete.bin" },
    fixture.session,
  );
  const download = fixture.session.downloads.get(transferId);
  fixture.controller.receiveDownloadChunk(
    { transferId, index: 0, data: "AQIDBA" },
    fixture.session,
  );
  assert.equal(download.received, 4);
  assert.equal(fixture.session.downloads.has(transferId), true);

  t.mock.timers.tick(49);
  assert.equal(fixture.session.downloads.has(transferId), true);
  t.mock.timers.tick(1);
  assert.equal(fixture.session.downloads.has(transferId), false);
  assert.equal(fixture.toasts.length, 1);
});

test("finishing a download cancels its idle timeout", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let clicked = 0;
  const anchor = {
    href: "",
    download: "",
    click() {
      clicked += 1;
    },
  };
  replaceGlobal(t, "document", { createElement: () => anchor });
  replaceGlobal(t, "URL", {
    createObjectURL: () => "blob:test",
    revokeObjectURL() {},
  });
  const fixture = transferFixture(t, { downloadIdleTimeoutMs: 50 });
  const transferId = "download-complete";

  fixture.controller.beginDownload(
    { transferId, size: 4, name: "complete.bin" },
    fixture.session,
  );
  fixture.controller.receiveDownloadChunk(
    { transferId, index: 0, data: "AQIDBA" },
    fixture.session,
  );
  fixture.controller.finishDownload(transferId, fixture.session);
  const toastCount = fixture.toasts.length;

  assert.equal(clicked, 1);
  assert.equal(fixture.session.downloads.has(transferId), false);
  t.mock.timers.tick(50);
  assert.equal(fixture.toasts.length, toastCount);
});

test("rejecting a download cancels its idle timeout", (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const fixture = transferFixture(t, { downloadIdleTimeoutMs: 50 });
  const transferId = "download-rejected";

  fixture.controller.beginDownload(
    { transferId, size: 4, name: "rejected.bin" },
    fixture.session,
  );
  fixture.controller.receiveDownloadChunk(
    { transferId, index: 1, data: "AQIDBA" },
    fixture.session,
  );
  const toastCount = fixture.toasts.length;

  assert.equal(fixture.session.downloads.has(transferId), false);
  t.mock.timers.tick(50);
  assert.equal(fixture.toasts.length, toastCount);
});

test("backpressure aborts a file send after the session disconnects", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const startGate = deferred();
  const gated = gatedFile("disconnect.bin", [1, 2]);
  const fixture = transferFixture(t, {
    selectedFile: gated.file,
    channel: { readyState: "open", bufferedAmount: 2 * 1024 * 1024 },
    sendMessage: async (message) => {
      fixture.sent.push({ message });
      if (message.type === "file.start") await startGate.promise;
    },
  });

  const sending = fixture.controller.sendComposerContent();
  await flushMicrotasks();
  startGate.resolve();
  await flushMicrotasks();
  gated.releaseChunk();
  await flushMicrotasks();
  fixture.session.connected = false;
  t.mock.timers.tick(12);
  await sending;

  assert.deepEqual(
    fixture.sent.map(({ message }) => message.type),
    ["file.start"],
  );
  assert.equal(fixture.session.sending, false);
  assert.equal(fixture.toasts.length, 1);
});

test("backpressure aborts a file send when its content generation changes", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const startGate = deferred();
  const gated = gatedFile("generation.bin", [1, 2]);
  const fixture = transferFixture(t, {
    selectedFile: gated.file,
    channel: { readyState: "open", bufferedAmount: 2 * 1024 * 1024 },
    sendMessage: async (message) => {
      fixture.sent.push({ message });
      if (message.type === "file.start") await startGate.promise;
    },
  });

  const sending = fixture.controller.sendComposerContent();
  await flushMicrotasks();
  startGate.resolve();
  await flushMicrotasks();
  gated.releaseChunk();
  await flushMicrotasks();
  fixture.session.contentGeneration += 1;
  t.mock.timers.tick(12);
  await sending;

  assert.deepEqual(
    fixture.sent.map(({ message }) => message.type),
    ["file.start"],
  );
  assert.equal(fixture.session.sending, false);
  assert.equal(fixture.toasts.length, 1);
});
