import assert from "node:assert/strict";
import { createECDH, createHmac, randomBytes } from "node:crypto";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  createWebPushRequest,
  isValidPushRegistration,
  isValidRoom,
  RelayRoom,
  secureAssetResponse,
} from "../src/worker.js";
import worker from "../src/worker.js";

const workerSource = readFileSync(new URL("../src/worker.js", import.meta.url), "utf8");

test("relay room ids are opaque and bounded", () => {
  assert.match(workerSource, /const serviceVersion = "1\.3\.6"/);
  assert.match(workerSource, /releaseSha: env\.DINGDONG_RELEASE_SHA \|\| null/);
  assert.equal(isValidRoom("Abcd_1234-efgh5678-IJKL"), true);
  assert.equal(isValidRoom("short"), false);
  assert.equal(isValidRoom("room/with/path"), false);
  assert.equal(isValidRoom("a".repeat(65)), false);
});

test("room connection and legacy subscription routes reach the Durable Object", async () => {
  const durableRequests = [];
  let assetRequests = 0;
  const env = {
    RELAY_ROOMS: {
      idFromName(name) {
        return name;
      },
      get(id) {
        return {
          async fetch(request) {
            if (id.startsWith("!dingdong-ip-rate-")) {
              return new Response(null, { status: 204 });
            }
            durableRequests.push({ id, method: request.method });
            return Response.json({ ok: true });
          },
        };
      },
    },
    ASSETS: {
      async fetch() {
        assetRequests += 1;
        return new Response("not found", { status: 404 });
      },
    },
  };
  const room = "Abcd_1234-efgh5678-IJKL";
  const requests = [
    new Request(`https://relay.example/v1/rooms/${room}`, {
      method: "GET",
      headers: {
        "CF-Connecting-IP": "203.0.113.8",
        Upgrade: "websocket",
      },
    }),
    ...["POST", "DELETE"].map(
      (method) =>
        new Request(`https://relay.example/v1/rooms/${room}/subscription`, {
          method,
          headers: { "CF-Connecting-IP": "203.0.113.8" },
        }),
    ),
  ];
  for (const request of requests) {
    const response = await worker.fetch(
      request,
      env,
    );
    assert.equal(response.status, 200);
  }
  assert.deepEqual(
    durableRequests.map(({ id, method }) => [id, method]),
    [
      [room, "GET"],
      [room, "POST"],
      [room, "DELETE"],
    ],
  );
  assert.equal(assetRequests, 0);
});

test("malformed room encoding is rejected before rate limiting or room lookup", async () => {
  let durableLookups = 0;
  let assetRequests = 0;
  const env = {
    RELAY_ROOMS: {
      idFromName() {
        durableLookups += 1;
        throw new Error("Malformed rooms must not instantiate a Durable Object");
      },
    },
    ASSETS: {
      async fetch() {
        assetRequests += 1;
        return new Response("not found", { status: 404 });
      },
    },
  };

  for (const path of [
    "/v1/rooms/%E0%A4%A",
    "/v1/push/%E0%A4%A/status",
  ]) {
    const response = await worker.fetch(
      new Request(`https://relay.example${path}`),
      env,
    );
    assert.equal(response.status, 400);
    assert.equal(await response.text(), "Invalid room");
  }
  assert.equal(durableLookups, 0);
  assert.equal(assetRequests, 0);
});

test("push subscription aliases dispatch to subscription handling", async () => {
  const storage = {
    async get() {
      return undefined;
    },
  };
  const room = new RelayRoom({ storage }, {});
  const response = await room.fetch(
    new Request(
      "https://relay.example/v1/push/Abcd_1234-efgh5678-IJKL/subscription",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      },
    ),
  );
  assert.equal(response.status, 400);
});

test("replacing a peer does not publish a stale peer-left event", () => {
  assert.match(workerSource, /serializeAttachment\(\{ side, replaced: true \}\)/);
  assert.match(workerSource, /if \(attachment\?\.replaced === true\) return/);
});

