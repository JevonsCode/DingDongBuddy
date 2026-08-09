const cacheName = "dingdong-app-shell-v19";
const notificationJobs = new Map();
const notificationDedupeMs = 24 * 60 * 60 * 1000;
const notificationVibrationPattern = [250, 100, 250, 100, 450];
const agentLaunchIntentKey = "agent-launch-intent";

self.addEventListener("install", (event) => {
  const scope = new URL(self.registration.scope);
  const base = scope.pathname.endsWith("/") ? scope.pathname : `${scope.pathname}/`;
  const assets = new URL("../assets/", self.registration.scope).pathname;
  event.waitUntil(
    caches
      .open(cacheName)
      .then((cache) =>
        cache.addAll([
          base,
          `${base}index.html`,
          `${base}styles.css`,
          `${base}app.js`,
          `${base}connection-policy.js`,
          `${base}notification-policy.js`,
          `${base}device-name.js`,
          `${base}pairing-state.js`,
          `${base}content-navigation.js`,
          `${base}manifest.webmanifest`,
          `${assets}dingdong-icon.png`,
          `${assets}dingdong-pwa-192.png`,
          `${assets}dingdong-pwa-512.png`,
          `${assets}dingdong-mobile-alert-icon.png`,
          `${assets}dingdong-mobile-alert-icon-2.png`,
          `${assets}dingdong-sleeping-icon.png`,
          `${assets}dingdong-sleeping-icon-2.png`,
          `${assets}dingdong-rest-icon.png`,
          `${assets}dingdong-thinking-icon.png`,
        ]),
      )
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter(
              (key) => key.startsWith("dingdong-app-shell-") && key !== cacheName,
            )
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin || url.pathname.startsWith("/v1/")) return;
  const isApplicationShell =
    request.mode === "navigate" ||
    (url.pathname.startsWith(new URL(self.registration.scope).pathname) &&
      /(?:\.html|\.js|\.css|\.webmanifest)$/.test(url.pathname));
  event.respondWith(
    isApplicationShell ? networkFirst(request) : cacheFirst(request),
  );
});

async function networkFirst(request) {
  try {
    const response = await fetch(request);
    await cacheResponse(request, response);
    return response;
  } catch {
    const cached = await caches.match(request);
    if (cached) return cached;
    if (request.mode === "navigate") {
      const scope = new URL(self.registration.scope);
      return caches.match(scope.pathname);
    }
    throw new Error("Network and cache are both unavailable");
  }
}

async function cacheFirst(request) {
  const cached = await caches.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  await cacheResponse(request, response);
  return response;
}

async function cacheResponse(request, response) {
  if (!response.ok || response.type !== "basic") return;
  const cache = await caches.open(cacheName);
  await cache.put(request, response.clone());
}

self.addEventListener("push", (event) => {
  event.waitUntil(handlePush(event));
});

