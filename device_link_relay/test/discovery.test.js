import assert from "node:assert/strict";
import test from "node:test";
import worker, { RelayRoom } from "../src/worker.js";

const pairSlot = "pair-" + "A".repeat(43);
const request = (slot, side, more = "") =>
  new Request(`https://relay.example/v1/discovery/${slot}?side=${side}${more}`, {
    headers: { Upgrade: "websocket" },
  });

function service(t, { enforceLimits = false } = {}) {
  const rateRooms = new Map();
  const rooms = new Map();
  const rateKinds = [];
  const nativeResponse = globalThis.Response;
  t.mock.method(globalThis, "Response", function (body, init) {
    if (init?.status === 101) return init;
    return new nativeResponse(body, init);
  });
  class Socket {
    sent = [];
    readyState = 1;
    serializeAttachment(state) { this.state = structuredClone(state); }
    deserializeAttachment() { return structuredClone(this.state); }
    send(message) {
      assert.equal(this.readyState, 1);
      this.sent.push(JSON.parse(message));
    }
    close(code) { this.readyState = 3; this.code ??= code; }
  }
  class Pair {
    constructor() {
      this[0] = new Socket();
      this[1] = new Socket();
      this[0].server = this[1];
    }
  }
  globalThis.WebSocketPair = Pair;
  t.after(() => { delete globalThis.WebSocketPair; });
  function createRoom() {
    const sockets = new Map();
    const values = new Map();
    const storage = {
      values,
      get: async key => structuredClone(values.get(key)),
      put: async (key, value) => values.set(key, structuredClone(value)),
      delete: async key => values.delete(key),
      setAlarm: async at => { storage.alarm = at; },
      deleteAll: async () => { values.clear(); storage.alarm = null; },
    };
    const ctx = {
      storage,
      acceptWebSocket: (socket, tags) => sockets.set(socket, tags),
      getWebSockets: tag => [...sockets.keys()].filter(socket => sockets.get(socket).includes(tag)),
      getTags: socket => sockets.get(socket),
    };
    return new RelayRoom(ctx, {});
  }
  const env = {
    RELAY_ROOMS: {
      idFromName: name => name,
      get(name) {
        if (name.startsWith("!dingdong-ip-rate-")) return {
          async fetch(req) {
            rateKinds.push(req.headers.get("x-dingdong-rate-kind"));
            if (!enforceLimits) return new nativeResponse(null, { status: 204 });
            if (!rateRooms.has(name)) rateRooms.set(name, createRoom());
            return rateRooms.get(name).fetch(req);
          },
        };
        if (!rooms.has(name)) rooms.set(name, createRoom());
        return rooms.get(name);
      },
    },
  };
  async function connect(slot, side) {
    const response = await worker.fetch(request(slot, side), env);
    assert.equal(response.status, 101);
    return response.webSocket.server;
  }
  return { connect, env, rooms, rateKinds };
}

test("discovery validates exact raw slots and side before selecting a rate-limited namespace", async t => {
  const { connect, env, rooms, rateKinds } = service(t);
  for (const req of [
    request("invite-001234", "peer"),
    request("invite-01%2Fstatus", "peer"),
    request(pairSlot.slice(1), "host"),
    request(pairSlot, "client"),
    request(pairSlot, "host", "&side=peer"),
    request("invite-25", "host", "&code=1234"),
  ]) {
    assert.equal((await worker.fetch(req, env)).status, 400);
  }
  assert.equal((await worker.fetch(new Request(request(pairSlot, "host").url), env)).status, 426);
  assert.deepEqual(rateKinds, []);
  await connect("invite-00", "host");
  await connect("invite-99", "host");
  await connect(pairSlot, "peer");
  assert.deepEqual([...rooms.keys()], ["discovery:invite-00", "discovery:invite-99", "discovery:" + pairSlot]);
  assert.deepEqual(rateKinds, ["invite-host", "invite-host", "connection"]);
});

