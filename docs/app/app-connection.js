import {
  relayConnectionWasReplaced,
  shouldReconnectRelay,
} from "./connection-policy.js";
import { pairingsMatch } from "./pairing-state.js?shell=41";
import { wantsAgentNotifications } from "./notification-policy.js?shell=41";
import {
  encodedEnvelopeByteLength,
  encodeRelayFrame,
  importAesKey,
  maximumRelayFrameBytes,
  openEnvelope,
  relayFrameByteLength,
  sealEnvelope,
} from "./app-codecs.js?shell=41";

// Encrypted relay/WebRTC lifecycle and ordered inbound message dispatch.
export const maximumQueuedInboundEntries = 256;
export const maximumQueuedInboundBytes = maximumRelayFrameBytes * 32;
export const maximumPendingRemoteCandidates = 256;
export const maximumPendingRemoteCandidateBytes = maximumRelayFrameBytes * 4;

export function createConnectionController({
  state,
  initialReconnectDelayMs,
  maximumReconnectDelayMs,
  activeSession,
  render,
  savePairings,
  notificationPermission,
  sendSettings,
  receiveClipboardSnapshot,
  upsertClipboardItem,
  handleRequestRejected,
  receiveAgentEvent,
  receiveAgentState,
  beginDownload,
  receiveDownloadChunk,
  finishDownload,
  clearDownloads,
  showToast = () => {},
}) {
  async function connect(session = activeSession()) {
    if (
      !session ||
      session.connecting ||
      session.socket?.readyState === WebSocket.OPEN ||
      session.socket?.readyState === WebSocket.CONNECTING
    ) {
      return;
    }
    clearTimeout(session.reconnectTimer);
    const pair = { ...session.pair };
    const connectionGeneration = session.connectionGeneration;
    const relayGeneration = session.relayGeneration + 1;
    session.relayGeneration = relayGeneration;
    session.connecting = !session.connected;
    session.relayHostPresent = false;
    session.helloSent = false;
    session.connectionSuperseded = false;
    session.pair.manualDisconnect = false;
    render();
    const attempt = { session, pair, connectionGeneration, relayGeneration };
    try {
      const key = await importAesKey(pair.secret);
      if (!relayAttemptIsCurrent(attempt)) return;
      session.signalKey = key;
      const relay = new URL(pair.relay);
      relay.protocol = relay.protocol === "https:" ? "wss:" : "ws:";
      relay.pathname = `${relay.pathname.replace(/\/$/, "")}/v1/rooms/${encodeURIComponent(
        pair.room,
      )}`;
      relay.search = "?side=peer";
      const socket = new WebSocket(relay);
      const context = { ...attempt, key, socket };
      session.socket = socket;
      const relayQueue = resetRelayQueue(session);
      context.relayQueue = relayQueue;
      socket.addEventListener("message", (event) => {
        // The bounded queue serializes handleRelayFrame(event.data, context).
        queueRelayFrame(event.data, context);
      });
      socket.addEventListener("close", (event) => {
        if (!relayContextIsCurrent(context)) return;
        session.socket = null;
        resetRelayQueue(session);
        session.relayHostPresent = false;
        session.connecting = false;
        session.connected = session.channel?.readyState === "open";
        session.connectionSuperseded = relayConnectionWasReplaced(event);
        if (!session.connected) clearDisconnectedContent(session);
        render();
        if (shouldReconnectRelay(event, session.pair)) {
          const reconnectDelay = session.reconnectDelayMs;
          session.reconnectTimer = setTimeout(
            () => connect(session),
            reconnectDelay,
          );
          session.reconnectDelayMs = Math.min(
            maximumReconnectDelayMs,
            Math.round(reconnectDelay * 1.7),
          );
        }
      });
      socket.addEventListener("error", (error) =>
        connectionErrorForContext(error, context),
      );
    } catch (error) {
      connectionErrorForContext(error, attempt);
    }
  }

  function sessionContextIsCurrent(context) {
    const session = context?.session;
    return (
      Boolean(session) &&
      state.sessions.get(context.pair?.room) === session &&
      context.connectionGeneration === session.connectionGeneration &&
      (context.contentGeneration === undefined ||
        context.contentGeneration === session.contentGeneration) &&
      pairingsMatch(context.pair, session.pair)
    );
  }

  function relayAttemptIsCurrent(context) {
    return (
      sessionContextIsCurrent(context) &&
      context.relayGeneration === context.session.relayGeneration
    );
  }

  function relayContextIsCurrent(context) {
    return (
      relayAttemptIsCurrent(context) && context.session.socket === context.socket
    );
  }

  function peerContextIsCurrent(context) {
    return (
      sessionContextIsCurrent(context) && context.session.peer === context.peer
    );
  }

  function channelContextIsCurrent(context) {
    return (
      sessionContextIsCurrent(context) &&
      context.session.channel === context.channel
    );
  }

  function connectionContextIsCurrent(context) {
    if (!sessionContextIsCurrent(context)) return false;
    const session = context.session;
    if (context.socket && session.socket !== context.socket) return false;
    if (context.peer && session.peer !== context.peer) return false;
    if (context.channel && session.channel !== context.channel) return false;
    return true;
  }

  function connectionErrorForContext(error, context) {
    if (!connectionContextIsCurrent(context)) return;
    connectionError(error, context.session);
  }

  function createQueueState(chain = Promise.resolve()) {
    const queue = {
      chain,
      count: 0,
      bytes: 0,
      entries: new Set(),
      cancelled: false,
    };
    queue.cancel = () => {
      queue.cancelled = true;
      for (const entry of queue.entries) entry.payload = null;
    };
    return queue;
  }

  function resetRelayQueue(session) {
    session.relayQueue?.cancel?.();
    const queue = createQueueState();
    session.relayQueue = queue;
    session.relayFrames = queue.chain;
    return queue;
  }

  function resetIncomingQueue(session) {
    session.incomingQueue?.cancel?.();
    const queue = createQueueState();
    session.incomingQueue = queue;
    session.incomingMessages = queue.chain;
    return queue;
  }

  function incomingQueueFor(session) {
    const chain = session.incomingMessages || Promise.resolve();
    if (session.incomingQueue?.chain === chain) return session.incomingQueue;
    session.incomingQueue?.cancel?.();
    const queue = createQueueState(chain);
    session.incomingQueue = queue;
    return queue;
  }

  function releaseQueueBudget(queue, bytes) {
    queue.count = Math.max(0, queue.count - 1);
    queue.bytes = Math.max(0, queue.bytes - bytes);
  }

  function inboundQueueOverflowError() {
    const error = new Error("连接消息队列已满");
    error.code = "inbound-queue-overflow";
    return error;
  }

  function closeForInboundLimit(error, context) {
    if (!connectionContextIsCurrent(context)) return;
    const message =
      error?.code === "relay-frame-too-large"
        ? "收到的连接消息超过 256 KB，已断开，请重新连接"
        : "连接消息过多，已断开，请重新连接";
    showToast(message);
    closeConnection(context.session);
    render();
  }

  function queueRelayFrame(raw, context) {
    if (!relayContextIsCurrent(context)) return;
    let bytes;
    try {
      bytes = relayFrameByteLength(raw);
    } catch (error) {
      closeForInboundLimit(error, context);
      return;
    }
    const session = context.session;
    const queue = context.relayQueue;
    if (!queue || session.relayQueue !== queue) return;
    if (
      queue.count >= maximumQueuedInboundEntries ||
      queue.bytes + bytes > maximumQueuedInboundBytes
    ) {
      closeForInboundLimit(inboundQueueOverflowError(), context);
      return;
    }
    queue.count += 1;
    queue.bytes += bytes;
    const entry = { payload: raw, bytes };
    queue.entries.add(entry);
    session.relayFrames = session.relayFrames
      .then(() => {
        if (queue.cancelled || entry.payload === null) return;
        return relayContextIsCurrent(context)
          ? handleRelayFrame(entry.payload, context)
          : undefined;
      })
      .catch((error) => connectionErrorForContext(error, context))
      .finally(() => {
        queue.entries.delete(entry);
        entry.payload = null;
        releaseQueueBudget(queue, entry.bytes);
      });
    queue.chain = session.relayFrames;
  }

  function sessionContextFrom(context) {
    return {
      session: context.session,
      pair: context.pair,
      key: context.key,
      connectionGeneration: context.connectionGeneration,
    };
  }

  async function handleRelayFrame(raw, context) {
    if (!relayContextIsCurrent(context)) return;
    const session = context.session;
    const frame = JSON.parse(raw);
    if (frame.type === "relay") {
      if (frame.event === "ready" && !session.connected && !session.relayHostPresent) {
        // The relay is reachable; a missing host is an offline computer, not
        // an indefinitely pending connection attempt.
        session.connecting = false;
        render();
      }
      if (frame.event === "host_joined") {
        session.relayHostPresent = true;
        await markConnected(sessionContextFrom(context));
      }
      if (frame.event === "host_left") {
        if (!relayContextIsCurrent(context)) return;
        session.relayHostPresent = false;
        session.helloSent = false;
        session.connected = session.channel?.readyState === "open";
        if (!session.connected) clearDisconnectedContent(session);
        render();
      }
      return;
    }
    if (frame.type === "data" && typeof frame.payload === "string") {
      queueIncomingEnvelope(frame.payload, context);
      return;
    }
    if (frame.type !== "signal" || typeof frame.payload !== "string") return;
    let signal;
    try {
      signal = await openEnvelope(frame.payload, context.key);
    } catch (error) {
      if (error?.code === "relay-frame-too-large") {
        closeForInboundLimit(error, context);
        return;
      }
      throw error;
    }
    if (!relayContextIsCurrent(context)) return;
    if (signal.type === "offer") {
      await acceptOffer(signal, context);
    } else if (signal.type === "candidate") {
      const candidate = new RTCIceCandidate({
        candidate: signal.candidate,
        sdpMid: signal.sdpMid,
        sdpMLineIndex: signal.sdpMLineIndex,
      });
      const peer = session.peer;
      if (peer?.remoteDescription) {
        await peer.addIceCandidate(candidate);
      } else {
        let candidateBytes;
        try {
          candidateBytes = relayFrameByteLength(
            JSON.stringify({
              candidate: signal.candidate,
              sdpMid: signal.sdpMid,
              sdpMLineIndex: signal.sdpMLineIndex,
            }),
          );
        } catch (error) {
          closeForInboundLimit(error, context);
          return;
        }
        if (
          session.remoteCandidates.length >= maximumPendingRemoteCandidates ||
          (session.remoteCandidateBytes || 0) + candidateBytes >
            maximumPendingRemoteCandidateBytes
        ) {
          closeForInboundLimit(inboundQueueOverflowError(), context);
          return;
        }
        session.remoteCandidates.push(candidate);
        session.remoteCandidateBytes =
          (session.remoteCandidateBytes || 0) + candidateBytes;
      }
    }
  }

  async function acceptOffer(signal, relayContext) {
    if (!relayContextIsCurrent(relayContext)) return;
    const session = relayContext.session;
    closePeer(session);
    const peer = new RTCPeerConnection({ iceServers: [] });
    session.peer = peer;
    const context = { ...sessionContextFrom(relayContext), peer };
    peer.addEventListener("icecandidate", (event) => {
      if (
        !event.candidate ||
        !peerContextIsCurrent(context) ||
        !relayContextIsCurrent(relayContext)
      ) {
        return;
      }
      sendSignal(
        {
          type: "candidate",
          candidate: event.candidate.candidate,
          sdpMid: event.candidate.sdpMid,
          sdpMLineIndex: event.candidate.sdpMLineIndex,
        },
        relayContext,
        peer,
      ).catch((error) => connectionErrorForContext(error, context));
    });
    peer.addEventListener("datachannel", (event) => {
      if (!peerContextIsCurrent(context)) return;
      attachDataChannel(event.channel, context);
    });
    peer.addEventListener("connectionstatechange", () => {
      if (!peerContextIsCurrent(context)) return;
      if (["failed", "disconnected", "closed"].includes(peer.connectionState)) {
        session.connected =
          session.relayHostPresent &&
          session.socket?.readyState === WebSocket.OPEN;
        if (!session.connected) clearDisconnectedContent(session);
        render();
      }
    });
    await peer.setRemoteDescription({
      type: signal.sdpType || "offer",
      sdp: signal.sdp,
    });
    if (!peerContextIsCurrent(context) || !relayContextIsCurrent(relayContext)) {
      return;
    }
    const pendingCandidates = session.remoteCandidates.splice(0);
    session.remoteCandidateBytes = 0;
    for (const candidate of pendingCandidates) {
      await peer.addIceCandidate(candidate);
      if (!peerContextIsCurrent(context)) return;
    }
    const answer = await peer.createAnswer();
    if (!peerContextIsCurrent(context)) return;
    await peer.setLocalDescription(answer);
    if (!peerContextIsCurrent(context) || !relayContextIsCurrent(relayContext)) {
      return;
    }
    await sendSignal(
      {
        type: "answer",
        sdp: answer.sdp,
        sdpType: answer.type,
      },
      relayContext,
      peer,
    );
  }

  function attachDataChannel(channel, peerContext) {
    const session = peerContext.session;
    session.channel = channel;
    const context = { ...peerContext, channel };
    channel.addEventListener("open", () => {
      if (!channelContextIsCurrent(context)) return;
      markConnected(sessionContextFrom(context)).catch((error) =>
        connectionErrorForContext(error, context),
      );
    });
    channel.addEventListener("close", () => {
      if (!channelContextIsCurrent(context)) return;
      session.channel = null;
      session.connected =
        session.relayHostPresent &&
        session.socket?.readyState === WebSocket.OPEN;
      if (!session.connected) clearDisconnectedContent(session);
      render();
    });
    channel.addEventListener("message", (event) => {
      if (!channelContextIsCurrent(context)) return;
      queueIncomingEnvelope(event.data, context);
    });
  }

  async function markConnected(context) {
    if (!sessionContextIsCurrent(context)) return;
    const session = context.session;
    session.connected = true;
    session.connecting = false;
    session.reconnectDelayMs = initialReconnectDelayMs;
    render();
    if (session.helloSent) return;
    session.helloSent = true;
    try {
      await sendMessage(
        {
          type: "hello",
          device: {
            id: state.identity.id,
            name: state.identity.name,
            kind: "phone",
            platform: state.identity.platform,
          },
          vibrationEnabled: session.pair.vibrationEnabled !== false,
          agentNotificationsEnabled: wantsAgentNotifications(session.pair),
        },
        context,
      );
      if (!sessionContextIsCurrent(context)) return;
      if (
        !wantsAgentNotifications(session.pair) ||
        notificationPermission() !== "granted"
      ) {
        sendSettings(session).catch(() => {});
      }
    } catch (error) {
      if (sessionContextIsCurrent(context)) session.helloSent = false;
      throw error;
    }
  }

  function queueIncomingEnvelope(envelope, context) {
    if (!connectionContextIsCurrent(context)) return;
    const session = context.session;
    if (!session.connected) return;
    let bytes;
    try {
      bytes = encodedEnvelopeByteLength(envelope);
    } catch (error) {
      closeForInboundLimit(error, context);
      return;
    }
    const contentGeneration = session.contentGeneration;
    const queue = incomingQueueFor(session);
    if (
      queue.count >= maximumQueuedInboundEntries ||
      queue.bytes + bytes > maximumQueuedInboundBytes
    ) {
      closeForInboundLimit(inboundQueueOverflowError(), context);
      return;
    }
    queue.count += 1;
    queue.bytes += bytes;
    const entry = { payload: envelope, bytes };
    queue.entries.add(entry);
    const pending = queue.chain
      .then(async () => {
        if (queue.cancelled || entry.payload === null) return;
        if (!connectionContextIsCurrent(context) || !session.connected ||
            contentGeneration !== session.contentGeneration) return;
        // The bounded entry carries the value passed to openEnvelope(envelope, context.key).
        const message = await openEnvelope(entry.payload, context.key);
        if (!connectionContextIsCurrent(context) || !session.connected ||
            contentGeneration !== session.contentGeneration) return;
        await handleDeviceMessage(message, session);
      })
      .catch((error) => {
        if (
          connectionContextIsCurrent(context) &&
          session.connected &&
          contentGeneration === session.contentGeneration
        ) {
          connectionError(error, session);
        }
      })
      .finally(() => {
        queue.entries.delete(entry);
        entry.payload = null;
        releaseQueueBudget(queue, entry.bytes);
      });
    queue.chain = pending;
    session.incomingMessages = pending;
  }

  async function sendSignal(signal, context, peer = null) {
    if (!relayContextIsCurrent(context)) return;
    if (peer && context.session.peer !== peer) return;
    const payload = await sealEnvelope(signal, context.key);
    if (!relayContextIsCurrent(context)) return;
    if (peer && context.session.peer !== peer) return;
    if (context.socket.readyState !== WebSocket.OPEN) return;
    context.socket.send(encodeRelayFrame("signal", payload));
  }

  async function sendMessage(
    message,
    context = currentSessionContext(activeSession()),
  ) {
    if (!context?.key || !sessionContextIsCurrent(context)) {
      throw new Error("连接已经变化，请重试");
    }
    const session = context.session;
    const envelope = await sealEnvelope(message, context.key);
    const relayFrame = encodeRelayFrame("data", envelope);
    if (!sessionContextIsCurrent(context)) {
      throw new Error("连接已经变化，请重试");
    }
    const transport = messageTransport(session, context);
    if (!transport) {
      throw new Error("电脑当前不在线");
    }
    if (transport.kind === "channel") {
      transport.target.send(envelope);
      return transport;
    }
    if (transport.kind === "relay") {
      // Relay fallback remains the equivalent of session.socket.send(relayFrame).
      transport.target.send(relayFrame);
      return transport;
    }
    throw new Error("连接传输已经变化，请重新发送文件");
  }

  function messageTransport(session, context) {
    const pin = context?.transport;
    if (pin !== undefined && pin !== null) {
      const kind = pin?.kind;
      const target = kind === "channel" ? session.channel : session.socket;
      const expectedTarget = pin?.target;
      if (
        kind === "channel" &&
        target?.readyState === "open" &&
        expectedTarget === target
      ) {
        return { kind, target };
      }
      if (
        kind === "relay" &&
        target?.readyState === WebSocket.OPEN &&
        session.relayHostPresent &&
        expectedTarget === target
      ) {
        return { kind, target };
      }
      throw new Error("连接传输已经变化，请重新发送文件");
    }
    if (session.channel?.readyState === "open") {
      return { kind: "channel", target: session.channel };
    }
    if (
      session.socket?.readyState === WebSocket.OPEN &&
      session.relayHostPresent
    ) {
      return { kind: "relay", target: session.socket };
    }
    return null;
  }

  function currentSessionContext(session) {
    return session
      ? {
          session,
          pair: { ...session.pair },
          key: session.signalKey,
          connectionGeneration: session.connectionGeneration,
          contentGeneration: session.contentGeneration,
        }
      : null;
  }

  async function handleDeviceMessage(message, session) {
    switch (message.type) {
      case "welcome":
        if (message.host?.name) {
          session.pair.hostName = message.host.name;
          savePairings();
        }
        render();
        break;
      case "clipboard.snapshot":
        receiveClipboardSnapshot(message, session);
        break;
      case "clipboard.upsert":
        if (message.item) upsertClipboardItem(message.item, session);
        break;
      case "request.rejected":
        handleRequestRejected(message, session);
        break;
      case "agent.completed":
        receiveAgentEvent(message, { session });
        break;
      case "agent.state":
        receiveAgentState(message, session);
        break;
      case "file.start":
        beginDownload(message, session);
        break;
      case "file.chunk":
        receiveDownloadChunk(message, session);
        break;
      case "file.end":
        finishDownload(message.transferId, session);
        break;
    }
  }


  function closeConnection(session = activeSession()) {
    if (!session) return;
    session.connectionGeneration += 1;
    session.relayGeneration += 1;
    clearTimeout(session.reconnectTimer);
    session.reconnectTimer = null;
    session.reconnectDelayMs = initialReconnectDelayMs;
    session.socket?.close();
    session.socket = null;
    closePeer(session);
    session.signalKey = null;
    resetRelayQueue(session);
    resetIncomingQueue(session);
    session.connected = false;
    session.connecting = false;
    session.relayHostPresent = false;
    session.helloSent = false;
    clearDisconnectedContent(session);
  }

  function clearDisconnectedContent(session) {
    session.contentGeneration = (session.contentGeneration || 0) + 1;
    session.items = [];
    session.clipboardRenderRevision += 1;
    session.lastSyncAt = null;
    clearDownloads(session);
    session.outgoingRequests.clear();
    resetIncomingQueue(session);
    session.remoteCandidates = [];
    session.remoteCandidateBytes = 0;
  }

  function closePeer(session) {
    const channel = session.channel;
    const peer = session.peer;
    session.channel = null;
    session.peer = null;
    session.remoteCandidates = [];
    session.remoteCandidateBytes = 0;
    channel?.close();
    peer?.close();
  }

  function connectionError(error, session) {
    // A WebSocket `error` event carries no diagnostic payload and can fire on
    // every reconnect attempt while a paired computer is offline. Keeping those
    // events in the browser console only adds noise (and retained log objects).
    // Preserve real exceptions from protocol and crypto handling.
    if (!(error instanceof Event && error.type === "error")) {
      console.error(error);
    }
    session.connecting = false;
    session.connected =
      session.channel?.readyState === "open" ||
      (session.relayHostPresent &&
        session.socket?.readyState === WebSocket.OPEN);
    if (!session.connected) clearDisconnectedContent(session);
    render();
  }


    return {
      closeConnection,
      connect,
      currentSessionContext,
      sendMessage,
    };
}