async function handlePush(event) {
  let pair = null;
  let messageId = "unknown";
  let receivedHealth = Promise.resolve();
  try {
    const payload = event.data?.json();
    if (
      typeof payload?.envelope !== "string" ||
      typeof payload?.messageId !== "string" ||
      typeof payload?.room !== "string"
    ) {
      throw pushError("invalid-payload");
    }
    messageId = payload.messageId;
    pair = await idbGet("pair");
    if (!pair) throw pushError("pair-missing");
    if (payload.room !== pair.room) return;
    receivedHealth = recordPushHealth(
      "received",
      messageId,
      null,
      pair.room,
      pair.notificationEpoch,
    ).catch(() => {});
    if (pair.agentNotificationsEnabled !== true) {
      throw pushError("notifications-disabled");
    }
    const key = await crypto.subtle.importKey(
      "raw",
      base64UrlDecode(pair.secret),
      { name: "AES-GCM" },
      false,
      ["decrypt"],
    );
    let message;
    try {
      message = await openEnvelope(payload.envelope, key);
    } catch {
      throw pushError("decrypt-failed");
    }
    if (message.type !== "agent.completed" || message.id !== messageId) {
      throw pushError("unexpected-message");
    }
    if (!workerPairMatches(pair, await idbGet("pair"))) {
      await rejectStalePush(pair, messageId, receivedHealth);
      return;
    }
    let notificationResult;
    try {
      notificationResult = await showAgentCompletionNotification(message, pair);
    } catch {
      throw pushError("notification-create-failed");
    }
    if (notificationResult === "stale") {
      await rejectStalePush(pair, messageId, receivedHealth);
      return;
    }
    if (notificationResult === "duplicate") {
      await receivedHealth;
      await postPushReceipt(pair, messageId, "received").catch(() => {});
      if (!workerPairMatches(pair, await idbGet("pair"))) return;
      const clients = await self.clients.matchAll({
        type: "window",
        includeUncontrolled: true,
      });
      for (const client of clients) {
        client.postMessage({
          type: "agent.completed",
          source: "push",
          message,
        });
        client.postMessage({
          type: "push.health",
          stage: "received",
          messageId,
          room: pair.room,
          notificationEpoch: pair.notificationEpoch,
        });
      }
      return;
    }
    await receivedHealth;
    await recordPushHealth(
      "created",
      messageId,
      null,
      pair.room,
      pair.notificationEpoch,
    ).catch(() => {});
    await Promise.all([
      postPushReceipt(pair, messageId, "received").catch(() => {}),
      postPushReceipt(pair, messageId, "created").catch(() => {}),
    ]);
    if (!workerPairMatches(pair, await idbGet("pair"))) return;
    const clients = await self.clients.matchAll({
      type: "window",
      includeUncontrolled: true,
    });
    for (const client of clients) {
      client.postMessage({
        type: "agent.completed",
        source: "push",
        message,
      });
      client.postMessage({
        type: "push.health",
        stage: "created",
        messageId,
        room: pair.room,
        notificationEpoch: pair.notificationEpoch,
      });
    }
  } catch (error) {
    const errorCode = pushErrorCode(error);
    await receivedHealth;
    await recordPushHealth(
      "failed",
      messageId,
      errorCode,
      pair?.room,
      pair?.notificationEpoch,
    ).catch(() => {});
    if (pair && messageId !== "unknown") {
      await postPushReceipt(pair, messageId, "failed", errorCode).catch(
        () => {},
      );
    }
    await postPushHealthToClients(
      "failed",
      messageId,
      errorCode,
      pair?.room,
      pair?.notificationEpoch,
    ).catch(() => {});
    if (
      shouldRevokeBrokenPushSubscription(errorCode) &&
      (await pushFailureContextStillCurrent(pair))
    ) {
      await revokeBrokenPushSubscription(pair).catch(() => {});
    }
  }
}

async function rejectStalePush(pair, messageId, receivedHealth) {
  await receivedHealth;
  await recordPushHealth(
    "failed",
    messageId,
    "pair-changed",
    pair.room,
    pair.notificationEpoch,
  ).catch(() => {});
  await postPushReceipt(
    pair,
    messageId,
    "failed",
    "pair-changed",
  ).catch(() => {});
}

self.addEventListener("message", (event) => {
  if (event.data?.type !== "agent.completed.realtime") return;
  event.waitUntil(handleRealtimeAgentCompletion(event.data));
});

self.addEventListener("pushsubscriptionchange", (event) => {
  event.waitUntil(
    refreshPushSubscription(event.newSubscription).catch(() => {}),
  );
});

