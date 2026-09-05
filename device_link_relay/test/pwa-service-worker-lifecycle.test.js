import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const serviceWorkerSource = readFileSync(
  new URL("../../docs/app/service-worker.js", import.meta.url),
  "utf8",
);

const pair = {
  agentNotificationsEnabled: true,
  notificationEpoch: 1,
  relay: "https://relay.example.invalid",
  room: "service-worker-test-room",
  secret: "service-worker-test-secret",
  vibrationEnabled: false,
};

function clone(value) {
  return value === undefined ? undefined : structuredClone(value);
}

function createIndexedDbMock({ failKey = null, failure = new Error("IDB request failed") } = {}) {
  const state = {
    closeCount: 0,
    databases: [],
    failedDatabase: null,
    ledgerReadCount: 0,
    ledgerReadWaiters: [],
    records: new Map([
      ["pairings", { pairings: [pair], version: 2 }],
      ["notification-ledger", {}],
    ]),
    transactions: [],
  };

  class MockObjectStore {
    constructor(transaction) {
      this.transaction = transaction;
    }

    delete(key) {
      const request = { error: null, onerror: null, onsuccess: null };
      queueMicrotask(() => {
        state.records.delete(key);
        request.onsuccess?.({ target: request });
        queueMicrotask(() => this.transaction.complete());
      });
      return request;
    }

    get(key) {
      const request = {
        error: null,
        onerror: null,
        onsuccess: null,
        result: undefined,
      };
      const complete = () => {
        if (key === failKey && !state.failedDatabase) {
          state.failedDatabase = this.transaction.database;
          request.error = failure;
          request.onerror?.({ target: request });
          return;
        }
        request.result = clone(state.records.get(key));
        request.onsuccess?.({ target: request });
        queueMicrotask(() => this.transaction.complete());
      };
      if (key === "notification-ledger" && state.ledgerReadCount < 2) {
        state.ledgerReadCount += 1;
        state.ledgerReadWaiters.push(complete);
        if (state.ledgerReadCount === 2) {
          queueMicrotask(() => {
            const waiters = state.ledgerReadWaiters.splice(0);
            state.ledgerReadWaiters = [];
            for (const waiter of waiters) waiter();
          });
        }
      } else {
        queueMicrotask(complete);
      }
      this.transaction.lastRequest = request;
      return request;
    }

    put(value, key) {
      const request = { error: null, onerror: null, onsuccess: null };
      queueMicrotask(() => {
        state.records.set(key, clone(value));
        request.onsuccess?.({ target: request });
        queueMicrotask(() => this.transaction.complete());
      });
      return request;
    }
  }

  class MockTransaction {
    constructor(database, mode) {
      this.database = database;
      this.error = null;
      this.lastRequest = null;
      this.mode = mode;
      this.onabort = null;
      this.oncomplete = null;
      this.onerror = null;
      this.store = new MockObjectStore(this);
    }

    complete() {
      this.oncomplete?.({ target: this });
    }

    objectStore(name) {
      assert.equal(name, "settings");
      return this.store;
    }
  }

  class MockDatabase {
    constructor() {
      this.closed = false;
      this.objectStoreNames = {
        contains(name) {
          return name === "settings";
        },
      };
      state.databases.push(this);
    }

    close() {
      this.closed = true;
      state.closeCount += 1;
    }

    createObjectStore(name) {
      assert.equal(name, "settings");
      return {};
    }

    transaction(name, mode) {
      assert.equal(name, "settings");
      assert.ok(mode === "readonly" || mode === "readwrite");
      const transaction = new MockTransaction(this, mode);
      state.transactions.push(transaction);
      return transaction;
    }
  }

  return {
    indexedDB: {
      open(name, version) {
        assert.equal(name, "dingdong-device-link");
        assert.equal(version, 1);
        const request = {
          error: null,
          onerror: null,
          onupgradeneeded: null,
          result: null,
          onsuccess: null,
        };
        request.result = new MockDatabase();
        queueMicrotask(() => {
          request.onupgradeneeded?.({ target: request });
          request.onsuccess?.({ target: request });
        });
        return request;
      },
    },
    state,
  };
}

function createServiceWorkerHarness(options = {}) {
  const listeners = new Map();
  const indexedDb = createIndexedDbMock(options);
  const notifications = [];
  const self = {
    addEventListener(type, listener) {
      const handlers = listeners.get(type) || [];
      handlers.push(listener);
      listeners.set(type, handlers);
    },
    clients: {
      async matchAll() {
        return [];
      },
    },
    location: new URL("https://dingdong.example/"),
    navigator: {},
    registration: {
      scope: "https://dingdong.example/app/",
      async showNotification(title, notificationOptions) {
        notifications.push({ options: notificationOptions, title });
      },
    },
  };
  const context = vm.createContext({
    AbortController,
    URL,
    clearTimeout,
    crypto: globalThis.crypto,
    fetch: async () => {
      throw new Error("unexpected fetch in Service Worker harness");
    },
    indexedDB: indexedDb.indexedDB,
    queueMicrotask,
    self,
    setTimeout,
    TextDecoder,
    TextEncoder,
  });
  vm.runInContext(serviceWorkerSource, context, {
    filename: "service-worker.js",
  });

  return {
    notifications,
    state: indexedDb.state,
    async dispatch(type, data) {
      const waits = [];
      const event = {
        data,
        waitUntil(promise) {
          waits.push(Promise.resolve(promise));
        },
      };
      for (const listener of listeners.get(type) || []) listener(event);
      await Promise.all(waits);
    },
  };
}

function realtimeCompletion(id) {
  return {
    message: {
      detail: `detail-${id}`,
      id,
      type: "agent.completed",
    },
    notificationEpoch: pair.notificationEpoch,
    room: pair.room,
    type: "agent.completed.realtime",
  };
}

test("serializes distinct notification ledger updates without losing either key", async () => {
  const harness = createServiceWorkerHarness();
  await Promise.all([
    harness.dispatch("message", realtimeCompletion("first")),
    harness.dispatch("message", realtimeCompletion("second")),
  ]);

  const ledger = harness.state.records.get("notification-ledger");
  assert.deepEqual(Object.keys(ledger).sort(), [
    `${pair.room}:first`,
    `${pair.room}:second`,
  ]);
  assert.equal(harness.notifications.length, 2);
});

test("closes the database when a Service Worker IndexedDB request fails", async () => {
  const harness = createServiceWorkerHarness({ failKey: "pairings" });
  await harness.dispatch("message", realtimeCompletion("failed-read"));

  assert.ok(harness.state.failedDatabase);
  assert.equal(harness.state.failedDatabase.closed, true);
  assert.ok(harness.state.closeCount >= 1);
});
