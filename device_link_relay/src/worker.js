import webPush from "web-push";

const serviceVersion = "1.3.0";
const maximumFrameBytes = 256 * 1024;
// Web Push providers only guarantee a 4 KiB encrypted message. Keeping the
// already-encrypted DingDong envelope below this limit leaves room for the
// Web Push record header and its small JSON wrapper.
const maximumPushEnvelopeBytes = 3500;
const maximumWebPushBytes = 4096;
const pushTtlSeconds = 24 * 60 * 60;
const pushProviderTimeoutMs = 8000;
const allowedPushProviders = new Set([
  "fcm.googleapis.com",
  "updates.push.services.mozilla.com",
  "push.services.mozilla.com",
  "web.push.apple.com",
]);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
};
const securityHeaders = {
  "Content-Security-Policy":
    "default-src 'self'; base-uri 'none'; connect-src 'self' wss://dingdong.xn--m8txu.com; form-action 'none'; frame-ancestors 'none'; img-src 'self' data: blob:; manifest-src 'self'; object-src 'none'; script-src 'self'; style-src 'self'; worker-src 'self'",
  "Cross-Origin-Resource-Policy": "same-origin",
  "Referrer-Policy": "no-referrer",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
  "X-Content-Type-Options": "nosniff",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (url.pathname === "/v1/health") {
      return jsonResponse({
        service: "dingdong-device-link",
        serviceVersion,
        releaseSha: env.DINGDONG_RELEASE_SHA || null,
        status: "ok",
        contentStorage: false,
      });
    }
    if (url.pathname === "/v1/config") {
      return jsonResponse({
        protocolVersion: 1,
        pushAvailable: Boolean(
          env.VAPID_PUBLIC_KEY && env.VAPID_PRIVATE_KEY,
        ),
        vapidPublicKey: env.VAPID_PUBLIC_KEY || null,
      });
    }
    const route = relayRoute(url.pathname);
    if (route) {
      const room = route.room;
      if (!isValidRoom(room)) {
        return new Response("Invalid room", { status: 400 });
      }
      const methodError = relayMethodError(request, route.kind);
      if (methodError) return methodError;
      const rateLimitResponse = await enforceGlobalRateLimit(
        request,
        env,
        route.kind,
      );
      if (rateLimitResponse) return rateLimitResponse;
      const id = env.RELAY_ROOMS.idFromName(room);
      return env.RELAY_ROOMS.get(id).fetch(request);
    }
    return secureAssetResponse(await env.ASSETS.fetch(request));
  },
};