test("background notifications use modern Web Push with high urgency", () => {
  const subscriber = createECDH("prime256v1");
  subscriber.generateKeys();
  const vapid = createECDH("prime256v1");
  vapid.generateKeys();
  const request = createWebPushRequest(
    {
      endpoint: "https://fcm.googleapis.com/fcm/send/dingdong-test",
      keys: {
        p256dh: subscriber.getPublicKey().toString("base64url"),
        auth: randomBytes(16).toString("base64url"),
      },
    },
    {
      envelope: "x".repeat(3500),
      messageId: "m".repeat(160),
      room: "Abcd_1234-efgh5678-IJKL",
    },
    {
      subject: "mailto:dingdong@example.com",
      publicKey: vapid.getPublicKey().toString("base64url"),
      privateKey: vapid.getPrivateKey().toString("base64url"),
    },
  );

  assert.equal(request.request.headers.get("content-encoding"), "aes128gcm");
  assert.equal(request.request.headers.get("urgency"), "high");
  assert.equal(request.request.headers.get("ttl"), "86400");
  assert.match(request.request.headers.get("authorization"), /^vapid t=/i);
  assert.ok(request.request.body.byteLength < 4096);
});

test("push status distinguishes provider acceptance from device display", () => {
  assert.match(workerSource, /const accepted = response\.ok/);
  assert.match(workerSource, /stage: accepted \? "provider-accepted"/);
  assert.match(workerSource, /\["received", "created", "failed"\]/);
  assert.match(workerSource, /\{ envelope: body\.envelope, messageId: body\.messageId, room \}/);
  assert.doesNotMatch(workerSource, /delivered: response\.ok/);
});

test("push relay bounds provider access and final encrypted payload size", () => {
  assert.match(workerSource, /!\/\^\[A-Za-z0-9_-\]\+\$\/\.test\(body\.envelope\)/);
  assert.match(workerSource, /details\.body\?\.byteLength > maximumWebPushBytes/);
  assert.match(workerSource, /redirect: "manual"/);
  assert.match(workerSource, /AbortSignal\.timeout\(pushProviderTimeoutMs\)/);
  assert.match(workerSource, /allowedPushProviders/);
  assert.match(workerSource, /enforceGlobalRateLimit/);
  assert.match(workerSource, /readJsonBody\(request, 16 \* 1024\)/);
  assert.match(workerSource, /readJsonBody\(request, 8 \* 1024\)/);
  assert.match(workerSource, /readJsonBody\(request, 1024\)/);
  assert.match(workerSource, /!dingdong-ip-rate-/);
  assert.match(workerSource, /async alarm\(\)/);
  assert.match(workerSource, /deleteAll\(\)/);

  const subscriber = createECDH("prime256v1");
  subscriber.generateKeys();
  const registration = {
    token: "t".repeat(43),
    subscription: {
      endpoint: "https://fcm.googleapis.com/fcm/send/dingdong-test",
      keys: {
        p256dh: subscriber.getPublicKey().toString("base64url"),
        auth: randomBytes(16).toString("base64url"),
      },
    },
  };
  assert.equal(isValidPushRegistration(registration), true);
  assert.equal(
    isValidPushRegistration({
      ...registration,
      subscription: {
        ...registration.subscription,
        endpoint: "https://example.com/collect",
      },
    }),
    false,
  );
  assert.equal(
    isValidPushRegistration({
      ...registration,
      subscription: {
        ...registration.subscription,
        keys: { ...registration.subscription.keys, auth: "too-short" },
      },
    }),
    false,
  );
});

