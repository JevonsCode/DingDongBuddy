// Cryptographic envelopes and transport bounds shared by relay and push paths.
const maximumRelayFrameBytes = 256 * 1024;
const maximumEncryptedEnvelopeBytes = maximumRelayFrameBytes;

function relayFrameTooLargeError(
  message = "加密消息超过 256 KB 传输上限，请重新连接后重试",
) {
  const error = new RangeError(message);
  error.code = "relay-frame-too-large";
  return error;
}

function invalidEncryptedEnvelopeError() {
  const error = new TypeError("加密消息格式无效");
  error.code = "invalid-encrypted-envelope";
  return error;
}

function boundedUtf8ByteLength(value, maximumBytes) {
  if (typeof value !== "string") throw invalidEncryptedEnvelopeError();
  // Reject by code-unit length first so a hostile string cannot force an
  // arbitrarily large TextEncoder allocation before the bound is checked.
  if (value.length > maximumBytes) throw relayFrameTooLargeError();
  const bytes = utf8ByteLength(value);
  if (bytes > maximumBytes) throw relayFrameTooLargeError();
  return bytes;
}

function encodedEnvelopeByteLength(envelope) {
  return boundedUtf8ByteLength(envelope, maximumEncryptedEnvelopeBytes);
}

function relayFrameByteLength(frame) {
  return boundedUtf8ByteLength(frame, maximumRelayFrameBytes);
}

async function importAesKey(encoded) {
  return crypto.subtle.importKey(
    "raw",
    base64UrlDecode(encoded),
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
}

async function sealEnvelope(message, key) {
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const clear = new TextEncoder().encode(JSON.stringify(message));
  const encrypted = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, clear),
  );
  const result = new Uint8Array(nonce.length + encrypted.length);
  result.set(nonce, 0);
  result.set(encrypted, nonce.length);
  return base64UrlEncode(result);
}

async function openEnvelope(envelope, key) {
  encodedEnvelopeByteLength(envelope);
  const value = base64UrlDecode(envelope);
  if (value.byteLength < 12 + 16) throw invalidEncryptedEnvelopeError();
  const nonce = value.slice(0, 12);
  const encrypted = value.slice(12);
  const clear = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: nonce },
    key,
    encrypted,
  );
  return JSON.parse(new TextDecoder().decode(clear));
}

async function pushToken(secret) {
  const key = await crypto.subtle.importKey(
    "raw",
    base64UrlDecode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return base64UrlEncode(
    new Uint8Array(
      await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode("dingdong-push-v1"),
      ),
    ),
  );
}

function base64UrlEncode(bytes) {
  return bytesToBase64(bytes)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64UrlDecode(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function bytesToBase64(bytes) {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000));
  }
  return btoa(binary);
}

function utf8ByteLength(value) {
  return new TextEncoder().encode(value).byteLength;
}

function encodeRelayFrame(type, envelope) {
  const frame = JSON.stringify({ type, payload: envelope });
  if (utf8ByteLength(frame) > maximumRelayFrameBytes) {
    throw relayFrameTooLargeError("内容加密后超过传输上限，请改为选择文件发送");
  }
  return frame;
}

function apiUrl(base, path) {
  const url = new URL(base);
  url.pathname = `${url.pathname.replace(/\/$/, "")}/${path}`;
  url.search = "";
  url.hash = "";
  return url.toString();
}

async function withTimeout(promise, timeoutMs, message) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(message)), timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

async function fetchWithTimeout(input, init, timeoutMs, message) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) throw new Error(message);
    throw error;
  } finally {
    clearTimeout(timer);
  }
}


export {
  apiUrl,
  base64UrlDecode,
  bytesToBase64,
  encodedEnvelopeByteLength,
  encodeRelayFrame,
  fetchWithTimeout,
  importAesKey,
  maximumEncryptedEnvelopeBytes,
  maximumRelayFrameBytes,
  openEnvelope,
  pushToken,
  relayFrameByteLength,
  sealEnvelope,
  utf8ByteLength,
  withTimeout,
};
