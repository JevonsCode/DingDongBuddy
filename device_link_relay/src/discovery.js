const leaseKey = "invite-lease";
const leaseDuration = 5 * 60 * 1000;
const maxTrials = 5;
const maxFrameBytes = 4096;
const maxFramesPerMinute = 12;
const exchange = ["hello", "challenge", "proof", "offer"];
const hex = /^[a-f\d]{1,512}$/i;
const base64url = /^[A-Za-z0-9_-]+$/;
const shortBase64url = /^[A-Za-z0-9_-]{1,128}$/;
const inviteFrames = {
  host: { challenge: { b: hex, salt: shortBase64url }, offer: { box: base64url }, release: {} },
  peer: { hello: { a: hex }, proof: { box: base64url } },
};
const pairFrames = { who: { nonce: shortBase64url }, addresses: { box: base64url } };

export function isDiscoverySlot(slot) {
  return /^(?:invite-\d{2}|pair-[A-Za-z0-9_-]{43})$/.test(slot);
}

function activeSocket(ctx, side) {
  return ctx.getWebSockets(side).find(socket => socket.readyState === 1 &&
    !socket.deserializeAttachment()?.retired);
}

function opposite(side) {
  return side === "host" ? "peer" : "host";
}

function send(socket, frame) {
  try {
    socket.send(JSON.stringify(frame));
  } catch {
    // The transport may already have failed before its close event arrives.
  }
}

function notify(socket, event) {
  if (socket) send(socket, { type: "relay", event });
}

function retire(socket, reason, code = 1008) {
  try {
    socket.serializeAttachment({ ...socket.deserializeAttachment(), retired: true });
  } catch {
    // The attachment disappears when the runtime detaches a closed socket.
  }
  try {
    socket.close(code, reason);
  } catch {
    // A detached socket has already closed.
  }
}

function closeAll(ctx, reason) {
  for (const socket of ctx.getWebSockets("discovery")) {
    retire(socket, reason);
  }
}

export async function expireDiscoveryLease(ctx) {
  const lease = await ctx.storage.get(leaseKey);
  if (!lease) return false;
  if (lease.expiresAt > Date.now()) {
    // An already-dispatched alarm may belong to the previous lease.
    await ctx.storage.setAlarm(lease.expiresAt);
    return true;
  }
  closeAll(ctx, "Invitation expired");
  await ctx.storage.delete(leaseKey);
  return true;
}

export async function discoveryUpgrade(ctx, url) {
  const invite = url.pathname.startsWith("/v1/discovery/invite-");
  const side = url.searchParams.get("side");
  let expiresAt = null;
  let leaseId = null;
  if (invite) {
    let lease = await ctx.storage.get(leaseKey);
    if (lease && lease.expiresAt <= Date.now()) {
      closeAll(ctx, "Invitation expired");
      await ctx.storage.delete(leaseKey);
      lease = null;
    }
    if (side === "host") {
      if (lease) return new Response("Invitation reserved", { status: 409 });
      lease = { id: crypto.randomUUID(), expiresAt: Date.now() + leaseDuration, trials: 0 };
      await ctx.storage.setAlarm(lease.expiresAt);
    } else {
      if (!lease || !activeSocket(ctx, "host")) {
        return new Response("Host unavailable", { status: 404 });
      }
      if (activeSocket(ctx, "peer")) return new Response("Peer present", { status: 409 });
      if (lease.trials >= maxTrials) return new Response("Trial limit reached", { status: 429 });
      lease.trials++;
    }
    expiresAt = lease.expiresAt;
    leaseId = lease.id;
    await ctx.storage.put(leaseKey, lease);
  }
  // Closing connections can still be listed and deliver queued callbacks.
  // Mark them before accepting a replacement so they cannot announce a departure.
  for (const previous of ctx.getWebSockets(side)) retire(previous, "Connection replaced");

  const [client, server] = Object.values(new WebSocketPair());
  ctx.acceptWebSocket(server, [side, "discovery"]);
  server.serializeAttachment({ side, expiresAt, leaseId, step: 0 });
  notify(server, "ready");

  const partner = activeSocket(ctx, opposite(side));
  if (partner) {
    const state = partner.deserializeAttachment();
    partner.serializeAttachment({ ...state, awaitingAddresses: false });
    notify(partner, `${side}_joined`);
    notify(server, `${opposite(side)}_joined`);
  }
  return new Response(null, { status: 101, webSocket: client });
}