test("connection rate limits expire and do not grow storage forever", async () => {
  const values = new Map();
  let alarm = null;
  const storage = {
    async get(key) {
      return values.get(key);
    },
    async put(key, value) {
      values.set(key, value);
    },
    async delete(keys) {
      for (const key of Array.isArray(keys) ? keys : [keys]) values.delete(key);
    },
    async setAlarm(value) {
      alarm = value;
    },
    async deleteAll() {
      values.clear();
    },
  };
  const room = new RelayRoom({ storage }, {});
  const request = new Request("https://dingdong.internal/internal/push-rate-limit", {
    method: "POST",
    headers: {
      "x-dingdong-rate-key": "a".repeat(64),
      "x-dingdong-rate-kind": "connection",
    },
  });

  for (let index = 0; index < 60; index += 1) {
    assert.equal((await room.enforceRateLimit(request.clone())).status, 204);
  }
  assert.equal((await room.enforceRateLimit(request.clone())).status, 429);
  assert.ok(Number.isFinite(alarm));

  await room.alarm();
  assert.equal(values.size, 0);
});

test("lifecycle telemetry stores only a keyed installation hash", async () => {
  const { env, batches, rateKinds } = telemetryEnvironment();
  const event = lifecycleEvent();
  const response = await worker.fetch(
    lifecycleRequest(event),
    env,
  );

  assert.equal(response.status, 202);
  assert.deepEqual(await response.json(), { accepted: true });
  assert.deepEqual(rateKinds, ["telemetry"]);
  assert.equal(batches.length, 1);
  assert.equal(batches[0].length, 2);
  const expectedHash = createHmac(
    "sha256",
    env.TELEMETRY_HASH_SECRET,
  )
    .update(event.installationId)
    .digest("hex");
  assert.equal(batches[0][0].values[0], expectedHash);
  assert.equal(batches[0][1].values[1], expectedHash);
  assert.doesNotMatch(JSON.stringify(batches), new RegExp(event.installationId));
  assert.match(batches[0][0].sql, /WHERE NOT EXISTS/);
  assert.match(batches[0][0].sql, /ON CONFLICT\(installation_hash\)/);
  assert.match(batches[0][1].sql, /INSERT OR IGNORE/);

  const duplicate = await worker.fetch(lifecycleRequest(event), env);
  assert.equal(duplicate.status, 202);
  assert.equal(batches[1][0].values.at(-1), event.eventId);
  assert.equal(batches[1][1].values[0], event.eventId);
  assert.equal(batches[1][1].values[1], expectedHash);
});

test("lifecycle telemetry rejects unbounded or behavior-bearing payloads", async () => {
  const { env, batches } = telemetryEnvironment();
  for (const event of [
    { ...lifecycleEvent(), clipboardContent: "private" },
    { ...lifecycleEvent(), platform: "linux" },
    { ...lifecycleEvent(), currentVersion: 130 },
    {
      ...lifecycleEvent(),
      event: "install",
      previousVersion: "1.2.0",
    },
  ]) {
    const response = await worker.fetch(lifecycleRequest(event), env);
    assert.equal(response.status, 400);
  }
  assert.equal(batches.length, 0);

  const oversized = await worker.fetch(
    new Request("https://relay.example/v1/telemetry/lifecycle", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ padding: "x".repeat(5000) }),
    }),
    env,
  );
  assert.equal(oversized.status, 413);
});

test("lifecycle telemetry fails closed when D1 or the hash secret is absent", async () => {
  const configured = telemetryEnvironment();
  const missingDatabase = {
    ...configured.env,
    TELEMETRY_DB: undefined,
  };
  const missingSecret = {
    ...configured.env,
    TELEMETRY_HASH_SECRET: undefined,
  };

  assert.equal(
    (await worker.fetch(lifecycleRequest(lifecycleEvent()), missingDatabase))
      .status,
    503,
  );
  assert.equal(
    (await worker.fetch(lifecycleRequest(lifecycleEvent()), missingSecret))
      .status,
    503,
  );
  assert.equal(
    (
      await worker.fetch(
        new Request("https://relay.example/v1/telemetry/lifecycle"),
        configured.env,
      )
    ).status,
    405,
  );

  const config = await worker.fetch(
    new Request("https://relay.example/v1/config"),
    configured.env,
  );
  assert.equal((await config.json()).lifecycleTelemetryAvailable, true);
});