test("invite admission, transcript order and trial count survive reconnects and hibernation", async t => {
  const { connect, env, rooms } = service(t);
  const slot = "invite-01";
  const status = async side => (await worker.fetch(request(slot, side), env)).status;
  assert.equal(await status("peer"), 404);
  const host = await connect(slot, "host");
  assert.equal(await status("host"), 409);
  let room = rooms.get("discovery:" + slot);
  let peer = await connect(slot, "peer");
  assert.equal(await status("peer"), 409);
  assert.deepEqual(host.sent.map(f => f.event), ["ready", "peer_joined"]);
  assert.deepEqual(peer.sent.map(f => f.event), ["ready", "host_joined"]);
  for (const [from, to, frame] of [
    [peer, host, { type: "hello", a: "abc" }],
    [host, peer, { type: "challenge", b: "de", salt: "salt" }],
    [peer, host, { type: "proof", box: "proof" }],
    [host, peer, { type: "offer", box: "offer" }],
  ]) {
    room.webSocketMessage(from, JSON.stringify(frame));
    assert.deepEqual(to.sent.at(-1), frame);
  }
  room.webSocketMessage(peer, '{"type":"hello","a":"abc"}');
  assert.equal(peer.code, 1008);
  room.webSocketClose(peer);
  assert.equal(host.sent.at(-1).event, "peer_left");
  room = new RelayRoom(room.ctx, {});
  rooms.set("discovery:" + slot, room);
  for (let trial = 2; trial <= 5; trial++) {
    peer = await connect(slot, "peer");
    room.webSocketClose(peer);
  }
  assert.equal(await status("peer"), 429);
  const persisted = [...room.ctx.storage.values.values()];
  assert.deepEqual(persisted, [{
    id: host.deserializeAttachment().leaseId, expiresAt: room.ctx.storage.alarm, trials: 5,
  }]);
});

test("host loss reserves its lease and expiry closes both ends before reusing a slot", async t => {
  t.mock.timers.enable({ apis: ["Date"], now: 1_000_000 });
  const { connect, env, rooms } = service(t);
  const slot = "invite-02";
  const host = await connect(slot, "host");
  const peer = await connect(slot, "peer");
  const room = rooms.get("discovery:" + slot);
  const expiry = room.ctx.storage.alarm;
  assert.equal(expiry, Date.now() + 300_000);
  room.webSocketClose(host);
  assert.equal(peer.sent.at(-1).event, "host_left");
  assert.equal(peer.code, 1008);
  assert.equal((await worker.fetch(request(slot, "peer"), env)).status, 404);
  assert.equal((await worker.fetch(request(slot, "host"), env)).status, 409);
  t.mock.timers.setTime(expiry);
  const nextHost = await connect(slot, "host");
  const nextPeer = await connect(slot, "peer");
  // A queued alarm from the previous lease cannot expire the current one.
  await room.alarm();
  assert.equal(nextHost.readyState, 1);
  t.mock.timers.setTime(room.ctx.storage.alarm);
  // Enforce the deadline even when the scheduled cleanup has not fired yet.
  room.webSocketMessage(nextPeer, '{"type":"hello","a":"ab"}');
  assert.equal(nextPeer.code, 1008);
  assert.equal(nextHost.code, 1008);
  assert.equal(nextHost.sent.at(-1).event, "peer_joined");
  await room.alarm();
  assert.equal(room.ctx.storage.values.size, 0);
});

test("pair replacement ignores stale frames and closes and clears pending challenges", async t => {
  const { connect, rooms } = service(t);
  const peer = await connect(pairSlot, "peer");
  const host = await connect(pairSlot, "host");
  const room = rooms.get("discovery:" + pairSlot);
  const who = '{"type":"who","nonce":"new"}';
  const reply = '{"type":"addresses","box":"sealed"}';
  room.webSocketMessage(host, who);
  const replacement = await connect(pairSlot, "peer");
  assert.equal(peer.code, 1008);
  room.webSocketMessage(peer, reply);
  room.webSocketError(peer);
  room.webSocketClose(peer);
  assert.equal(host.sent.at(-1).event, "peer_joined");
  room.webSocketMessage(replacement, reply);
  assert.equal(replacement.code, 1008);
  const live = await connect(pairSlot, "peer");
  for (const [from, to] of [[host, live], [live, host]]) {
    room.webSocketMessage(from, who);
    assert.deepEqual(to.sent.at(-1), JSON.parse(who));
    room.webSocketMessage(to, reply);
    assert.deepEqual(from.sent.at(-1), JSON.parse(reply));
  }
  assert.equal(room.ctx.storage.values.size, 0);
  room.webSocketClose(live);
  assert.equal(host.sent.at(-1).event, "peer_left");
});

