import assert from "node:assert/strict";
import test from "node:test";
import { createContentTransferController } from "../../docs/app/app-content-transfer.js";
import { createPairingController } from "../../docs/app/app-pairing.js";

// Browser API fixtures; these tests never read or write a real clipboard/account.
function replaceGlobal(t, name, value) {
  const previous = Object.getOwnPropertyDescriptor(globalThis, name);
  Object.defineProperty(globalThis, name, { configurable: true, value });
  t.after(() => {
    if (previous) Object.defineProperty(globalThis, name, previous);
    else delete globalThis[name];
  });
}

for (const failure of [false, new Error("Copy blocked by browser")]) {
  test(`copy failure (${failure === false ? "false" : "exception"}) never claims success`, async (t) => {
    let removed = false;
    const textarea = {
      style: {},
      select() {},
      remove() { removed = true; },
    };
    replaceGlobal(t, "navigator", {
      clipboard: { async writeText() { throw new Error("Permission denied"); } },
    });
    replaceGlobal(t, "document", {
      createElement: () => textarea,
      body: { append() {} },
      execCommand() {
        if (failure instanceof Error) throw failure;
        return failure;
      },
    });
    const messages = [];
    const controller = createContentTransferController({ showToast: (text) => messages.push(text) });
    const button = { innerHTML: "Copy", textContent: "Copy" };

    assert.equal(await controller.copyItem({ content: "Synthetic test text" }, button), false);
    assert.equal(button.textContent, "Copy");
    assert.equal(removed, true);
    assert.deepEqual(messages, ["复制失败，请长按文字手动复制"]);
  });
}

test("successful native copy confirms only after the clipboard promise resolves", async (t) => {
  let finishCopy;
  let written;
  replaceGlobal(t, "navigator", {
    clipboard: {
      writeText(text) {
        written = text;
        return new Promise((resolve) => { finishCopy = resolve; });
      },
    },
  });
  const controller = createContentTransferController({ showToast: assert.fail });
  const button = { innerHTML: "Copy", textContent: "Copy" };
  const copying = controller.copyItem({ content: "Synthetic test text" }, button);
  assert.equal(button.textContent, "Copy");
  assert.equal(written, "Synthetic test text");
  finishCopy();
  assert.equal(await copying, true);
  assert.equal(button.textContent, "已复制");
});

function pairingFixture(t, overrides = {}) {
  const pair = {
    version: 1,
    room: "pairing-test-room-000001",
    secret: "a".repeat(43),
    relay: "https://relay.example.invalid",
    hostId: "test-host",
    hostName: "Test computer",
  };
  const previousSession = { pair: { ...pair, secret: "b".repeat(43) } };
  const state = {
    pendingPair: pair,
    sessions: new Map([[pair.room, previousSession]]),
    identity: { name: "Test phone" },
  };
  const elements = {
    "device-name": { value: "Test phone", focus() {} },
    "confirm-pair": { disabled: false },
    "cancel-pair": { disabled: false },
  };
  const connected = [];
  const messages = [];
  replaceGlobal(t, "localStorage", { setItem() {}, removeItem() {} });
  replaceGlobal(t, "location", { hash: "#pair=test", pathname: "/app/", search: "" });
  replaceGlobal(t, "history", { replaceState() {} });
  const controller = createPairingController({
    state,
    elements,
    storageKeys: { identity: "test.identity", pendingPair: "test.pending" },
    sessionForRoom: (room) => state.sessions.get(room),
    createDeviceSession: (nextPair) => ({ pair: nextPair }),
    invalidateNotificationOperations() {},
    closeConnection() {},
    async persistPairingsForWorker() {},
    async cleanupPushSubscription() {},
    async resetNotificationRuntime() {},
    savePairings() {},
    render() {},
    notificationsCanRunInCurrentSurface: () => false,
    connect: (session) => connected.push(session),
    showToast: (message) => messages.push(message),
    ...overrides,
  });
  return { controller, state, elements, connected, messages };
}

test("double confirmation during old-pair cleanup creates only one new connection", async (t) => {
  let finishCleanup;
  let cleanupCount = 0;
  const fixture = pairingFixture(t, {
    persistPairingsForWorker() {
      cleanupCount++;
      return new Promise((resolve) => { finishCleanup = resolve; });
    },
  });
  const first = fixture.controller.confirmPairing();
  assert.equal(fixture.elements["confirm-pair"].disabled, true);
  assert.equal(fixture.elements["cancel-pair"].disabled, true);
  await fixture.controller.confirmPairing();
  assert.equal(fixture.connected.length, 0);
  assert.equal(cleanupCount, 1);
  finishCleanup();
  await first;
  assert.equal(fixture.connected.length, 1);
  assert.equal(fixture.state.sessions.size, 1);
  assert.equal(fixture.state.pendingPair, null);
  assert.equal(fixture.elements["confirm-pair"].disabled, false);
  assert.equal(fixture.elements["cancel-pair"].disabled, false);
});

test("failed pairing cleanup leaves a retryable confirmation", async (t) => {
  const fixture = pairingFixture(t, {
    async cleanupPushSubscription() { throw new Error("Test cleanup failure"); },
  });
  await fixture.controller.confirmPairing();
  assert.equal(fixture.connected.length, 0);
  assert.notEqual(fixture.state.pendingPair, null);
  assert.equal(fixture.elements["confirm-pair"].disabled, false);
  assert.equal(fixture.elements["cancel-pair"].disabled, false);
  assert.deepEqual(fixture.messages, ["连接准备失败，请重试"]);
});