test("PWA asset responses include strict browser security headers", async () => {
  const response = secureAssetResponse(
    new Response("ok", {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    }),
  );

  assert.equal(await response.text(), "ok");
  assert.match(
    response.headers.get("content-security-policy"),
    /default-src 'self'/,
  );
  assert.equal(response.headers.get("x-content-type-options"), "nosniff");
  assert.equal(response.headers.get("referrer-policy"), "no-referrer");
  assert.match(
    response.headers.get("strict-transport-security"),
    /max-age=31536000/,
  );
});

test("an expired subscription keeps its room token authority", async () => {
  const values = new Map([["push-auth-token", "t".repeat(43)]]);
  const storage = {
    async get(key) {
      return values.get(key);
    },
    async put(key, value) {
      if (typeof key === "object") {
        for (const [entryKey, entryValue] of Object.entries(key)) {
          values.set(entryKey, entryValue);
        }
        return;
      }
      values.set(key, value);
    },
    async delete(keys) {
      for (const key of Array.isArray(keys) ? keys : [keys]) values.delete(key);
    },
  };
  const room = new RelayRoom({ storage }, {});
  const subscriber = createECDH("prime256v1");
  subscriber.generateKeys();
  const registration = {
    token: "x".repeat(43),
    supportedContentEncodings: ["aes128gcm"],
    subscription: {
      endpoint: "https://fcm.googleapis.com/fcm/send/dingdong-test",
      keys: {
        p256dh: subscriber.getPublicKey().toString("base64url"),
        auth: randomBytes(16).toString("base64url"),
      },
    },
  };
  const response = await room.updateSubscription(
    new Request("https://relay.example/v1/rooms/test/subscription", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${"t".repeat(43)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(registration),
    }),
  );
  assert.equal(response.status, 401);
  assert.equal(values.get("push-auth-token"), "t".repeat(43));

  const deleteResponse = await room.updateSubscription(
    new Request("https://relay.example/v1/rooms/test/subscription", {
      method: "DELETE",
    }),
  );
  assert.equal(deleteResponse.status, 401);

  const oversized = await room.updateSubscription(
    new Request("https://relay.example/v1/rooms/test/subscription", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ padding: "x".repeat(17000) }),
    }),
  );
  assert.equal(oversized.status, 413);
});

function lifecycleEvent() {
  return {
    schemaVersion: 1,
    eventId: "11111111-1111-4111-8111-111111111111",
    installationId: "22222222-2222-4222-8222-222222222222",
    event: "upgrade",
    currentVersion: "1.3.2",
    currentBuild: "43",
    previousVersion: "1.3.0",
    previousBuild: "42",
    platform: "macos",
    architecture: "arm64",
    occurredAt: "2026-08-09T03:04:05.000Z",
  };
}

function lifecycleRequest(event) {
  return new Request("https://relay.example/v1/telemetry/lifecycle", {
    method: "POST",
    headers: {
      "CF-Connecting-IP": "203.0.113.20",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(event),
  });
}

function telemetryEnvironment() {
  const batches = [];
  const rateKinds = [];
  const database = {
    prepare(sql) {
      return {
        bind(...values) {
          return { sql, values };
        },
      };
    },
    async batch(statements) {
      batches.push(statements);
      return statements.map(() => ({ success: true }));
    },
  };
  const env = {
    TELEMETRY_DB: database,
    TELEMETRY_HASH_SECRET: "dingdong-test-hmac-secret-with-32-bytes",
    RELAY_ROOMS: {
      idFromName(name) {
        return name;
      },
      get() {
        return {
          async fetch(request) {
            rateKinds.push(request.headers.get("x-dingdong-rate-kind"));
            return new Response(null, { status: 204 });
          },
        };
      },
    },
    ASSETS: {
      async fetch() {
        throw new Error("Telemetry must not reach the asset binding");
      },
    },
  };
  return { env, batches, rateKinds };
}