async function refreshPushSubscription(replacement) {
  const pair = await idbGet("pair");
  if (!pair || pair.agentNotificationsEnabled !== true) return;
  const base = pair.relay.endsWith("/") ? pair.relay : `${pair.relay}/`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const configResponse = await fetch(new URL("v1/config", base), {
      cache: "no-store",
      signal: controller.signal,
    });
    if (!configResponse.ok) return;
    const config = await configResponse.json();
    if (!config.pushAvailable || !config.vapidPublicKey) return;
    const subscription =
      replacement ||
      (await self.registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: base64UrlDecode(config.vapidPublicKey),
      }));
    if (!workerPairMatches(pair, await idbGet("pair"))) return;
    const token = await pushToken(pair.secret);
    if (!workerPairMatches(pair, await idbGet("pair"))) return;
    const response = await fetch(
      new URL(`v1/rooms/${pair.room}/subscription`, base),
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          token,
          subscription: subscription.toJSON(),
          supportedContentEncodings: Array.from(
            self.PushManager?.supportedContentEncodings || [],
          ),
        }),
        signal: controller.signal,
      },
    );
    if (!response.ok) throw pushError("subscription-refresh-failed");
    const currentPair = await idbGet("pair");
    if (!workerPairMatches(pair, currentPair)) {
      if (
        !currentPair ||
        currentPair.agentNotificationsEnabled !== true ||
        currentPair.room !== pair.room ||
        currentPair.relay !== pair.relay
      ) {
        await deletePushRegistration(pair).catch(() => {});
      }
    }
  } finally {
    clearTimeout(timeout);
  }
}

function workerPairMatches(expected, current) {
  return (
    expected?.agentNotificationsEnabled === true &&
    current?.agentNotificationsEnabled === true &&
    workerPairSnapshotMatches(expected, current)
  );
}

function workerPairSnapshotMatches(expected, current) {
  return (
    Boolean(expected) &&
    Boolean(current) &&
    expected.room === current.room &&
    expected.secret === current.secret &&
    expected.relay === current.relay &&
    expected.notificationEpoch === current.notificationEpoch &&
    expected.agentNotificationsEnabled === current.agentNotificationsEnabled &&
    (expected.vibrationEnabled !== false) ===
      (current.vibrationEnabled !== false)
  );
}

async function handleRealtimeAgentCompletion(context) {
  const message = context?.message;
  if (message?.type !== "agent.completed" || typeof message?.id !== "string") {
    return;
  }
  try {
    const pair = await idbGet("pair");
    if (
      !pair ||
      pair.agentNotificationsEnabled !== true ||
      context.room !== pair.room ||
      context.notificationEpoch !== pair.notificationEpoch
    ) {
      return;
    }
    if (!workerPairMatches(pair, await idbGet("pair"))) return;
    await showAgentCompletionNotification(message, pair);
  } catch {
    // The realtime list remains available even when the platform refuses a
    // system notification. Background delivery diagnostics are handled by
    // the Web Push receipt path above.
  }
}

async function showAgentCompletionNotification(message, pair) {
  const existingJob = notificationJobs.get(message.id);
  if (existingJob) return existingJob;
  const job = (async () => {
    const ledger = await notificationLedger();
    const shownAt = Number(ledger[message.id]);
    if (shownAt > 0 && Date.now() - shownAt < notificationDedupeMs) {
      return "duplicate";
    }
    const detail = String(
      message.detail || message.summary || "本轮任务已经完成。",
    )
      .replace(/\s+/g, " ")
      .trim();
    const vibrate =
      pair.vibrationEnabled !== false && message.vibrate !== false;
    const options = {
      body: detail.length > 260 ? `${detail.slice(0, 259)}…` : detail,
      icon: "../assets/dingdong-mobile-alert-icon.png",
      tag: message.id,
      renotify: true,
      ...(vibrate ? { vibrate: notificationVibrationPattern } : {}),
      data: {
        type: "agent.completed",
        message,
        room: pair.room,
        url: agentCompletionLaunchUrl(),
      },
    };
    if (!workerPairMatches(pair, await idbGet("pair"))) return "stale";
    try {
      await self.registration.showNotification(
        message.title || "Agent 完成啦",
        options,
      );
    } catch (error) {
      if (!vibrate) throw error;
      delete options.vibrate;
      await self.registration.showNotification(
        message.title || "Agent 完成啦",
        options,
      );
    }
    ledger[message.id] = Date.now();
    await idbSet("notification-ledger", trimNotificationLedger(ledger)).catch(
      () => {},
    );
    return "created";
  })();
  notificationJobs.set(message.id, job);
  try {
    return await job;
  } finally {
    if (notificationJobs.get(message.id) === job) {
      notificationJobs.delete(message.id);
    }
  }
}