export class RelayRoom {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/internal/push-rate-limit") {
      return this.enforceRateLimit(request);
    }
    if (url.pathname.endsWith("/subscription")) {
      return this.updateSubscription(request);
    }
    if (url.pathname.startsWith("/v1/push/")) {
      if (url.pathname.endsWith("/receipt")) {
        return this.updatePushReceipt(request);
      }
      if (url.pathname.endsWith("/status")) {
        return this.getPushStatus(request);
      }
      return this.sendPush(request);
    }
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("WebSocket required", { status: 426 });
    }
    const side = new URL(request.url).searchParams.get("side");
    if (side !== "host" && side !== "peer") {
      return new Response("Invalid side", { status: 400 });
    }

    for (const socket of this.ctx.getWebSockets(side)) {
      socket.serializeAttachment({ side, replaced: true });
      socket.close(1008, "Replaced by a newer connection");
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server, [side]);
    server.serializeAttachment({ side });
    server.send(JSON.stringify({ type: "relay", event: "ready" }));

    const otherSide = side === "host" ? "peer" : "host";
    const partners = this.ctx.getWebSockets(otherSide);
    if (partners.length > 0) {
      for (const partner of partners) {
        partner.send(
          JSON.stringify({
            type: "relay",
            event: side === "host" ? "host_joined" : "peer_joined",
          }),
        );
      }
      server.send(
        JSON.stringify({
          type: "relay",
          event: otherSide === "host" ? "host_joined" : "peer_joined",
        }),
      );
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  webSocketMessage(socket, message) {
    const bytes =
      typeof message === "string"
        ? new TextEncoder().encode(message).byteLength
        : message.byteLength;
    if (bytes > maximumFrameBytes) {
      socket.close(1009, "Frame too large");
      return;
    }
    const sourceSide = socket.deserializeAttachment()?.side;
    if (sourceSide !== "host" && sourceSide !== "peer") return;
    const targetSide = sourceSide === "host" ? "peer" : "host";
    for (const partner of this.ctx.getWebSockets(targetSide)) {
      partner.send(message);
    }
  }

  webSocketClose(socket) {
    const attachment = socket.deserializeAttachment();
    if (attachment?.replaced === true) return;
    const sourceSide = attachment?.side;
    if (sourceSide !== "host" && sourceSide !== "peer") return;
    const targetSide = sourceSide === "host" ? "peer" : "host";
    for (const partner of this.ctx.getWebSockets(targetSide)) {
      partner.send(
        JSON.stringify({
          type: "relay",
          event: sourceSide === "host" ? "host_left" : "peer_left",
        }),
      );
    }
  }

  webSocketError() {
    // Cloudflare closes the failed socket. No application data is persisted.
  }

  async updateSubscription(request) {
    if (request.method === "DELETE") {
      const [registration, storedToken] = await Promise.all([
        this.ctx.storage.get("push-subscription"),
        this.ctx.storage.get("push-auth-token"),
      ]);
      const authority = registration?.token || storedToken;
      if (authority && !isAuthorizedToken(request, authority)) {
        return jsonResponse({ error: "Unauthorized" }, 401);
      }
      await this.clearPushDiagnostics();
      await this.ctx.storage.delete(["push-subscription", "push-auth-token"]);
      return jsonResponse({ deleted: true });
    }
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }
    const body = await readJsonBody(request, 16 * 1024);
    if (body === requestBodyTooLarge) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }
    if (!isValidPushRegistration(body)) {
      return jsonResponse({ error: "Invalid subscription" }, 400);
    }
    const [existing, storedToken] = await Promise.all([
      this.ctx.storage.get("push-subscription"),
      this.ctx.storage.get("push-auth-token"),
    ]);
    const authority = existing?.token || storedToken;
    if (
      authority &&
      (!isAuthorizedToken(request, authority) || body.token !== authority)
    ) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
    if (
      Array.isArray(body.supportedContentEncodings) &&
      body.supportedContentEncodings.length > 0 &&
      !body.supportedContentEncodings.includes("aes128gcm")
    ) {
      return jsonResponse({ error: "Unsupported content encoding" }, 400);
    }
    await this.ctx.storage.put("push-subscription", {
      token: body.token,
      subscription: body.subscription,
      supportedContentEncodings: sanitizeContentEncodings(
        body.supportedContentEncodings,
      ),
      provider: providerName(body.subscription.endpoint),
      updatedAt: new Date().toISOString(),
    });
    await this.ctx.storage.put("push-auth-token", body.token);
    await this.clearPushDiagnostics();
    return jsonResponse({
      registered: true,
      contentEncoding: "aes128gcm",
      provider: providerName(body.subscription.endpoint),
    });
  }

  async sendPush(request) {
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }
    const room = pushRoomFromRequest(request.url);
    if (!room) return jsonResponse({ error: "Invalid room" }, 400);
    const registration = await this.ctx.storage.get("push-subscription");
    if (!registration) {
      return jsonResponse({ accepted: false, reason: "not-subscribed" }, 404);
    }
    const authorization = request.headers.get("Authorization") || "";
    if (authorization !== `Bearer ${registration.token}`) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
    if ((await this.ctx.storage.get("push-auth-token")) !== registration.token) {
      await this.ctx.storage.put("push-auth-token", registration.token);
    }
    const body = await readJsonBody(request, 8 * 1024);
    if (body === requestBodyTooLarge) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }
    if (
      typeof body?.envelope !== "string" ||
      !/^[A-Za-z0-9_-]+$/.test(body.envelope) ||
      new TextEncoder().encode(body.envelope).byteLength >
        maximumPushEnvelopeBytes ||
      !isValidMessageId(body.messageId)
    ) {
      return jsonResponse({ error: "Invalid envelope" }, 400);
    }
    if (!this.env.VAPID_PUBLIC_KEY || !this.env.VAPID_PRIVATE_KEY) {
      return jsonResponse({ accepted: false, reason: "push-unconfigured" }, 503);
    }
    const attemptedAt = new Date().toISOString();
    await this.recordPushStatus(body.messageId, {
      messageId: body.messageId,
      stage: "provider-pending",
      accepted: false,
      attemptedAt,
      provider:
        registration.provider || providerName(registration.subscription.endpoint),
    });
    let response;
    try {
      const payload = createWebPushRequest(
        registration.subscription,
        { envelope: body.envelope, messageId: body.messageId, room },
        {
          subject:
            this.env.VAPID_SUBJECT || "https://xn--8ovp9s.xn--m8txu.com/",
          publicKey: this.env.VAPID_PUBLIC_KEY,
          privateKey: this.env.VAPID_PRIVATE_KEY,
        },
      );
      response = await fetch(payload.endpoint, payload.request);
    } catch (error) {
      const reason =
        error?.code === "payload-too-large"
          ? "payload-too-large"
          : "push-provider-error";
      await this.recordPushStatus(body.messageId, {
        messageId: body.messageId,
        stage: "provider-error",
        accepted: false,
        attemptedAt,
        provider:
          registration.provider ||
          providerName(registration.subscription.endpoint),
        reason,
      });
      return jsonResponse(
        { accepted: false, reason },
        reason === "payload-too-large" ? 413 : 502,
      );
    }
    if (response.status === 404 || response.status === 410) {
      const current = await this.ctx.storage.get("push-subscription");
      if (
        current?.token === registration.token &&
        current?.subscription?.endpoint === registration.subscription.endpoint &&
        current?.updatedAt === registration.updatedAt
      ) {
        await this.ctx.storage.delete("push-subscription");
      }
    }
    const accepted = response.ok;
    const reason = accepted
      ? null
      : response.status === 404 || response.status === 410
        ? "subscription-expired"
        : "push-provider-rejected";
    await this.recordPushStatus(body.messageId, {
      messageId: body.messageId,
      stage: accepted ? "provider-accepted" : "provider-error",
      accepted,
      pushStatus: response.status,
      attemptedAt,
      provider:
        registration.provider || providerName(registration.subscription.endpoint),
      ...(reason ? { reason } : {}),
    });
    return jsonResponse(
      {
        accepted,
        messageId: body.messageId,
        pushStatus: response.status,
        ...(reason ? { reason } : {}),
      },
      accepted ? 200 : 502,
    );
  }

  async enforceRateLimit(request) {
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }
    const key = request.headers.get("x-dingdong-rate-key") || "unknown";
    const kind = request.headers.get("x-dingdong-rate-kind") || "push";
    if (!/^[a-f0-9]{64}$/.test(key)) {
      return jsonResponse({ error: "Invalid rate key" }, 400);
    }
    const limit =
      kind === "receipt"
        ? 120
        : kind === "connection"
          ? 60
          : kind === "subscription"
            ? 20
            : 30;
    const minute = Math.floor(Date.now() / 60000);
    const storageKey = `rate:${kind}`;
    const current = await this.ctx.storage.get(storageKey);
    const count = current?.minute === minute ? current.count + 1 : 1;
    await this.ctx.storage.put(storageKey, { minute, count });
    await this.ctx.storage.setAlarm(Date.now() + 10 * 60 * 1000);
    return count > limit
      ? jsonResponse({ error: "Rate limit exceeded" }, 429)
      : new Response(null, { status: 204 });
  }

  async alarm() {
    await this.ctx.storage.deleteAll();
  }

  async recordPushStatus(messageId, status) {
    const ids = await this.ctx.storage.get("push-diagnostic-ids");
    const nextIds = Array.isArray(ids)
      ? ids.filter((value) => value !== messageId)
      : [];
    nextIds.push(messageId);
    const expired = nextIds.splice(0, Math.max(0, nextIds.length - 20));
    const deletions = expired.flatMap((id) => [
      `push-status:${id}`,
      `push-receipt:${id}`,
    ]);
    if (deletions.length > 0) await this.ctx.storage.delete(deletions);
    await this.ctx.storage.put({
      [`push-status:${messageId}`]: status,
      "push-diagnostic-ids": nextIds,
      "last-push-message-id": messageId,
    });
  }

  async clearPushDiagnostics() {
    const ids = await this.ctx.storage.get("push-diagnostic-ids");
    const keys = Array.isArray(ids)
      ? ids.flatMap((id) => [`push-status:${id}`, `push-receipt:${id}`])
      : [];
    await this.ctx.storage.delete([
      ...keys,
      "push-diagnostic-ids",
      "last-push-message-id",
      "push-status",
      "push-receipt",
    ]);
  }

  async updatePushReceipt(request) {
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }
    const [registration, storedToken] = await Promise.all([
      this.ctx.storage.get("push-subscription"),
      this.ctx.storage.get("push-auth-token"),
    ]);
    const token = registration?.token || storedToken;
    if (!token) {
      return jsonResponse({ error: "Not subscribed" }, 404);
    }
    if (!isAuthorizedToken(request, token)) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
    const body = await readJsonBody(request, 1024);
    if (body === requestBodyTooLarge) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }
    if (
      !isValidMessageId(body?.messageId) ||
      !["received", "created", "failed"].includes(body?.stage)
    ) {
      return jsonResponse({ error: "Invalid receipt" }, 400);
    }
    const providerStatus = await this.ctx.storage.get(
      `push-status:${body.messageId}`,
    );
    if (!providerStatus) {
      return jsonResponse({ error: "Unknown push message" }, 409);
    }
    const receipt = {
      messageId: body.messageId,
      stage: body.stage,
      recordedAt: new Date().toISOString(),
      ...(typeof body.errorCode === "string" &&
      /^[a-z0-9-]{1,64}$/.test(body.errorCode)
        ? { errorCode: body.errorCode }
        : {}),
    };
    const receiptKey = `push-receipt:${body.messageId}`;
    const current = await this.ctx.storage.get(receiptKey);
    const stageOrder = { received: 1, failed: 2, created: 3 };
    if ((stageOrder[current?.stage] || 0) <= stageOrder[receipt.stage]) {
      await this.ctx.storage.put(receiptKey, receipt);
    }
    return jsonResponse({ recorded: true });
  }

  async getPushStatus(request) {
    if (request.method !== "GET") {
      return jsonResponse({ error: "Method not allowed" }, 405);
    }
    const [registration, storedToken] = await Promise.all([
      this.ctx.storage.get("push-subscription"),
      this.ctx.storage.get("push-auth-token"),
    ]);
    const token = registration?.token || storedToken;
    if (!token) return jsonResponse({ error: "Not subscribed" }, 404);
    if (!isAuthorizedToken(request, token)) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }
    const requestedMessageId = new URL(request.url).searchParams.get("messageId");
    const messageId = isValidMessageId(requestedMessageId)
      ? requestedMessageId
      : await this.ctx.storage.get("last-push-message-id");
    const [providerStatus, receipt] = await Promise.all([
      messageId ? this.ctx.storage.get(`push-status:${messageId}`) : null,
      messageId ? this.ctx.storage.get(`push-receipt:${messageId}`) : null,
    ]);
    return jsonResponse({
      registered: Boolean(registration),
      contentEncoding: "aes128gcm",
      provider: registration
        ? registration.provider || providerName(registration.subscription.endpoint)
        : providerStatus?.provider || null,
      supportedContentEncodings:
        registration?.supportedContentEncodings || [],
      providerStatus: providerStatus || null,
      receipt: receipt || null,
    });
  }
}

