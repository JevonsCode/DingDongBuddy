import assert from "node:assert/strict";
import test from "node:test";

import { RelayRoom, broadcast } from "../src/worker.js";

// A phone that loses its network without a TCP close leaves its socket in
// the Durable Object until Cloudflare notices. Found 2026-10-19 with the
// Android companion: after a Wi-Fi drop the reconnected phone sent `hello`,
// but the desktop's `welcome` and every later frame threw on the stale socket
// first and never reached the live one.

function liveSocket(side) {
  const sent = [];
  return {
    sent,
    send: (message) => sent.push(message),
    close: () => {},
    serializeAttachment: () => {},
    deserializeAttachment: () => ({ side }),
  };
}

function staleSocket(side) {
  const fail = () => {
    throw new TypeError("WebSocket is already closed");
  };
  return {
    send: fail,
    close: fail,
    serializeAttachment: fail,
    deserializeAttachment: () => ({ side }),
  };
}

function roomWith(sockets) {
  return new RelayRoom(
    {
      storage: {},
      getWebSockets: (tag) => sockets.filter((s) => s.deserializeAttachment().side === tag),
    },
    {},
  );
}

test("broadcast skips a stale socket and still reaches the live one", () => {
  const live = liveSocket("peer");
  assert.equal(broadcast([staleSocket("peer"), live], "frame"), 1);
  assert.deepEqual(live.sent, ["frame"]);
});

test("host frames reach the reconnected peer past its stale predecessor", () => {
  const host = liveSocket("host");
  const reconnected = liveSocket("peer");
  const room = roomWith([host, staleSocket("peer"), reconnected]);
  room.webSocketMessage(host, '{"type":"data","payload":"welcome"}');
  assert.deepEqual(reconnected.sent, ['{"type":"data","payload":"welcome"}']);
});

test("closing a peer still tells the host even with a stale host listed", () => {
  const host = liveSocket("host");
  const room = roomWith([staleSocket("host"), host]);
  room.webSocketClose(liveSocket("peer"));
  assert.deepEqual(host.sent, ['{"type":"relay","event":"peer_left"}']);
});