test("discovery rejects payload traffic, extra fields, wrong side, malformed data and oversized frames", async t => {
  const { connect, rooms } = service(t);
  const host = await connect(pairSlot, "host");
  const room = rooms.get("discovery:" + pairSlot);
  for (const [message, expected] of [
    ['{"type":"file","data":"content"}', 1008],
    ['{"type":"who","nonce":"nonce","data":"content"}', 1008],
    ['{"type":"hello","a":"123"}', 1008],
    ['{"type":"relay","event":"host_joined"}', 1008],
    ['{"type":"who","nonce":["abc"]}', 1008],
    ['{"type":"who","nonce":"a b"}', 1008],
    ["null", 1008],
    ["{", 1008],
    [new ArrayBuffer(4), 1003],
    ['{"type":"addresses","box":"' + "界".repeat(1500) + '"}', 1009],
  ]) {
    const peer = await connect(pairSlot, "peer");
    const count = host.sent.length;
    room.webSocketMessage(peer, message);
    assert.equal(peer.code, expected);
    assert.equal(host.sent.length, count);
  }
  const invitedHost = await connect("invite-03", "host");
  for (const frame of [
    { type: "challenge", b: "ab", salt: "abcd" },
    { type: "proof", box: "beforeChallenge" },
    { type: "hello", a: "a".repeat(513) },
    { type: "hello", a: "g" },
    { type: "hello", a: "ff", box: "extra" },
  ]) {
    const peer = await connect("invite-03", "peer");
    rooms.get("discovery:invite-03").webSocketMessage(peer, JSON.stringify(frame));
    assert.equal(peer.code, 1008);
    assert.equal(invitedHost.sent.at(-1).event, "peer_joined");
  }
});

test("discovery frame rate is bounded per socket and recovers after its minute", async t => {
  t.mock.timers.enable({ apis: ["Date"], now: 1_000_000 });
  const { connect, rooms } = service(t);
  const host = await connect(pairSlot, "host");
  const peer = await connect(pairSlot, "peer");
  const room = rooms.get("discovery:" + pairSlot);
  const message = '{"type":"who","nonce":"x"}';
  for (let n = 0; n < 12; n++) room.webSocketMessage(peer, message);
  assert.equal(peer.code, undefined);
  t.mock.timers.tick(60_000);
  for (let n = 0; n < 12; n++) room.webSocketMessage(peer, message);
  assert.equal(peer.code, undefined);
  room.webSocketMessage(peer, message);
  assert.equal(peer.code, 1008);
  assert.equal(host.sent.filter(frame => frame.type === "who").length, 24);
});