function pushRoomFromRequest(value) {
  try {
    const match = /^\/v1\/push\/([^/]+)$/.exec(new URL(value).pathname);
    if (!match) return null;
    const room = decodeURIComponent(match[1]);
    return isValidRoom(room) ? room : null;
  } catch {
    return null;
  }
}

export function createWebPushRequest(subscription, data, vapidDetails) {
  const details = webPush.generateRequestDetails(
    subscription,
    JSON.stringify(data),
    {
      TTL: pushTtlSeconds,
      urgency: "high",
      contentEncoding: "aes128gcm",
      vapidDetails,
    },
  );
  const headers = new Headers(details.headers);
  if (details.body?.byteLength > maximumWebPushBytes) {
    const error = new RangeError("Web Push payload exceeds 4096 bytes");
    error.code = "payload-too-large";
    throw error;
  }
  // Fetch calculates this itself. Supplying Node's value can be rejected by
  // the Workers runtime as a guarded header.
  headers.delete("content-length");
  return {
    endpoint: details.endpoint,
    request: {
      method: details.method,
      headers,
      body: details.body,
      redirect: "manual",
      signal: AbortSignal.timeout(pushProviderTimeoutMs),
    },
  };
}

export function isValidRoom(value) {
  return /^[A-Za-z0-9_-]{20,64}$/.test(value);
}

