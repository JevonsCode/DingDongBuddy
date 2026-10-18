// Stand-in for the DingDong desktop's relay host, for testing the Android
// companion without clicking through the desktop UI. It speaks the real
// device-link protocol (docs/app/app-codecs.js envelopes over the relay) and
// sends agent.completed events shaped like device_link_controller.dart.
//
// Usage:
//   node android_companion/tools/fake_desktop_host.mjs --state <file.json>
//        [--relay https://dingdong.xn--m8txu.com] [--seconds 120]
//        [--sequence completion,attention,silent]
//
// The state file keeps the room and secret so a second run reuses the same
// pairing (to test reconnects). The pairing link is printed on start.
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { randomBytes, randomUUID } from "node:crypto";
import {
  base64UrlDecode,
  bytesToBase64,
  importAesKey,
  openEnvelope,
  sealEnvelope,
} from "../../docs/app/app-codecs.js";

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, value, index, all) => {
    if (value.startsWith("--")) pairs.push([value.slice(2), all[index + 1]]);
    return pairs;
  }, []),
);
const relay = args.relay || "https://dingdong.xn--m8txu.com";
const seconds = Number(args.seconds || 120);
const sequence = (args.sequence || "completion,attention,silent").split(",").filter(Boolean);
const statePath = args.state;
if (!statePath) throw new Error("--state <file.json> is required");

const base64Url = (bytes) =>
  bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const state = existsSync(statePath)
  ? JSON.parse(readFileSync(statePath, "utf8"))
  : {
      room: base64Url(randomBytes(18)),
      secret: base64Url(randomBytes(32)),
      hostId: randomUUID(),
      hostName: "DingDong 测试电脑",
    };
writeFileSync(statePath, JSON.stringify(state, null, 2));
const pair = { version: 1, relay, ...state };
const link = `${relay}/app/#pair=${base64Url(new TextEncoder().encode(JSON.stringify(pair)))}`;
console.log(`PAIRING_LINK ${link}`);

const key = await importAesKey(state.secret);
if (base64UrlDecode(state.secret).byteLength !== 32) throw new Error("bad secret");
const url = new URL(relay);
url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
url.pathname = `/v1/rooms/${state.room}`;
url.search = "?side=host";
const socket = new WebSocket(url);
const log = (...values) => console.log(new Date().toISOString(), ...values);
let sent = false;

async function send(message) {
  socket.send(JSON.stringify({ type: "data", payload: await sealEnvelope(message, key) }));
}

function agentEvent(kind) {
  const attention = kind === "attention";
  return {
    type: "agent.completed",
    id: `fake-${kind}-${Date.now()}`,
    activityId: randomUUID(),
    title: attention ? "Agent 需要你处理" : "Agent 完成啦",
    source: "Claude Code",
    summary: attention ? "需要你确认是否继续执行迁移。" : "测试全部通过，改动已提交。",
    detail: attention ? "需要你确认是否继续执行迁移。" : "测试全部通过，改动已提交。",
    task: kind === "silent" ? "静默提醒（不应弹出通知）" : "Android 伴侣联调",
    notificationKind: attention ? "attention" : "completion",
    needsUserAttention: attention,
    unseen: true,
    completedAt: new Date().toISOString(),
    vibrate: true,
    ...(kind === "silent" ? { silent: true } : {}),
  };
}

socket.addEventListener("open", () => log("relay open", url.pathname));
socket.addEventListener("close", (event) => log("relay closed", event.code, event.reason));
socket.addEventListener("message", async (event) => {
  const frame = JSON.parse(event.data);
  if (frame.type === "relay") {
    log("relay event", frame.event);
    return;
  }
  if (frame.type !== "data") return;
  const message = await openEnvelope(frame.payload, key);
  log("phone ->", JSON.stringify(message));
  if (message.type === "hello") {
    await send({
      type: "welcome",
      fileTransferVersion: 2,
      host: { id: state.hostId, name: state.hostName, kind: "computer", platform: "windows" },
      permissions: { autoSendClipboard: false, receiveAgentNotifications: true, transportPreference: "automatic" },
    });
    if (sent) return;
    sent = true;
    sequence.forEach((kind, index) => {
      setTimeout(async () => {
        const payload = agentEvent(kind);
        await send(payload);
        log("sent", kind, payload.id);
      }, 2500 + index * 4000);
    });
  }
});

setTimeout(() => {
  socket.close(1000, "Fake host finished");
  setTimeout(() => process.exit(0), 500);
}, seconds * 1000);