async function notificationLedger() {
  const value = await idbGet("notification-ledger").catch(() => null);
  return value && typeof value === "object" ? value : {};
}

function trimNotificationLedger(ledger) {
  const cutoff = Date.now() - notificationDedupeMs;
  return Object.fromEntries(
    Object.entries(ledger)
      .filter(([, shownAt]) => Number(shownAt) >= cutoff)
      .sort((left, right) => Number(right[1]) - Number(left[1]))
      .slice(0, 100),
  );
}

async function recordPushHealth(
  stage,
  messageId,
  errorCode,
  room,
  notificationEpoch,
) {
  await idbSet("push-health", {
    stage,
    messageId,
    recordedAt: new Date().toISOString(),
    ...(room ? { room } : {}),
    ...(notificationEpoch ? { notificationEpoch } : {}),
    ...(errorCode ? { errorCode } : {}),
  });
}

async function postPushHealthToClients(
  stage,
  messageId,
  errorCode,
  room,
  notificationEpoch,
) {
  const clients = await self.clients.matchAll({
    type: "window",
    includeUncontrolled: true,
  });
  for (const client of clients) {
    client.postMessage({
      type: "push.health",
      stage,
      messageId,
      ...(room ? { room } : {}),
      ...(notificationEpoch ? { notificationEpoch } : {}),
      ...(errorCode ? { errorCode } : {}),
    });
  }
}