function parseFrame(message, invite, side) {
  if (typeof message !== "string") return null;
  let frame;
  try {
    frame = JSON.parse(message);
  } catch {
    return null;
  }
  const allowed = invite ? inviteFrames[side] : pairFrames;
  if (typeof frame?.type !== "string" || !Object.hasOwn(allowed, frame.type)) return null;
  const fields = Object.entries(allowed[frame.type]);
  if (Object.keys(frame).length !== fields.length + 1) return null;
  for (const [key, pattern] of fields) {
    if (typeof frame[key] !== "string" || !pattern.test(frame[key])) return null;
  }
  return frame;
}

async function releaseInvite(ctx, leaseId) {
  const lease = await ctx.storage.get(leaseKey);
  if (!leaseId || lease?.id !== leaseId) return;
  // Each invitation has its own DO. This removes the lease and its alarm
  // atomically. Input gates serialize this read/write against other admissions.
  const cleanup = ctx.storage.deleteAll();
  for (const socket of ctx.getWebSockets("discovery")) {
    if (socket.deserializeAttachment()?.leaseId === leaseId) {
      retire(socket, "Invitation released", 1000);
    }
  }
  await cleanup;
}

export function discoveryMessage(ctx, socket, message) {
  const source = socket.deserializeAttachment();
  if (!source || source.retired || activeSocket(ctx, source.side) !== socket) return;
  const now = Date.now();
  const invite = source.expiresAt != null;
  if (invite && source.expiresAt <= now) {
    closeAll(ctx, "Invitation expired");
    return;
  }
  if (typeof message !== "string") {
    socket.close(1003, "Text frame required");
    return;
  }
  if (message.length > maxFrameBytes || new TextEncoder().encode(message).length > maxFrameBytes) {
    socket.close(1009, "Frame too large");
    return;
  }
  const frame = parseFrame(message, invite, source.side);
  if (!frame) {
    socket.close(1008, "Invalid discovery frame");
    return;
  }
  if (source.windowStart == null || now - source.windowStart >= 60_000) {
    source.windowStart = now;
    source.frames = 0;
  }
  if (++source.frames > maxFramesPerMinute) {
    socket.close(1008, "Frame rate limit");
    return;
  }
  socket.serializeAttachment(source);
  if (frame.type === "release") return releaseInvite(ctx, source.leaseId);
  const partner = activeSocket(ctx, opposite(source.side));
  if (!partner) return;
  if (invite) {
    // Keep the transcript position on the trial socket so reconnecting starts
    // a fresh exchange and each admission can make only one password guess.
    const peer = source.side === "peer" ? socket : partner;
    const trial = peer.deserializeAttachment();
    if (exchange[trial.step] !== frame.type) {
      socket.close(1008, "Unexpected exchange step");
      return;
    }
    peer.serializeAttachment({ ...trial, step: trial.step + 1 });
  } else if (frame.type === "who") {
    source.awaitingAddresses = true;
    socket.serializeAttachment(source);
  } else {
    const requester = partner.deserializeAttachment();
    if (!requester.awaitingAddresses) {
      socket.close(1008, "No address request");
      return;
    }
    partner.serializeAttachment({ ...requester, awaitingAddresses: false });
  }
  // Normalize validated JSON so duplicate or shadowed fields never leave the relay.
  send(partner, frame);
}

export function discoveryClosed(ctx, socket) {
  const state = socket.deserializeAttachment();
  if (!state || state.retired) return;
  retire(socket, "Connection ended");
  const replacement = activeSocket(ctx, state.side);
  if (replacement) return;
  const partner = activeSocket(ctx, opposite(state.side));
  if (!partner) return;
  notify(partner, `${state.side}_left`);
  if (state.expiresAt != null && state.side === "host") retire(partner, "Host left");
}