export function isValidPushRegistration(body) {
  const subscription = body?.subscription;
  return (
    typeof body?.token === "string" &&
    /^[A-Za-z0-9_-]{32,128}$/.test(body.token) &&
    isAllowedPushEndpoint(subscription?.endpoint) &&
    isValidPushKey(subscription?.keys?.p256dh, 65, true) &&
    isValidPushKey(subscription?.keys?.auth, 16, false)
  );
}

function isValidMessageId(value) {
  return typeof value === "string" && /^[A-Za-z0-9._:-]{1,160}$/.test(value);
}

function isAuthorized(request, registration) {
  return isAuthorizedToken(request, registration.token);
}

function isAuthorizedToken(request, token) {
  return request.headers.get("Authorization") === `Bearer ${token}`;
}

function sanitizeContentEncodings(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((encoding) => encoding === "aes128gcm" || encoding === "aesgcm")
    .slice(0, 2);
}

function providerName(endpoint) {
  try {
    const host = new URL(endpoint).hostname;
    if (host.includes("googleapis.com")) return "FCM";
    if (host.includes("push.apple.com")) return "APNs";
    if (host.includes("mozilla.com")) return "Mozilla Push";
    if (host.endsWith(".notify.windows.com")) return "WNS";
    return host;
  } catch {
    return "unknown";
  }
}

