// Stand-in for the DingDong desktop's relay host, for testing the Android
// companion without the desktop UI. It speaks the real device-link protocol
// (docs/app/app-codecs.js envelopes over the production relay) with message
// shapes taken from lib/features/device_link/ui/device_link_*.dart.
//
// Usage:
//   node mobile/tool/fake_desktop_host.mjs --state <file.json>
//        [--relay https://dingdong.xn--m8txu.com] [--seconds 120]
//        [--sequence clipboard,completion,attention,silent,state]
//        [--out <dir>]   (where files sent by the phone are written)
//        [--every-hello 1]  (replay the sequence after every reconnect)
//        [--host-relay <url>]  (the host's own relay URL when the phone needs
//                               a different address, e.g. an emulator's 10.0.2.2)
//
// The state file keeps the room and secret, so a second run reuses the same
// pairing (to test reconnects). The pairing link is printed on start, and
// every message from the phone is logged as `phone -> {...}`.
import { createHash, randomBytes, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
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
const sequence = (args.sequence ?? "clipboard,completion,attention,silent,state")
  .split(",")
  .filter(Boolean);
const statePath = args.state;
const outDir = args.out;
const everyHello = Boolean(args["every-hello"]);
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
// Same field names as DevicePairingPayload.encode() on the desktop.
const pair = { v: 1, room: state.room, secret: state.secret, hostId: state.hostId, hostName: state.hostName, relay };
const link = `${relay}/app/#pair=${base64Url(new TextEncoder().encode(JSON.stringify(pair)))}`;
console.log(`PAIRING_LINK ${link}`);

const key = await importAesKey(state.secret);
const url = new URL(args["host-relay"] || relay);
url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
url.pathname = `/v1/rooms/${state.room}`;
url.search = "?side=host";
const log = (...values) => console.log(new Date().toISOString(), ...values);
const uploads = new Map();
const sharedFile = new TextEncoder().encode("DingDong 文件下载测试\n".repeat(4000));
let socket;
let sequenceStarted = false;

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
    detail: attention ? "迁移会修改 3 张表，确认后继续。" : "共 214 个测试通过，耗时 41 秒。",
    task: kind === "silent" ? "静默提醒（不应弹出通知）" : "Android 伴侣联调",
    notificationKind: attention ? "attention" : "completion",
    needsUserAttention: attention,
    unseen: true,
    startedAt: new Date(Date.now() - 95_000).toISOString(),
    completedAt: new Date().toISOString(),
    workspacePath: "T:\\workspace\\dingdong",
    vibrate: true,
    ...(kind === "silent" ? { silent: true } : {}),
  };
}

const steps = {
  async clipboard() {
    await send({ type: "clipboard.snapshot", items: [] });
    const now = new Date().toISOString();
    await send({
      type: "clipboard.upsert",
      manual: true,
      item: {
        id: "fake-text", title: "构建命令", kind: "command", sensitive: false,
        createdAt: now, updatedAt: now, sources: ["终端"],
        content: "cd mobile && flutter build apk --debug",
      },
    });
    await send({
      type: "clipboard.upsert",
      manual: false,
      item: {
        id: "fake-file", title: "下载测试.txt", kind: "file", sensitive: false,
        createdAt: now, updatedAt: now, sources: ["访达"],
        fileName: "下载测试.txt", fileSize: sharedFile.byteLength, downloadable: true,
      },
    });
  },
  completion: () => send(agentEvent("completion")),
  attention: () => send(agentEvent("attention")),
  silent: () => send(agentEvent("silent")),
  state: () =>
    send({
      type: "agent.state",
      generatedAt: new Date().toISOString(),
      running: [{ id: "run-1", source: "Codex", task: "整理 Android 伴侣的测试报告", startedAt: new Date(Date.now() - 300_000).toISOString(), workspacePath: "T:\\workspace\\dingdong" }],
      completed: [],
    }),
};

async function sendRequestedFile(itemId) {
  const transferId = `download-${randomUUID()}`;
  await send({ type: "file.start", transferId, itemId, name: "下载测试.txt", size: sharedFile.byteLength, mime: "text/plain" });
  let index = 0;
  for (let offset = 0; offset < sharedFile.byteLength; offset += 32 * 1024) {
    await send({ type: "file.chunk", transferId, index, data: bytesToBase64(sharedFile.subarray(offset, offset + 32 * 1024)) });
    index += 1;
  }
  await send({ type: "file.end", transferId });
  log("served file", itemId, sharedFile.byteLength, "bytes");
}

async function handlePhone(message) {
  const summary = { ...message };
  if (summary.type === "file.chunk") summary.data = `<${summary.data.length} b64 chars>`;
  log("phone ->", JSON.stringify(summary).slice(0, 400));
  switch (message.type) {
    case "hello":
      await send({
        type: "welcome",
        host: { id: state.hostId, name: state.hostName, kind: "computer", platform: "windows" },
        permissions: { autoSendClipboard: false, receiveAgentNotifications: true, transportPreference: "automatic" },
      });
      if (!sequenceStarted || everyHello) {
        sequenceStarted = true;
        sequence.forEach((step, index) =>
          setTimeout(async () => {
            await steps[step]?.();
            log("sent", step);
          }, 2500 + index * 4000),
        );
      }
      break;
    case "file.request":
      await sendRequestedFile(message.itemId);
      break;
    case "file.start":
      uploads.set(message.transferId, { name: message.name, size: message.size, parts: [] });
      break;
    case "file.chunk":
      uploads.get(message.transferId)?.parts.push(Buffer.from(message.data, "base64"));
      break;
    case "file.end": {
      const upload = uploads.get(message.transferId);
      if (!upload) break;
      const bytes = Buffer.concat(upload.parts);
      log("received file", upload.name, bytes.length, "of", upload.size, "bytes sha256", createHash("sha256").update(bytes).digest("hex"));
      if (outDir) {
        mkdirSync(outDir, { recursive: true });
        writeFileSync(join(outDir, upload.name), bytes);
      }
      break;
    }
  }
}

function connect() {
  socket = new WebSocket(url);
  socket.addEventListener("open", () => log("relay open", url.pathname));
  socket.addEventListener("close", (event) => log("relay closed", event.code, event.reason));
  socket.addEventListener("message", async (event) => {
    const frame = JSON.parse(event.data);
    if (frame.type === "relay") {
      log("relay event", frame.event);
      return;
    }
    if (frame.type !== "data") return;
    await handlePhone(await openEnvelope(frame.payload, key));
  });
}

connect();
setTimeout(() => {
  socket.close(1000, "Fake host finished");
  setTimeout(() => process.exit(0), 500);
}, seconds * 1000);
