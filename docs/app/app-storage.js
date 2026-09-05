// IndexedDB is the durable hand-off between the page and Service Worker.
function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open("dingdong-device-link", 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains("settings")) {
        request.result.createObjectStore("settings");
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function transactionFailure(transaction, message) {
  return transaction?.error || new Error(message);
}

function runTransaction(database, mode, operation) {
  return new Promise((resolve, reject) => {
    let transaction;
    let result;
    let settled = false;
    const rejectTransaction = (error, message) => {
      if (settled) return;
      settled = true;
      reject(error || transactionFailure(transaction, message));
    };

    try {
      transaction = database.transaction("settings", mode);
      transaction.oncomplete = () => {
        if (settled) return;
        settled = true;
        resolve(result);
      };
      transaction.onerror = () =>
        rejectTransaction(null, "IndexedDB transaction failed");
      transaction.onabort = () =>
        rejectTransaction(null, "IndexedDB transaction aborted");
      operation(transaction, (value) => {
        result = value;
      });
    } catch (error) {
      rejectTransaction(error, "IndexedDB transaction failed");
      try {
        transaction?.abort();
      } catch {
        // The operation error is the useful failure when abort itself fails.
      }
    }
  });
}

async function withDatabase(operation) {
  const database = await openDatabase();
  try {
    return await operation(database);
  } finally {
    database.close();
  }
}

async function idbSetMany(entries) {
  return withDatabase((database) =>
    runTransaction(database, "readwrite", (transaction) => {
      const store = transaction.objectStore("settings");
      for (const [key, value] of entries) {
        if (value == null) store.delete(key);
        else store.put(value, key);
      }
    }),
  );
}

async function idbGet(key) {
  return withDatabase((database) =>
    runTransaction(database, "readonly", (transaction, setResult) => {
      const request = transaction.objectStore("settings").get(key);
      request.onsuccess = () => setResult(request.result);
    }),
  );
}

async function idbDelete(key) {
  return withDatabase((database) =>
    runTransaction(database, "readwrite", (transaction) => {
      transaction.objectStore("settings").delete(key);
    }),
  );
}

export {
  idbDelete,
  idbGet,
  idbSetMany,
};