test("only explicit release from the current invitation host frees a nameplate immediately", async t => {
  t.mock.timers.enable({ apis: ["Date"], now: 1_000_000 });
  const { connect, env, rooms } = service(t);
  const slot = "invite-24";
  const status = async side => (await worker.fetch(request(slot, side), env)).status;
  const oldHost = await connect(slot, "host");
  const room = rooms.get("discovery:" + slot);
  const peer = await connect(slot, "peer");
  const release = '{"type":"release"}';
  await room.webSocketMessage(peer, release);
  assert.equal(peer.code, 1008);
  assert.equal(await status("host"), 409);
  const oldPeer = await connect(slot, "peer");
  await room.webSocketMessage(oldHost, release);
  assert.equal(oldHost.code, 1000);
  assert.equal(oldPeer.code, 1000);
  assert.equal(room.ctx.storage.values.size, 0);
  assert.equal(room.ctx.storage.alarm, null);
  assert.equal(await status("peer"), 404);

  // Same millisecond: expiry is identical, but the newly claimed lease has
  // a distinct identity and remains live after late callbacks and alarms.
  const newHost = await connect(slot, "host");
  const newPeer = await connect(slot, "peer");
  assert.notEqual(oldHost.state.leaseId, newHost.state.leaseId);
  await room.webSocketMessage(oldHost, release);
  room.webSocketClose(oldHost);
  room.webSocketError(oldPeer);
  await room.alarm();
  assert.equal(newPeer.readyState, 1);
  assert.equal(await status("host"), 409);
  assert.equal(newHost.sent.at(-1).event, "peer_joined");
  room.webSocketMessage(newHost, '{"type":"release","unexpected":true}');
  assert.equal(newHost.code, 1008);
  assert.equal(await status("host"), 409);
});

test("release cannot be used on paired sockets and failed invitation trials preserve the lease", async t => {
  const { connect, env, rooms } = service(t);
  const pairedHost = await connect(pairSlot, "host");
  rooms.get("discovery:" + pairSlot).webSocketMessage(pairedHost, '{"type":"release"}');
  assert.equal(pairedHost.code, 1008);
  const slot = "invite-25";
  const host = await connect(slot, "host");
  const room = rooms.get("discovery:" + slot);
  for (let trial = 0; trial < 5; trial++) {
    const peer = await connect(slot, "peer");
    room.webSocketMessage(peer, '{"type":"proof","box":"outOfOrder"}');
    room.webSocketClose(peer);
  }
  assert.equal((await worker.fetch(request(slot, "peer"), env)).status, 429);
  room.webSocketError(host);
  await room.webSocketMessage(host, '{"type":"release"}');
  assert.equal((await worker.fetch(request(slot, "host"), env)).status, 409);
});


test("invite limits charge attempted public reservations and lookups independently of data connections", async t => {
  const { env } = service(t, { enforceLimits: true });
  const status = async req => (await worker.fetch(req, env)).status;
  const phone = new Request("https://relay.example/v1/rooms/" + "A".repeat(24) + "?side=host", {
    headers: { Upgrade: "websocket" },
  });
  t.mock.timers.enable({ apis: ["Date"], now: 59_999 });
  for (let attempt = 0; attempt < 8; attempt++) {
    assert.equal(await status(request("invite-42", "host")), attempt === 0 ? 101 : 409);
  }
  assert.equal(await status(request("invite-43", "host")), 429);
  for (let attempt = 0; attempt < 15; attempt++) {
    assert.equal(await status(request("invite-99", "peer")), 404);
  }
  assert.equal(await status(request("invite-42", "peer")), 429);

  for (let attempt = 0; attempt < 30; attempt++) {
    assert.equal(await status(phone), 101);
    assert.equal(await status(request(pairSlot, "host")), 101);
  }
  assert.equal(await status(phone), 429);
  assert.equal(await status(request(pairSlot, "host")), 429);
  t.mock.timers.tick(1);
  assert.equal(await status(request("invite-43", "host")), 101);
  assert.equal(await status(request("invite-42", "peer")), 101);
  assert.equal(await status(phone), 101);
});

test("one source cannot preempt all nameplates even across fixed-minute boundaries", async t => {
  const { env } = service(t, { enforceLimits: true });
  t.mock.timers.enable({ apis: ["Date"], now: 59_999 });
  let held = 0;
  for (const now of [59_999, 60_000, 120_000, 180_000, 240_000, 300_000]) {
    t.mock.timers.setTime(now);
    for (let n = 0; n < 8; n++) {
      const slot = "invite-" + String(held).padStart(2, "0");
      assert.equal((await worker.fetch(request(slot, "host"), env)).status, 101);
      held++;
    }
    assert.equal((await worker.fetch(request("invite-99", "host"), env)).status, 429);
  }
  assert.equal(held, 48);
});
