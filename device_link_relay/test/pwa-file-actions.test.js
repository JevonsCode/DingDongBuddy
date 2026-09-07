import assert from "node:assert/strict";
import test from "node:test";
import { createDownloadHistory, createFileActions, downloadHistoryKey, imageMimeType } from "../../docs/app/app-file-actions.js";
import { formatTime, formatLifecycleTime } from "../../docs/app/app-formatters.js";

// Synthetic metadata and browser doubles; no real user files or downloads.
const session = { pair: { room: "synthetic-room" } };
const item = { id: "file-a", fileName: "photo.PNG", fileSize: 4, updatedAt: "2026-09-07T01:02:00Z" };
function memoryStorage() {
  const data = new Map();
  return { getItem: (key) => data.get(key) || null, setItem: (key, value) => data.set(key, value) };
}

test("receipt survives reload, is isolated by computer and invalidates changed files", () => {
  const storage = memoryStorage();
  const history = createDownloadHistory(() => storage);
  assert.equal(history.mark(session, item, 12345), true);
  const restored = createDownloadHistory(() => storage);
  assert.equal(restored.get(session, item), 12345);
  assert.equal(restored.get({ pair: { room: "other" } }, item), null);
  assert.equal(restored.get(session, { ...item, updatedAt: "2027-01-01" }), null);
  assert.equal(restored.get(session, { ...item, fileSize: 5 }), null);
  restored.clearRoom(session.pair.room);
  assert.equal(history.get(session, item), null);
});

test("receipts are bounded and do not retain file contents", () => {
  const storage = memoryStorage();
  const history = createDownloadHistory(() => storage);
  for (let index = 0; index < 305; index++) history.mark(session, { ...item, id: `file-${index}`, content: "private-body" }, index + 1);
  const entries = JSON.parse(storage.getItem(downloadHistoryKey));
  assert.equal(entries.length, 300);
  assert.equal(history.get(session, { ...item, id: "file-0" }), null);
  assert.equal(history.get(session, { ...item, id: "file-304" }), 305);
  assert.equal(storage.getItem(downloadHistoryKey).includes("private-body"), false);
});

test("blocked storage degrades to a session-only receipt", () => {
  const history = createDownloadHistory(() => { throw new Error("storage blocked"); });
  assert.equal(history.mark(session, item, 12345), false);
  assert.equal(history.get(session, item), 12345);
});

test("unsupported extensions and malformed history are handled without execution", () => {
  assert.equal(imageMimeType(item), "image/png");
  assert.equal(imageMimeType({ fileName: "image.svg" }), "image/svg+xml");
  for (const fileName of ["page.html", "image.png.exe", "toString", "photo.heic"]) {
    assert.equal(imageMimeType({ fileName }), null);
  }
  const storage = memoryStorage();
  storage.setItem(downloadHistoryKey, "not json");
  assert.equal(createDownloadHistory(() => storage).get(session, item), null);
});

test("feed and lifecycle timestamps include the year and date; missing values stay missing", () => {
  const date = new Date(2025, 11, 31, 23, 58, 20);
  for (const formatter of [formatTime, formatLifecycleTime]) {
    const label = formatter(date);
    assert.match(label, /2025/);
    assert.match(label, /12/);
    assert.match(label, /31/);
    assert.match(label, /23:58/);
    for (const value of [null, undefined, "", "invalid date"]) assert.equal(formatter(value), "未记录");
  }
  assert.match(formatTime(date.toISOString()), /2025/);
});

