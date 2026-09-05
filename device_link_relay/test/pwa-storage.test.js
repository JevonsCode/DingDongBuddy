import assert from "node:assert/strict";
import test from "node:test";
import { idbDelete, idbGet, idbSetMany } from "../../docs/app/app-storage.js";

function replaceGlobal(t, name, value) {
  const previous = Object.getOwnPropertyDescriptor(globalThis, name);
  Object.defineProperty(globalThis, name, { configurable: true, value });
  t.after(() => {
    if (previous) Object.defineProperty(globalThis, name, previous);
    else delete globalThis[name];
  });
}

function createIndexedDbMock({ cloneError } = {}) {
  const state = {
    cloneError,
    closeCount: 0,
    records: new Map([["answer", { value: 42 }]]),
    transactions: [],
  };

  class MockObjectStore {
    constructor(transaction) {
      this.transaction = transaction;
    }

    delete(key) {
      state.records.delete(key);
      return {};
    }

    get(key) {
      const request = {
        error: null,
        onsuccess: null,
        onerror: null,
        result: state.records.get(key),
      };
      this.transaction.lastRequest = request;
      return request;
    }

    put(value, key) {
      if (state.cloneError) throw state.cloneError;
      state.records.set(key, value);
      return {};
    }
  }

  class MockTransaction {
    constructor(mode) {
      this.error = null;
      this.lastRequest = null;
      this.mode = mode;
      this.abortCount = 0;
      this.onabort = null;
      this.oncomplete = null;
      this.onerror = null;
      this.store = new MockObjectStore(this);
    }

    abort(error = new Error("The transaction was aborted")) {
      this.abortCount += 1;
      this.error = error;
      this.onabort?.({ target: this });
    }

    complete() {
      this.oncomplete?.({ target: this });
    }

    fail(error = new Error("The transaction failed")) {
      this.error = error;
      this.onerror?.({ target: this });
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
      const transaction = new MockTransaction(mode);
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
        const database = new MockDatabase();
        request.result = database;
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

async function waitForTransaction(state) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    if (state.transactions.length > 0) return state.transactions[0];
    await Promise.resolve();
  }
  assert.fail("IndexedDB transaction was not opened");
}

test("closes the database when a transaction reports an error", async (t) => {
  const fixture = createIndexedDbMock();
  replaceGlobal(t, "indexedDB", fixture.indexedDB);

  const pending = idbDelete("stale");
  const transaction = await waitForTransaction(fixture.state);
  const failure = new Error("write failed");
  transaction.fail(failure);

  await assert.rejects(pending, (error) => error === failure);
  assert.equal(fixture.state.closeCount, 1);
});

test("closes the database after a synchronous clone error", async (t) => {
  const cloneError = new Error("value could not be cloned");
  cloneError.name = "DataCloneError";
  const fixture = createIndexedDbMock({ cloneError });
  replaceGlobal(t, "indexedDB", fixture.indexedDB);

  const pending = idbSetMany([["invalid", { callback() {} }]]);
  const transaction = await waitForTransaction(fixture.state);

  await assert.rejects(pending, (error) => error === cloneError);
  assert.equal(transaction.abortCount, 1);
  assert.equal(fixture.state.closeCount, 1);
});

test("closes the database when a transaction is aborted", async (t) => {
  const fixture = createIndexedDbMock();
  replaceGlobal(t, "indexedDB", fixture.indexedDB);

  const pending = idbDelete("stale");
  const transaction = await waitForTransaction(fixture.state);
  const failure = new Error("transaction aborted");
  transaction.abort(failure);

  await assert.rejects(pending, (error) => error === failure);
  assert.equal(fixture.state.closeCount, 1);
});

test("closes the database after a successful transaction", async (t) => {
  const fixture = createIndexedDbMock();
  replaceGlobal(t, "indexedDB", fixture.indexedDB);

  const pending = idbSetMany([["saved", { value: "ok" }], ["stale", null]]);
  const transaction = await waitForTransaction(fixture.state);
  transaction.complete();

  await pending;
  assert.equal(fixture.state.closeCount, 1);
});

test("waits for get transaction completion before settling", async (t) => {
  const fixture = createIndexedDbMock();
  replaceGlobal(t, "indexedDB", fixture.indexedDB);

  const pending = idbGet("answer");
  const transaction = await waitForTransaction(fixture.state);
  transaction.lastRequest.onsuccess?.({ target: transaction.lastRequest });

  let settled = false;
  pending.then(() => {
    settled = true;
  });
  await Promise.resolve();
  assert.equal(settled, false);

  transaction.complete();
  assert.deepEqual(await pending, { value: 42 });
  assert.equal(fixture.state.closeCount, 1);
});