function isAllowedPushEndpoint(value) {
  if (typeof value !== "string" || value.length > 2048) return false;
  try {
    const url = new URL(value);
    return (
      url.protocol === "https:" &&
      !url.username &&
      !url.password &&
      (!url.port || url.port === "443") &&
      (allowedPushProviders.has(url.hostname) ||
        url.hostname.endsWith(".push.apple.com") ||
        url.hostname.endsWith(".notify.windows.com"))
    );
  } catch {
    return false;
  }
}

function isValidPushKey(value, expectedBytes, requireUncompressedPoint) {
  if (
    typeof value !== "string" ||
    value.length > 128 ||
    !/^[A-Za-z0-9_-]+$/.test(value)
  ) {
    return false;
  }
  try {
    const bytes = base64UrlBytes(value);
    return (
      bytes.length === expectedBytes &&
      (!requireUncompressedPoint || bytes[0] === 4)
    );
  } catch {
    return false;
  }
}

function base64UrlBytes(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function relayRoute(pathname) {
  const roomMatch = /^\/v1\/rooms\/([^/]+)(?:\/(subscription))?$/.exec(
    pathname,
  );
  if (roomMatch) {
    return {
      room: decodeRoomComponent(roomMatch[1]),
      kind: roomMatch[2] || "connection",
    };
  }
  const pushMatch =
    /^\/v1\/push\/([^/]+)(?:\/(subscription|status|receipt))?$/.exec(
      pathname,
    );
  if (!pushMatch) return null;
  return {
    room: decodeRoomComponent(pushMatch[1]),
    kind: pushMatch[2] || "push",
  };
}

function decodeRoomComponent(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return null;
  }
}

function relayMethodError(request, kind) {
  if (kind === "connection") {
    return request.method === "GET" &&
      request.headers.get("Upgrade")?.toLowerCase() === "websocket"
      ? null
      : jsonResponse({ error: "WebSocket required" }, 426);
  }
  const allowed =
    (kind === "push" && request.method === "POST") ||
    (kind === "subscription" &&
      (request.method === "POST" || request.method === "DELETE")) ||
    (kind === "status" && request.method === "GET") ||
    (kind === "receipt" && request.method === "POST");
  return allowed ? null : jsonResponse({ error: "Method not allowed" }, 405);
}

async function enforceGlobalRateLimit(request, env, kind) {
  const address = request.headers.get("CF-Connecting-IP") || "unknown";
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(address),
  );
  const key = Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
  const id = env.RELAY_ROOMS.idFromName(`!dingdong-ip-rate-${key}`);
  const response = await env.RELAY_ROOMS.get(id).fetch(
    new Request("https://dingdong.internal/internal/push-rate-limit", {
      method: "POST",
      headers: {
        "x-dingdong-rate-key": key,
        "x-dingdong-rate-kind": kind,
      },
    }),
  );
  return response.ok ? null : response;
}

const requestBodyTooLarge = Symbol("request-body-too-large");

async function readJsonBody(request, maximumBytes) {
  const declaredLength = Number(request.headers.get("Content-Length"));
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    return requestBodyTooLarge;
  }
  if (!request.body) return null;
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > maximumBytes) {
        await reader.cancel();
        return requestBodyTooLarge;
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  } finally {
    reader.releaseLock();
  }
}

function jsonResponse(value, status = 200) {
  return Response.json(value, {
    status,
    headers: {
      ...corsHeaders,
      ...securityHeaders,
      "Cache-Control": "no-store",
    },
  });
}

export function secureAssetResponse(response) {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(securityHeaders)) {
    headers.set(name, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}