class Element {
  listeners = new Map();
  hidden = true;
  disabled = false;
  open = false;
  textContent = "";
  addEventListener(event, fn) { this.listeners.set(event, fn); }
  emit(event) { this.listeners.get(event)?.(); }
  removeAttribute(name) { delete this[name]; }
  showModal() { this.open = true; }
  close() { this.open = false; this.emit("close"); }
}
function fixture(t) {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const elements = Object.fromEntries(["dialog", "image", "status", "save", "close", "title"]
    .map((name) => [`image-preview-${name}`, new Element()]));
  const saved = [], revoked = [], blobs = [], toasts = [];
  const originalDocument = Object.getOwnPropertyDescriptor(globalThis, "document");
  Object.defineProperty(globalThis, "document", { configurable: true, value: {
    createElement() { return { click() { saved.push(this.download); } }; },
  } });
  t.after(() => {
    if (originalDocument) Object.defineProperty(globalThis, "document", originalDocument);
    else delete globalThis.document;
  });
  t.mock.method(URL, "createObjectURL", (blob) => { blobs.push(blob); return `blob:fixture-${blobs.length}`; });
  t.mock.method(URL, "revokeObjectURL", (url) => revoked.push(url));
  const history = createDownloadHistory(() => memoryStorageInstance);
  const memoryStorageInstance = memoryStorage();
  const actions = createFileActions({ elements, history, showToast: (message) => toasts.push(message) });
  return { actions, history, elements, saved, revoked, blobs, toasts };
}

test("preview uses typed image blobs, does not mark downloaded, and releases on close", (t) => {
  const f = fixture(t);
  const token = f.actions.openPreview(item, session);
  f.actions.showPreview(token, new Blob(["data"]), { name: item.fileName, item, chunks: [new Uint8Array(4)] });
  assert.equal(token.download.chunks, undefined);
  assert.equal(f.blobs[0].type, "image/png");
  assert.equal(f.history.get(session, item), null);
  assert.deepEqual(f.saved, []);
  f.elements["image-preview-image"].emit("load");
  assert.match(f.elements["image-preview-status"].textContent, /不会自动保存/);
  f.elements["image-preview-close"].emit("click");
  assert.deepEqual(f.revoked, ["blob:fixture-1"]);
  assert.equal(token.blob, null);
  assert.equal(token.download, null);
  assert.equal(f.elements["image-preview-image"].src, undefined);
});

test("a closed/replaced preview never reopens or triggers a download on late completion", (t) => {
  const f = fixture(t);
  const first = f.actions.openPreview(item, session);
  f.actions.openPreview({ ...item, id: "file-b" }, session);
  f.actions.showPreview(first, new Blob(["data"]), { name: item.fileName, item });
  assert.equal(f.blobs.length, 0);
  assert.deepEqual(f.saved, []);
});

test("preview save records a receipt; disconnect only closes the matching device preview", (t) => {
  const f = fixture(t);
  const token = f.actions.openPreview(item, session);
  f.actions.showPreview(token, new Blob(["data"]), { name: item.fileName, item });
  f.actions.closePreview({ pair: { room: "other" } });
  assert.equal(f.elements["image-preview-dialog"].open, true);
  f.elements["image-preview-save"].emit("click");
  assert.deepEqual(f.saved, [item.fileName]);
  assert.ok(f.history.get(session, item));
  f.actions.closePreview(session);
  t.mock.timers.tick(30_001);
  assert.equal(f.revoked.length, 2);
});

test("an image decode failure offers the original file and does not claim a download", (t) => {
  const f = fixture(t);
  const token = f.actions.openPreview(item, session);
  f.actions.showPreview(token, new Blob(["bad image"]), { name: item.fileName, item });
  f.elements["image-preview-image"].emit("error");
  assert.equal(f.elements["image-preview-image"].hidden, true);
  assert.equal(f.elements["image-preview-save"].disabled, false);
  assert.match(f.elements["image-preview-status"].textContent, /无法预览/);
  assert.equal(f.history.get(session, item), null);
});

test("failed browser activation does not create a receipt and releases its URL", (t) => {
  const f = fixture(t);
  t.mock.method(document, "createElement", () => { throw new Error("activation failed"); });
  assert.equal(f.actions.saveFile(new Blob(["data"]), { name: item.fileName, item }, session), false);
  assert.equal(f.history.get(session, item), null);
  assert.deepEqual(f.revoked, ["blob:fixture-1"]);
  assert.match(f.toasts[0], /无法保存/);
});