async function postPushReceipt(pair, messageId, stage, errorCode) {
  if (!pair?.relay || !pair?.room || !pair?.secret) return;
  const base = pair.relay.endsWith("/") ? pair.relay : `${pair.relay}/`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4000);
  try {
    await fetch(new URL(`v1/push/${pair.room}/receipt`, base), {
      method: "POST",
      headers: {
        Authorization: `Bearer ${await pushToken(pair.secret)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messageId,
        stage,
        ...(errorCode ? { errorCode } : {}),
      }),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function revokeBrokenPushSubscription(pair) {
  const subscription = await self.registration.pushManager.getSubscription();
  await subscription?.unsubscribe();
  await deletePushRegistration(pair);
}

async function deletePushRegistration(pair) {
  if (!pair?.relay || !pair?.room || !pair?.secret) return;
  const base = pair.relay.endsWith("/") ? pair.relay : `${pair.relay}/`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4000);
  try {
    await fetch(new URL(`v1/rooms/${pair.room}/subscription`, base), {
      method: "DELETE",
      headers: { Authorization: `Bearer ${await pushToken(pair.secret)}` },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

async function pushToken(secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    base64UrlDecode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const value = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode("dingdong-push-v1"),
  );
  return base64UrlEncode(new Uint8Array(value));
}

function pushError(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

function pushErrorCode(error) {
  const value = typeof error?.code === "string" ? error.code : "push-failed";
  return /^[a-z0-9-]{1,64}$/.test(value) ? value : "push-failed";
}

function shouldRevokeBrokenPushSubscription(errorCode) {
  return [
    "pair-missing",
    "notifications-disabled",
    "notification-create-failed",
  ].includes(errorCode);
}

async function pushFailureContextStillCurrent(failedPair) {
  try {
    const currentPair = await idbGet("pair");
    return failedPair
      ? workerPairSnapshotMatches(failedPair, currentPair)
      : !currentPair;
  } catch {
    return false;
  }
}

function agentCompletionLaunchUrl() {
  const url = new URL(self.registration.scope);
  url.searchParams.set("tab", "agent");
  return url.href;
}

self.addEventListener("notificationclick", (event) => {
  const data = event.notification.data || {};
  event.notification.close();
  event.waitUntil(openAgentCompletion(data));
});

async function openAgentCompletion(data) {
  const scope = new URL(self.registration.scope);
  const targetUrl = agentCompletionLaunchUrl();
  const hasPairingRoom = typeof data.room === "string";
  const clients = await self.clients.matchAll({
    type: "window",
    includeUncontrolled: true,
  });
  const appClients = clients.filter((client) => {
    try {
      const url = new URL(client.url);
      return url.origin === scope.origin && url.pathname.startsWith(scope.pathname);
    } catch {
      return false;
    }
  });
  const client =
    appClients.find((value) => value.focused) ||
    appClients.find((value) => value.visibilityState === "visible") ||
    appClients[0];
  if (client) {
    const navigationMessage = {
      type: "content-tab.open",
      tab: "agent",
      room: data.room,
      message: hasPairingRoom ? data.message : undefined,
      reason: "notification-click",
    };
    const focusedClient = await focusWindowClient(client);
    const activeClient = focusedClient || client;
    const acknowledged = await requestContentTabOpen(
      activeClient,
      navigationMessage,
    );
    if (acknowledged) {
      const refocusedClient = focusedClient
        ? focusedClient
        : await focusWindowClient(activeClient);
      return refocusedClient || activeClient;
    }
    await storeAgentLaunchIntent(data);
    if ("navigate" in activeClient) {
      const navigatedClient = await runClientOperationWithTimeout(
        () => activeClient.navigate(targetUrl),
      );
      if (navigatedClient === clientOperationTimedOut) {
        return activeClient;
      }
      if (navigatedClient) {
        return (await focusWindowClient(navigatedClient)) || navigatedClient;
      }
    }
    return self.clients.openWindow(targetUrl);
  }
  await storeAgentLaunchIntent(data);
  return self.clients.openWindow(targetUrl);
}

const clientOperationTimedOut = Symbol("client-operation-timed-out");

async function focusWindowClient(client) {
  if (typeof client?.focus !== "function") return Promise.resolve(null);
  const result = await runClientOperationWithTimeout(() => client.focus());
  return result === clientOperationTimedOut ? null : result;
}

async function runClientOperationWithTimeout(operation, timeoutMs = 1200) {
  let timer;
  try {
    return await Promise.race([
      Promise.resolve().then(operation),
      new Promise((resolve) => {
        timer = setTimeout(() => resolve(clientOperationTimedOut), timeoutMs);
      }),
    ]);
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function storeAgentLaunchIntent(data) {
  const intent = {
    tab: "agent",
    createdAt: Date.now(),
  };
  if (typeof data.room === "string" && typeof data.message?.id === "string") {
    intent.room = data.room;
    intent.message = data.message;
  }
  await idbSet(agentLaunchIntentKey, intent).catch(() => {});
}

function requestContentTabOpen(client, message) {
  if (typeof MessageChannel !== "function") {
    try {
      client.postMessage(message);
    } catch {}
    return Promise.resolve(false);
  }
  return new Promise((resolve) => {
    const channel = new MessageChannel();
    let settled = false;
    const finish = (acknowledged) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      channel.port1.close();
      resolve(acknowledged);
    };
    const timer = setTimeout(() => finish(false), 1200);
    channel.port1.onmessage = (event) => {
      finish(
        event.data?.type === "content-tab.opened" &&
          event.data.tab === message.tab,
      );
    };
    try {
      client.postMessage(message, [channel.port2]);
    } catch {
      finish(false);
    }
  });
}

async function openEnvelope(envelope, key) {
  const value = base64UrlDecode(envelope);
  const clear = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: value.slice(0, 12) },
    key,
    value.slice(12),
  );
  return JSON.parse(new TextDecoder().decode(clear));
}

function base64UrlDecode(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function base64UrlEncode(value) {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

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

async function idbGet(key) {
  const database = await openDatabase();
  const value = await new Promise((resolve, reject) => {
    const transaction = database.transaction("settings", "readonly");
    const request = transaction.objectStore("settings").get(key);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  database.close();
  return value;
}

async function idbSet(key, value) {
  const database = await openDatabase();
  await new Promise((resolve, reject) => {
    const transaction = database.transaction("settings", "readwrite");
    const request = transaction.objectStore("settings").put(value, key);
    request.onsuccess = () => resolve();
    request.onerror = () => reject(request.error);
  });
  database.close();
}
