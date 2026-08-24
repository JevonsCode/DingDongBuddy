import {
  relayConnectionWasReplaced,
  shouldReconnectRelay,
} from "./connection-policy.js";
import { pairingsMatch } from "./pairing-state.js?shell=35";
import { wantsAgentNotifications } from "./notification-policy.js?shell=35";
import {
  encodeRelayFrame,
  importAesKey,
  openEnvelope,
  sealEnvelope,
} from "./app-codecs.js?shell=35";

// Encrypted relay/WebRTC lifecycle and ordered inbound message dispatch.
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
      session.relayFrames = Promise.resolve();
      socket.addEventListener("message", (event) => {
        if (!relayContextIsCurrent(context)) return;
        session.relayFrames = session.relayFrames
          .then(() =>
            relayContextIsCurrent(context)
              ? handleRelayFrame(event.data, context)
              : undefined,
          )
          .catch((error) => connectionErrorForContext(error, context));
      });
      socket.addEventListener("close", (event) => {
        if (!relayContextIsCurrent(context)) return;
        session.socket = null;
        session.relayHostPresent = false;
        session.connecting = false;
        session.connected = session.channel?.readyState === "open";
        session.connectionSuperseded = relayConnectionWasReplaced(event);
        if (!session.connected) session.items = [];
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
      if (frame.event === "host_joined") {
        session.relayHostPresent = true;
        await markConnected(sessionContextFrom(context));
      }
      if (frame.event === "host_left") {
        if (!relayContextIsCurrent(context)) return;
        session.relayHostPresent = false;
        session.helloSent = false;
        session.connected = session.channel?.readyState === "open";
        if (!session.connected) session.items = [];
        render();
      }
      return;
    }
    if (frame.type === "data" && typeof frame.payload === "string") {
      queueIncomingEnvelope(frame.payload, context);
      return;
    }
    if (frame.type !== "signal" || typeof frame.payload !== "string") return;
    const signal = await openEnvelope(frame.payload, context.key);
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
        session.remoteCandidates.push(candidate);
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
        if (!session.connected) session.items = [];
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
    for (const candidate of session.remoteCandidates.splice(0)) {
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
      if (!session.connected) session.items = [];
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
    session.incomingMessages = session.incomingMessages
      .then(async () => {
        if (!connectionContextIsCurrent(context)) return;
        const message = await openEnvelope(envelope, context.key);
        if (!connectionContextIsCurrent(context)) return;
        await handleDeviceMessage(message, session);
      })
      .catch((error) => connectionErrorForContext(error, context));
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
    const envelope = await sealEnvelope(message, context.key);
    const relayFrame = encodeRelayFrame("data", envelope);
    if (!sessionContextIsCurrent(context)) {
      throw new Error("连接已经变化，请重试");
    }
    const session = context.session;
    if (session.channel?.readyState === "open") {
      session.channel.send(envelope);
      return;
    }
    if (
      session.socket?.readyState === WebSocket.OPEN &&
      session.relayHostPresent
    ) {
      session.socket.send(relayFrame);
      return;
    }
    throw new Error("电脑当前不在线");
  }

  function currentSessionContext(session) {
    return session
      ? {
          session,
          pair: { ...session.pair },
          key: session.signalKey,
          connectionGeneration: session.connectionGeneration,
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
    session.relayFrames = Promise.resolve();
    session.incomingMessages = Promise.resolve();
    session.connected = false;
    session.connecting = false;
    session.relayHostPresent = false;
    session.helloSent = false;
    session.items = [];
    session.lastSyncAt = null;
    session.downloads.clear();
    session.outgoingRequests.clear();
  }

  function closePeer(session) {
    const channel = session.channel;
    const peer = session.peer;
    session.channel = null;
    session.peer = null;
    session.remoteCandidates = [];
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
    if (!session.connected) session.items = [];
    render();
  }


    return {
      closeConnection,
      connect,
      currentSessionContext,
      sendMessage,
    };
}
