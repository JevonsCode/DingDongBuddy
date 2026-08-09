import {
  defaultDeviceName,
  detectDeviceName,
  shouldUpgradeAutomaticDeviceName,
} from "./device-name.js";
import {
  relayConnectionWasReplaced,
  shouldReconnectRelay,
} from "./connection-policy.js";
import {
  agentNotificationsAreActive,
  applyAgentNotificationDefault,
  wantsAgentNotifications,
} from "./notification-policy.js";
import { isStoredPairing, pairingsMatch } from "./pairing-state.js";
import {
  adjacentContentTab,
  contentScrollIsSnapped,
  contentTabAtScrollPosition,
  contentTabs,
  isContentTab,
  parseContentTabLaunch,
} from "./content-navigation.js";

const storageKeys = {
  identity: "dingdong.identity.v1",
  pair: "dingdong.pair.v1",
  pendingPair: "dingdong.pending-pair.v1",
  installRequest: "dingdong.install-request.v1",
};
const maximumFileBytes = 25 * 1024 * 1024;
const maximumRelayFrameBytes = 256 * 1024;
const maximumClipboardTextBytes = 128 * 1024;
const maximumClipboardItemBytes = 160 * 1024;
const fileChunkBytes = 32 * 1024;
const maximumConcurrentDownloads = 4;
const maximumEncodedFileChunkLength = Math.ceil(fileChunkBytes / 3) * 4 + 4;
const installVerificationIntervalMs = 3000;
const installVerificationTimeoutMs = 60 * 1000;
const directVibrationPattern = [300, 100, 300, 100, 600];
const agentLaunchIntentKey = "agent-launch-intent";
const agentLaunchIntentTtlMs = 5 * 60 * 1000;
const initialContentTab = consumeContentTabLaunch() || "clipboard";

const state = {
  identity: loadIdentity(),
  pair: loadJson(storageKeys.pair),
  socket: null,
  peer: null,
  channel: null,
  signalKey: null,
  remoteCandidates: [],
  connected: false,
  connecting: false,
  connectionSuperseded: false,
  relayHostPresent: false,
  helloSent: false,
  relayFrames: Promise.resolve(),
  incomingMessages: Promise.resolve(),
  connectionGeneration: 0,
  relayGeneration: 0,
  manualDisconnect: false,
  items: [],
  agentEvents: [],
  downloads: new Map(),
  outgoingRequests: new Set(),
  selectedFile: null,
  activeTab: initialContentTab,
  reconnectTimer: null,
  toastTimer: null,
  serviceWorkerRegistration: null,
  installPrompt: null,
  installStatus: "idle",
  installRequestedAt: Number(localStorage.getItem(storageKeys.installRequest)) || 0,
  installVerificationTimer: null,
  notificationCheckInProgress: false,
  notificationDeliveryHealthy: null,
  pushSubscriptionReady: false,
  pushProvider: null,
  pushProviderStatus: null,
  pushDeviceReceipt: null,
  pushMutationTail: Promise.resolve(),
  notificationGeneration: 0,
  notificationVerificationInProgress: false,
  pendingPair: null,
};

const elements = Object.fromEntries(
  [
    "connection-label",
    "settings-button",
    "install-app-banner",
    "install-app-title",
    "install-app-copy",
    "install-app-button",
    "install-dialog",
    "install-dialog-eyebrow",
    "install-dialog-title",
    "install-instructions",
    "pair-view",
    "pair-title",
    "pair-description",
    "device-name",
    "confirm-pair",
    "cancel-pair",
    "empty-view",
    "content-view",
    "offline-banner",
    "offline-title",
    "offline-copy",
    "reconnect-button",
    "notification-onboarding",
    "enable-notifications",
    "notification-help-dialog",
    "notification-help-eyebrow",
    "notification-help-title",
    "notification-help-reason",
    "notification-permission-status",
    "notification-subscription-status",
    "notification-provider-status",
    "notification-device-status",
    "notification-help-steps",
    "notification-help-note",
    "notification-recheck",
    "content-tabs",
    "feed-pager",
    "clipboard-panel",
    "agent-panel",
    "clipboard-count",
    "agent-count",
    "last-sync-label",
    "clipboard-list",
    "clipboard-empty",
    "agent-list",
    "agent-empty",
    "composer",
    "selected-file",
    "selected-file-name",
    "clear-file",
    "file-input",
    "message-input",
    "send-button",
    "settings-dialog",
    "settings-device-name",
    "agent-notification-toggle",
    "agent-notification-status",
    "vibration-toggle",
    "vibration-support-label",
    "vibration-test",
    "vibration-test-result",
    "disconnect-device",
    "delete-device",
    "toast",
  ].map((id) => [id, document.getElementById(id)]),
);

const contentTabButtons = Array.from(document.querySelectorAll(".tab"));
let feedPagerScrollTimer = null;
let feedPagerScrolling = false;
let feedPagerWidth = 0;
let feedPagerSupportsScrollEnd = false;
let feedPagerTouchActive = false;
const feedPanelHeights = new Map();

window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault();
  state.installPrompt = event;
  if (state.installStatus !== "installed") {
    clearInstallRequest();
    state.installStatus = "available";
  }
  renderInstallPromotion();
});
window.addEventListener("appinstalled", () => {
  state.installPrompt = null;
  markInstallRequested();
  refreshInstallState().catch(() => {});
});
document.addEventListener("visibilitychange", handleVisibilityChange);

const launchPair = capturePairingLaunch();
boot(launchPair);

async function boot(scannedPair) {
  wireInteractions();
  initializeInstallState();
  registerServiceWorker().then((registration) => {
    state.serviceWorkerRegistration = registration;
  });
  navigator.serviceWorker?.addEventListener("message", (event) => {
    if (event.data?.type === "content-tab.open") {
      if (handleContentTabOpen(event.data)) {
        event.ports?.[0]?.postMessage({
          type: "content-tab.opened",
          tab: event.data.tab,
        });
      }
      return;
    }
    if (event.data?.type === "agent.completed") {
      receiveAgentEvent(event.data.message, { requestNotification: false });
    }
    if (event.data?.type === "push.health") {
      if (event.data.room !== state.pair?.room) return;
      if (event.data.notificationEpoch !== state.pair?.notificationEpoch) return;
      state.pushDeviceReceipt = {
        messageId: event.data.messageId,
        stage: event.data.stage,
        errorCode: event.data.errorCode,
      };
      state.notificationDeliveryHealthy =
        event.data.stage === "created"
          ? true
          : event.data.stage === "failed"
            ? false
            : null;
      renderAgentNotificationStatus();
    }
  });
  await upgradeDefaultIdentityName();
  await restorePairFromWorker();
  await restoreAgentLaunchIntent();
  await restorePushHealthFromWorker();
  if (applyAgentNotificationDefault(state.pair)) {
    savePair();
  }
  renderInstallPromotion();
  refreshInstallState().catch(() => {});

  if (scannedPair && pairingsMatch(state.pair, scannedPair)) {
    clearPairingFragment();
    clearPendingPairingLaunch();
  } else if (scannedPair) {
    showPairConfirmation(scannedPair);
    return;
  }
  if (state.pair) {
    state.pushSubscriptionReady = false;
    await persistPairForWorker();
    render();
    if (!state.pair.manualDisconnect) connect();
    if (
      wantsAgentNotifications(state.pair) &&
      "Notification" in window &&
      Notification.permission === "granted"
    ) {
      enableAgentNotifications({
        requestPermission: false,
        markPreference: false,
        sendTest: false,
        syncEnabledToDesktop: true,
      }).then(() => render());
    }
  } else {
    render();
  }
}

function wireInteractions() {
  initializeFeedPager();
  elements["install-app-button"].addEventListener("click", installApp);
  elements["notification-recheck"].addEventListener(
    "click",
    recheckAgentNotifications,
  );
  elements["confirm-pair"].addEventListener("click", confirmPairing);
  elements["cancel-pair"].addEventListener("click", () => {
    history.replaceState(null, "", location.pathname + location.search);
    clearPendingPairingLaunch();
    state.pendingPair = null;
    render();
  });
  elements["reconnect-button"].addEventListener("click", () => {
    if (!state.pair) return;
    state.pair.manualDisconnect = false;
    savePair();
    connect();
  });
  elements["settings-button"].addEventListener("click", () => {
    if (!state.pair) {
      showToast("请先扫描电脑上的连接二维码");
      return;
    }
    elements["settings-device-name"].textContent =
      state.pair.hostName || "连接设置";
    elements["agent-notification-toggle"].checked =
      wantsAgentNotifications(state.pair);
    elements["vibration-toggle"].checked =
      state.pair.vibrationEnabled !== false;
    elements["vibration-toggle"].disabled =
      !wantsAgentNotifications(state.pair);
    renderAgentNotificationStatus();
    elements["settings-dialog"].showModal();
  });
  elements["enable-notifications"].addEventListener("click", async () => {
    await enableAgentNotifications();
    render();
  });
  elements["agent-notification-toggle"].addEventListener(
    "change",
    async (event) => {
      if (event.target.checked) {
        await enableAgentNotifications();
      } else {
        await disableAgentNotifications();
      }
      event.target.checked = wantsAgentNotifications(state.pair);
      elements["vibration-toggle"].disabled =
        !wantsAgentNotifications(state.pair);
      render();
    },
  );
  elements["vibration-toggle"].addEventListener("change", async (event) => {
    if (!state.pair) return;
    state.pair.vibrationEnabled = event.target.checked;
    state.pair.notificationEpoch = createNotificationEpoch();
    savePair();
    await sendSettings();
  });
  elements["vibration-test"].addEventListener("click", testDeviceVibration);
  elements["disconnect-device"].addEventListener("click", () => {
    if (!state.pair) return;
    state.pair.manualDisconnect = true;
    savePair();
    closeConnection();
    elements["settings-dialog"].close();
    render();
  });
  elements["delete-device"].addEventListener("click", deleteDevice);
  contentTabButtons.forEach((button) => {
    button.addEventListener("click", () => {
      selectContentTab(button.dataset.tab, { animate: true });
    });
    button.addEventListener("keydown", handleContentTabKeydown);
  });
  elements["message-input"].addEventListener("input", () => {
    resizeComposerInput();
    updateSendButton();
  });
  elements["file-input"].addEventListener("change", (event) => {
    const file = event.target.files?.[0] || null;
    if (file && file.size > maximumFileBytes) {
      event.target.value = "";
      showToast("单个文件上限为 25 MB");
      return;
    }
    state.selectedFile = file;
    renderSelectedFile();
    updateSendButton();
  });
  elements["clear-file"].addEventListener("click", clearSelectedFile);
  elements["send-button"].addEventListener("click", sendComposerContent);
}

function consumeContentTabLaunch() {
  const launch = parseContentTabLaunch(location.href, location.origin);
  if (!launch) return null;
  history.replaceState(null, "", launch.cleanPath);
  return launch.tab;
}

function initializeFeedPager() {
  const pager = elements["feed-pager"];
  pager.addEventListener("scroll", handleFeedPagerScroll, { passive: true });
  feedPagerSupportsScrollEnd = "onscrollend" in pager;
  if (feedPagerSupportsScrollEnd) {
    pager.addEventListener("scrollend", finishFeedPagerScroll);
  } else {
    pager.addEventListener("touchstart", handleFeedPagerTouchStart, {
      passive: true,
    });
    pager.addEventListener("touchend", handleFeedPagerTouchEnd, {
      passive: true,
    });
    pager.addEventListener("touchcancel", handleFeedPagerTouchEnd, {
      passive: true,
    });
  }

  if ("ResizeObserver" in window) {
    const observer = new ResizeObserver(handleFeedPagerResize);
    observer.observe(pager);
    observer.observe(elements["clipboard-panel"]);
    observer.observe(elements["agent-panel"]);
  } else {
    window.addEventListener("resize", refreshFeedPagerLayout);
  }
  requestAnimationFrame(refreshFeedPagerLayout);
}

function handleFeedPagerResize(entries) {
  for (const entry of entries) {
    const tab = entry.target.id?.replace(/-panel$/, "");
    if (!isContentTab(tab)) continue;
    const box = Array.isArray(entry.borderBoxSize)
      ? entry.borderBoxSize[0]
      : entry.borderBoxSize;
    const height = box?.blockSize || entry.contentRect.height;
    if (height > 0) feedPanelHeights.set(tab, height);
  }
  refreshFeedPagerLayout();
}

function refreshFeedPagerLayout() {
  const pager = elements["feed-pager"];
  const width = pager.clientWidth;
  const widthChanged = width > 0 && Math.abs(width - feedPagerWidth) > 0.5;
  if (widthChanged) {
    feedPagerWidth = width;
    if (!feedPagerScrolling) alignFeedPager(state.activeTab, false);
  }
  if (!feedPagerScrolling) syncFeedPagerHeight();
}

function handleFeedPagerScroll() {
  feedPagerScrolling = true;
  elements["feed-pager"].classList.add("is-scrolling");
  syncFeedPagerHeight();
  if (!feedPagerSupportsScrollEnd && !feedPagerTouchActive) {
    scheduleFeedPagerFinish();
  }
}

function handleFeedPagerTouchStart() {
  feedPagerTouchActive = true;
  clearTimeout(feedPagerScrollTimer);
  feedPagerScrollTimer = null;
}

function handleFeedPagerTouchEnd() {
  feedPagerTouchActive = false;
  if (feedPagerScrolling) scheduleFeedPagerFinish();
}

function scheduleFeedPagerFinish() {
  clearTimeout(feedPagerScrollTimer);
  feedPagerScrollTimer = setTimeout(finishFeedPagerScroll, 120);
}

function finishFeedPagerScroll() {
  clearTimeout(feedPagerScrollTimer);
  feedPagerScrollTimer = null;
  const pager = elements["feed-pager"];
  if (
    !feedPagerSupportsScrollEnd &&
    !contentScrollIsSnapped(pager.scrollLeft, pager.clientWidth)
  ) {
    return;
  }
  const tab = contentTabAtScrollPosition(pager.scrollLeft, pager.clientWidth);
  feedPagerScrolling = false;
  pager.classList.remove("is-scrolling");
  if (tab !== state.activeTab) {
    state.activeTab = tab;
    renderTabs();
  }
  syncFeedPagerHeight();
}

function syncFeedPagerHeight() {
  const pager = elements["feed-pager"];
  const height = feedPagerScrolling
    ? Math.max(...contentTabs.map(contentPanelHeight))
    : contentPanelHeight(state.activeTab);
  const nextHeight = `${Math.ceil(height)}px`;
  if (height > 0 && pager.style.height !== nextHeight) {
    pager.style.height = nextHeight;
  }
}

function contentPanelHeight(tab) {
  const cached = feedPanelHeights.get(tab);
  if (cached > 0) return cached;
  const panel = elements[`${tab}-panel`];
  const height = Math.max(panel.scrollHeight, panel.offsetHeight);
  if (height > 0) feedPanelHeights.set(tab, height);
  return height;
}

function invalidateFallbackFeedPanelHeight(tab) {
  if ("ResizeObserver" in window) return;
  feedPanelHeights.delete(tab);
  requestAnimationFrame(refreshFeedPagerLayout);
}

function alignFeedPager(tab, animate) {
  const pager = elements["feed-pager"];
  const width = pager.clientWidth;
  const index = contentTabs.indexOf(tab);
  if (width <= 0 || index < 0) return;
  const left = index * width;
  const behavior =
    animate && !window.matchMedia("(prefers-reduced-motion: reduce)").matches
      ? "smooth"
      : "auto";
  pager.scrollTo({ left, behavior });
  if (behavior === "auto") syncFeedPagerHeight();
}

function selectContentTab(
  tab,
  { animate = false, focusTab = false, reveal = false } = {},
) {
  if (!isContentTab(tab)) return;
  state.activeTab = tab;
  renderTabs();
  if (focusTab) {
    contentTabButtons.find((button) => button.dataset.tab === tab)?.focus();
  }
  requestAnimationFrame(() => {
    alignFeedPager(tab, animate);
    if (reveal) {
      elements["content-tabs"].scrollIntoView({
        block: "start",
        behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches
          ? "auto"
          : "smooth",
      });
    }
  });
}

function handleContentTabKeydown(event) {
  let tab = null;
  if (event.key === "ArrowLeft") {
    tab = adjacentContentTab(state.activeTab, -1);
  } else if (event.key === "ArrowRight") {
    tab = adjacentContentTab(state.activeTab, 1);
  } else if (event.key === "Home") {
    tab = contentTabs[0];
  } else if (event.key === "End") {
    tab = contentTabs.at(-1);
  }
  if (!tab) return;
  event.preventDefault();
  selectContentTab(tab, { animate: true, focusTab: true });
}

function handleContentTabOpen(message) {
  if (!isContentTab(message.tab)) return false;
  if (
    typeof message.room === "string" &&
    message.room === state.pair?.room &&
    message.message
  ) {
    receiveAgentEvent(message.message, { requestNotification: false });
  }
  document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close());
  selectContentTab(message.tab, { animate: true, reveal: true });
  return true;
}

function testDeviceVibration() {
  const result = elements["vibration-test-result"];
  if (typeof navigator.vibrate !== "function") {
    result.textContent = "支持：否 · 返回值：未调用";
    showToast("当前浏览器没有提供震动能力");
    return;
  }
  let accepted = false;
  try {
    accepted = navigator.vibrate(directVibrationPattern);
  } catch {
    accepted = false;
  }
  if (accepted) {
    result.textContent = "支持：是 · 返回值：true；无触感说明被系统拦截";
    showToast("已请求三段震动，请确认手机触感");
  } else {
    result.textContent = "支持：是 · 返回值：false；浏览器未接受请求";
    showToast("浏览器拒绝震动，请检查系统触感设置");
  }
}

function pairingFromFragment() {
  const raw = location.hash.startsWith("#pair=")
    ? location.hash.slice("#pair=".length)
    : null;
  if (!raw) return null;
  try {
    const decoded = JSON.parse(
      new TextDecoder().decode(base64UrlDecode(raw)),
    );
    if (
      decoded.v !== 1 ||
      typeof decoded.room !== "string" ||
      typeof decoded.secret !== "string" ||
      typeof decoded.relay !== "string"
    ) {
      clearPairingFragment();
      showToast("这个连接二维码无效或已经损坏");
      return null;
    }
    return decoded;
  } catch {
    clearPairingFragment();
    showToast("这个连接二维码无效或已经损坏");
    return null;
  }
}

function capturePairingLaunch() {
  const scannedPair = pairingFromFragment();
  if (scannedPair) {
    localStorage.setItem(
      storageKeys.pendingPair,
      JSON.stringify({ pair: scannedPair, capturedAt: Date.now() }),
    );
    return scannedPair;
  }
  const pending = loadJson(storageKeys.pendingPair);
  if (
    isStoredPairing(pending?.pair) &&
    Number.isFinite(pending?.capturedAt) &&
    Date.now() - pending.capturedAt <= 10 * 60 * 1000
  ) {
    return pending.pair;
  }
  clearPendingPairingLaunch();
  return null;
}

function clearPendingPairingLaunch() {
  localStorage.removeItem(storageKeys.pendingPair);
}

function showPairConfirmation(pair) {
  state.pendingPair = pair;
  elements["pair-title"].textContent = `连接“${pair.hostName || "DingDong 电脑"}”？`;
  elements["pair-description"].textContent =
    "连接后只会看到电脑主动发送，或为此设备开启自动发送后产生的内容。你也可以主动发送文字或文件。";
  elements["device-name"].value = state.identity.name;
  elements["pair-view"].hidden = false;
  elements["empty-view"].hidden = true;
  elements["content-view"].hidden = true;
  elements.composer.hidden = true;
}

async function confirmPairing() {
  const pair = state.pendingPair;
  if (!pair) return;
  const name = elements["device-name"].value.trim();
  if (!name) {
    elements["device-name"].focus();
    return;
  }
  const previousPair = state.pair;
  if (previousPair && !pairingsMatch(previousPair, pair)) {
    invalidateNotificationOperations();
    closeConnection();
    previousPair.agentNotificationsEnabled = false;
    previousPair.notificationEpoch = createNotificationEpoch();
    const previousPairSnapshot = { ...previousPair };
    await persistPairForWorker(previousPairSnapshot).catch(() => {});
    await cleanupPushSubscription(previousPairSnapshot);
    await resetNotificationRuntime();
    state.items = [];
    state.agentEvents = [];
  }
  if (name !== state.identity.name) {
    state.identity.nameSource = "user";
  }
  state.identity.name = name;
  localStorage.setItem(storageKeys.identity, JSON.stringify(state.identity));
  state.pair = {
    version: 1,
    room: pair.room,
    secret: pair.secret,
    relay: pair.relay,
    hostId: pair.hostId,
    hostName: pair.hostName || "DingDong 电脑",
    vibrationEnabled: true,
    agentNotificationsEnabled: true,
    agentNotificationPreferenceSet: false,
    manualDisconnect: false,
  };
  state.pendingPair = null;
  clearPairingFragment();
  clearPendingPairingLaunch();
  savePair();
  render();
  const notificationSetup =
    !isIos() || isStandalone()
      ? enableAgentNotifications({ markPreference: false })
      : Promise.resolve(false);
  connect();
  notificationSetup.then(() => render());
}

async function connect() {
  if (
    !state.pair ||
    state.connecting ||
    state.socket?.readyState === WebSocket.OPEN ||
    state.socket?.readyState === WebSocket.CONNECTING
  ) {
    return;
  }
  clearTimeout(state.reconnectTimer);
  const pair = { ...state.pair };
  const connectionGeneration = state.connectionGeneration;
  const relayGeneration = state.relayGeneration + 1;
  state.relayGeneration = relayGeneration;
  state.connecting = !state.connected;
  state.relayHostPresent = false;
  state.helloSent = false;
  state.connectionSuperseded = false;
  state.manualDisconnect = false;
  renderConnectionState();
  const attempt = { pair, connectionGeneration, relayGeneration };
  try {
    const key = await importAesKey(pair.secret);
    if (!relayAttemptIsCurrent(attempt)) return;
    state.signalKey = key;
    const relay = new URL(pair.relay);
    relay.protocol = relay.protocol === "https:" ? "wss:" : "ws:";
    relay.pathname = `${relay.pathname.replace(/\/$/, "")}/v1/rooms/${encodeURIComponent(
      pair.room,
    )}`;
    relay.search = "?side=peer";
    const socket = new WebSocket(relay);
    const context = { ...attempt, key, socket };
    state.socket = socket;
    state.relayFrames = Promise.resolve();
    socket.addEventListener("message", (event) => {
      if (!relayContextIsCurrent(context)) return;
      state.relayFrames = state.relayFrames
        .then(() =>
          relayContextIsCurrent(context)
            ? handleRelayFrame(event.data, context)
            : undefined,
        )
        .catch((error) => connectionErrorForContext(error, context));
    });
    socket.addEventListener("close", (event) => {
      if (!relayContextIsCurrent(context)) return;
      state.socket = null;
      state.relayHostPresent = false;
      state.connecting = false;
      state.connected = state.channel?.readyState === "open";
      state.connectionSuperseded = relayConnectionWasReplaced(event);
      if (!state.connected) state.items = [];
      render();
      if (shouldReconnectRelay(event, state.pair)) {
        state.reconnectTimer = setTimeout(connect, 2400);
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
  return (
    context?.connectionGeneration === state.connectionGeneration &&
    pairingsMatch(context.pair, state.pair)
  );
}

function relayAttemptIsCurrent(context) {
  return (
    sessionContextIsCurrent(context) &&
    context.relayGeneration === state.relayGeneration
  );
}

function relayContextIsCurrent(context) {
  return relayAttemptIsCurrent(context) && state.socket === context.socket;
}

function peerContextIsCurrent(context) {
  return sessionContextIsCurrent(context) && state.peer === context.peer;
}

function channelContextIsCurrent(context) {
  return sessionContextIsCurrent(context) && state.channel === context.channel;
}

function connectionContextIsCurrent(context) {
  if (!sessionContextIsCurrent(context)) return false;
  if (context.socket && state.socket !== context.socket) return false;
  if (context.peer && state.peer !== context.peer) return false;
  if (context.channel && state.channel !== context.channel) return false;
  return true;
}

function connectionErrorForContext(error, context) {
  if (!connectionContextIsCurrent(context)) return;
  connectionError(error);
}

function sessionContextFrom(context) {
  return {
    pair: context.pair,
    key: context.key,
    connectionGeneration: context.connectionGeneration,
  };
}

async function handleRelayFrame(raw, context) {
  if (!relayContextIsCurrent(context)) return;
  const frame = JSON.parse(raw);
  if (frame.type === "relay") {
    if (frame.event === "host_joined") {
      state.relayHostPresent = true;
      await markConnected(sessionContextFrom(context));
    }
    if (frame.event === "host_left") {
      if (!relayContextIsCurrent(context)) return;
      state.relayHostPresent = false;
      state.connected = state.channel?.readyState === "open";
      if (!state.connected) state.items = [];
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
    const peer = state.peer;
    if (peer?.remoteDescription) {
      await peer.addIceCandidate(candidate);
    } else {
      state.remoteCandidates.push(candidate);
    }
  }
}

async function acceptOffer(signal, relayContext) {
  if (!relayContextIsCurrent(relayContext)) return;
  closePeer();
  const peer = new RTCPeerConnection({ iceServers: [] });
  state.peer = peer;
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
      state.connected =
        state.relayHostPresent && state.socket?.readyState === WebSocket.OPEN;
      if (!state.connected) state.items = [];
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
  for (const candidate of state.remoteCandidates.splice(0)) {
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
  state.channel = channel;
  const context = { ...peerContext, channel };
  channel.addEventListener("open", () => {
    if (!channelContextIsCurrent(context)) return;
    markConnected(sessionContextFrom(context)).catch((error) =>
      connectionErrorForContext(error, context),
    );
  });
  channel.addEventListener("close", () => {
    if (!channelContextIsCurrent(context)) return;
    state.channel = null;
    state.connected =
      state.relayHostPresent && state.socket?.readyState === WebSocket.OPEN;
    if (!state.connected) state.items = [];
    render();
  });
  channel.addEventListener("message", (event) => {
    if (!channelContextIsCurrent(context)) return;
    queueIncomingEnvelope(event.data, context);
  });
}

async function markConnected(context) {
  if (!sessionContextIsCurrent(context)) return;
  state.connected = true;
  state.connecting = false;
  render();
  if (state.helloSent) return;
  state.helloSent = true;
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
        vibrationEnabled: state.pair.vibrationEnabled !== false,
        agentNotificationsEnabled: wantsAgentNotifications(state.pair),
      },
      context,
    );
    if (!sessionContextIsCurrent(context)) return;
    if (
      !wantsAgentNotifications(state.pair) ||
      notificationPermission() !== "granted"
    ) {
      sendSettings().catch(() => {});
    }
  } catch (error) {
    if (sessionContextIsCurrent(context)) state.helloSent = false;
    throw error;
  }
}

function queueIncomingEnvelope(envelope, context) {
  if (!connectionContextIsCurrent(context)) return;
  state.incomingMessages = state.incomingMessages
    .then(async () => {
      if (!connectionContextIsCurrent(context)) return;
      const message = await openEnvelope(envelope, context.key);
      if (!connectionContextIsCurrent(context)) return;
      await handleDeviceMessage(message);
    })
    .catch((error) => connectionErrorForContext(error, context));
}

async function sendSignal(signal, context, peer = null) {
  if (!relayContextIsCurrent(context)) return;
  if (peer && state.peer !== peer) return;
  const payload = await sealEnvelope(signal, context.key);
  if (!relayContextIsCurrent(context)) return;
  if (peer && state.peer !== peer) return;
  if (context.socket.readyState !== WebSocket.OPEN) return;
  context.socket.send(encodeRelayFrame("signal", payload));
}

async function sendMessage(
  message,
  context = {
    pair: { ...state.pair },
    key: state.signalKey,
    connectionGeneration: state.connectionGeneration,
  },
) {
  if (!context.key || !sessionContextIsCurrent(context)) {
    throw new Error("连接已经变化，请重试");
  }
  const envelope = await sealEnvelope(message, context.key);
  const relayFrame = encodeRelayFrame("data", envelope);
  if (!sessionContextIsCurrent(context)) {
    throw new Error("连接已经变化，请重试");
  }
  if (state.channel?.readyState === "open") {
    state.channel.send(envelope);
    return;
  }
  if (
    state.socket?.readyState === WebSocket.OPEN &&
    state.relayHostPresent
  ) {
    state.socket.send(relayFrame);
    return;
  }
  throw new Error("电脑当前不在线");
}

async function handleDeviceMessage(message) {
  switch (message.type) {
    case "welcome":
      if (message.host?.name) {
        state.pair.hostName = message.host.name;
        savePair();
      }
      render();
      break;
    case "clipboard.snapshot":
      receiveClipboardSnapshot(message);
      break;
    case "clipboard.upsert":
      if (message.item) upsertClipboardItem(message.item);
      break;
    case "request.rejected":
      handleRequestRejected(message);
      break;
    case "agent.completed":
      receiveAgentEvent(message);
      break;
    case "file.start":
      beginDownload(message);
      break;
    case "file.chunk":
      receiveDownloadChunk(message);
      break;
    case "file.end":
      finishDownload(message.transferId);
      break;
  }
}

function receiveClipboardSnapshot(message) {
  if (message.reset !== false) state.items = [];
  let rejected = false;
  for (const item of Array.isArray(message.items) ? message.items : []) {
    if (!clipboardItemFitsTransferBoundary(item)) {
      rejected = true;
      continue;
    }
    mergeClipboardItem(item);
  }
  sortItems();
  state.items = state.items.slice(0, 50);
  if (message.complete !== false) {
    elements["last-sync-label"].textContent = formatTime(new Date());
  }
  renderClipboard();
  if (rejected) showToast("部分文字超过传输上限，请在电脑上改为发送文件");
}

function upsertClipboardItem(item) {
  if (!clipboardItemFitsTransferBoundary(item)) {
    showToast("这条文字超过传输上限，请在电脑上改为发送文件");
    return;
  }
  mergeClipboardItem(item);
  sortItems();
  state.items = state.items.slice(0, 50);
  renderClipboard();
}

function mergeClipboardItem(item) {
  const index = state.items.findIndex((value) => value.id === item.id);
  if (index >= 0) state.items[index] = item;
  else state.items.unshift(item);
}

function clipboardItemFitsTransferBoundary(item) {
  if (!item || typeof item !== "object") return false;
  if (typeof item.id !== "string" || item.id.length < 1 || item.id.length > 160) {
    return false;
  }
  if (
    typeof item.content === "string" &&
    utf8ByteLength(item.content) > maximumClipboardTextBytes
  ) {
    return false;
  }
  try {
    return utf8ByteLength(JSON.stringify(item)) <= maximumClipboardItemBytes;
  } catch {
    return false;
  }
}

function handleRequestRejected(message) {
  const requestId = message.requestId;
  if (
    message.requestType !== "clipboard.create" ||
    message.code !== "text_too_large" ||
    typeof requestId !== "string" ||
    !state.outgoingRequests.delete(requestId)
  ) {
    return;
  }
  const maximumBytes = Number.isSafeInteger(message.maximumBytes)
    ? message.maximumBytes
    : maximumClipboardTextBytes;
  showToast(`电脑拒绝了过大的文字（上限 ${formatBytes(maximumBytes)}），请改为发送文件`);
}

function rememberOutgoingRequest(requestId) {
  state.outgoingRequests.add(requestId);
  setTimeout(() => state.outgoingRequests.delete(requestId), 30_000);
}

function sortItems() {
  state.items.sort(
    (left, right) =>
      new Date(right.updatedAt || 0).getTime() -
      new Date(left.updatedAt || 0).getTime(),
  );
}

function receiveAgentEvent(message, { requestNotification = true } = {}) {
  if (!message?.id) return;
  if (!state.agentEvents.some((value) => value.id === message.id)) {
    state.agentEvents.unshift(message);
    state.agentEvents = state.agentEvents.slice(0, 50);
    renderAgentEvents();
  }
  if (requestNotification) notifyAgentCompletion(message);
}

function notifyAgentCompletion(message) {
  if (
    !wantsAgentNotifications(state.pair) ||
    notificationPermission() !== "granted" ||
    !("serviceWorker" in navigator)
  ) {
    return;
  }
  notifyAgentCompletionThroughWorker(
    message,
    { ...state.pair },
    state.notificationGeneration,
  ).catch(() => {});
}

async function notifyAgentCompletionThroughWorker(message, pair, generation) {
  ensureNotificationContext(pair, generation);
  const registration = await withTimeout(
    navigator.serviceWorker.ready,
    5000,
    "Service Worker 尚未就绪",
  );
  ensureNotificationContext(pair, generation);
  if (!registration.active) throw new Error("Service Worker 尚未激活");
  registration.active.postMessage({
    type: "agent.completed.realtime",
    message,
    room: pair.room,
    notificationEpoch: pair.notificationEpoch,
  });
}

async function sendComposerContent() {
  if (!state.connected) {
    showToast("电脑离线，暂时不能发送");
    return;
  }
  const text = elements["message-input"].value.trim();
  const file = state.selectedFile;
  elements["send-button"].disabled = true;
  try {
    if (file) {
      await sendFile(file);
      showToast("文件已发送到电脑剪贴板列表");
    } else if (text) {
      if (utf8ByteLength(text) > maximumClipboardTextBytes) {
        throw new Error("文字超过 128 KB，请改为选择文件发送");
      }
      const requestId = `clipboard-${crypto.randomUUID()}`;
      rememberOutgoingRequest(requestId);
      try {
        await sendMessage({
          type: "clipboard.create",
          requestId,
          content: text,
        });
      } catch (error) {
        state.outgoingRequests.delete(requestId);
        throw error;
      }
      showToast("内容已发送到电脑剪贴板列表");
    } else {
      return;
    }
    elements["message-input"].value = "";
    resizeComposerInput();
    clearSelectedFile();
  } catch (error) {
    showToast(error?.message || "发送失败，请检查连接");
  } finally {
    updateSendButton();
  }
}

async function sendFile(file) {
  if (file.size > maximumFileBytes) throw new Error("文件超过 25 MB");
  const transferId = `upload-${crypto.randomUUID()}`;
  await sendMessage({
    type: "file.start",
    transferId,
    name: file.name,
    size: file.size,
    mime: file.type || "application/octet-stream",
  });
  let index = 0;
  for (let offset = 0; offset < file.size; offset += fileChunkBytes) {
    const bytes = new Uint8Array(
      await file.slice(offset, offset + fileChunkBytes).arrayBuffer(),
    );
    await waitForDataChannelBuffer();
    await sendMessage({
      type: "file.chunk",
      transferId,
      index,
      data: bytesToBase64(bytes),
    });
    index += 1;
  }
  await sendMessage({ type: "file.end", transferId });
}

async function waitForDataChannelBuffer() {
  while (state.channel?.bufferedAmount > 1024 * 1024) {
    await new Promise((resolve) => setTimeout(resolve, 12));
  }
}

function receiveDownloadChunk(message) {
  const download = state.downloads.get(message.transferId);
  if (
    !download ||
    !Number.isSafeInteger(message.index) ||
    message.index < 0 ||
    message.index >= download.expectedChunks ||
    download.chunks[message.index] ||
    typeof message.data !== "string" ||
    message.data.length > maximumEncodedFileChunkLength
  ) {
    rejectDownload(message.transferId);
    return;
  }
  let bytes;
  try {
    bytes = base64UrlDecode(message.data.replace(/\+/g, "-").replace(/\//g, "_"));
  } catch {
    rejectDownload(message.transferId);
    return;
  }
  if (
    bytes.byteLength > fileChunkBytes ||
    download.received + bytes.byteLength > download.size ||
    download.received + bytes.byteLength > maximumFileBytes
  ) {
    rejectDownload(message.transferId);
    return;
  }
  download.chunks[message.index] = bytes;
  download.received += bytes.byteLength;
}

function beginDownload(message) {
  const transferId = message.transferId;
  const size = message.size;
  if (
    typeof transferId !== "string" ||
    transferId.length < 1 ||
    transferId.length > 128 ||
    !Number.isSafeInteger(size) ||
    size < 0 ||
    size > maximumFileBytes ||
    state.downloads.size >= maximumConcurrentDownloads
  ) {
    rejectDownload(transferId);
    return;
  }
  const rawName = typeof message.name === "string" ? message.name : "DingDong 文件";
  const safeName = rawName.split(/[\\/]/).filter(Boolean).at(-1)?.slice(0, 180);
  state.downloads.set(transferId, {
    itemId: message.itemId,
    name: safeName || "DingDong 文件",
    size,
    expectedChunks: Math.ceil(size / fileChunkBytes),
    chunks: [],
    received: 0,
  });
}

function rejectDownload(transferId) {
  if (typeof transferId === "string") state.downloads.delete(transferId);
  showToast("文件数据无效或超过 25 MB，已停止接收");
}

function finishDownload(transferId) {
  const download = state.downloads.get(transferId);
  state.downloads.delete(transferId);
  const completeChunks = download
    ? Array.from(
        { length: download.expectedChunks },
        (_, index) => download.chunks[index],
      )
    : [];
  if (
    !download ||
    download.received !== download.size ||
    completeChunks.some((chunk) => !chunk)
  ) {
    showToast("文件接收不完整，请重试");
    return;
  }
  const blob = new Blob(completeChunks);
  if (blob.size !== download.size) {
    showToast("文件接收不完整，请重试");
    return;
  }
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = download.name;
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 30_000);
  showToast("文件已准备好，离线前请保存到手机");
}

async function copyItem(item, button) {
  if (typeof item.content !== "string") return;
  try {
    await navigator.clipboard.writeText(item.content);
  } catch {
    const textarea = document.createElement("textarea");
    textarea.value = item.content;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.append(textarea);
    textarea.select();
    document.execCommand("copy");
    textarea.remove();
  }
  const previous = button.innerHTML;
  button.textContent = "已复制";
  setTimeout(() => (button.innerHTML = previous), 900);
}

function requestFile(item) {
  sendMessage({ type: "file.request", itemId: item.id }).catch((error) =>
    showToast(error?.message || "无法下载文件"),
  );
  showToast("正在从电脑获取文件…");
}

function render() {
  renderInstallPromotion();
  const hasPair = Boolean(state.pair);
  elements["pair-view"].hidden = true;
  elements["empty-view"].hidden = hasPair;
  elements["content-view"].hidden = !hasPair;
  elements.composer.hidden = !hasPair;
  if (hasPair) {
    elements["settings-device-name"].textContent = state.pair.hostName;
    renderConnectionState();
    renderTabs();
    renderClipboard();
    renderAgentEvents();
    renderSelectedFile();
    updateSendButton();
    requestAnimationFrame(refreshFeedPagerLayout);
    const notificationsActive = agentNotificationsActive();
    elements["notification-onboarding"].hidden =
      notificationsActive && state.notificationDeliveryHealthy !== false;
    elements["enable-notifications"].textContent = notificationsActive
      ? "检查"
      : "开启";
    renderAgentNotificationStatus();
  } else {
    elements["connection-label"].textContent = "等待连接";
  }
}

function notificationPermission() {
  return "Notification" in window ? Notification.permission : "unsupported";
}

function agentNotificationsActive() {
  return agentNotificationsAreActive(
    state.pair,
    notificationPermission(),
    state.pushSubscriptionReady,
  );
}

function renderAgentNotificationStatus() {
  if (!state.pair) return;
  const desired = wantsAgentNotifications(state.pair);
  elements["agent-notification-toggle"].checked = desired;
  elements["vibration-toggle"].disabled = !desired;
  elements["agent-notification-status"].textContent = agentNotificationsActive()
    ? state.notificationDeliveryHealthy === true
      ? "已开启 · 浏览器已创建通知"
      : state.notificationDeliveryHealthy === false
        ? "已开启 · 后台送达未通过"
        : "已开启 · 等待送达验证"
    : desired
      ? notificationPermission() === "granted"
        ? "默认开启 · 正在连接推送通道"
        : "默认开启 · 等待系统授权"
      : "已关闭";
}

function renderConnectionState() {
  if (!state.pair) return;
  elements["connection-label"].textContent = state.connectionSuperseded
    ? `${state.pair.hostName} · 已在另一窗口打开`
    : state.connected
      ? `${state.pair.hostName} · 在线`
      : state.connecting
        ? `${state.pair.hostName} · 连接中`
        : `${state.pair.hostName} · 离线`;
  elements["offline-title"].textContent = state.connectionSuperseded
    ? "连接已转移到另一个页面"
    : "电脑当前离线";
  elements["offline-copy"].textContent = state.connectionSuperseded
    ? "同一设备只保留最新打开的 DingDong；需要时可在这个页面重新连接。"
    : "断开后不会缓存电脑里的剪贴板内容。";
  elements["reconnect-button"].textContent = state.connectionSuperseded
    ? "在此连接"
    : "重新连接";
  elements["offline-banner"].hidden = state.connected;
}

function renderTabs() {
  contentTabButtons.forEach((button) => {
    const active = button.dataset.tab === state.activeTab;
    button.classList.toggle("is-active", active);
    button.setAttribute("aria-selected", String(active));
    button.tabIndex = active ? 0 : -1;
  });
  contentTabs.forEach((tab) => {
    const panel = elements[`${tab}-panel`];
    const active = tab === state.activeTab;
    panel.setAttribute("aria-hidden", String(!active));
    panel.inert = !active;
  });
}

function renderClipboard() {
  elements["clipboard-count"].textContent = String(state.items.length);
  elements["clipboard-list"].replaceChildren(
    ...state.items.map(createClipboardCard),
  );
  elements["clipboard-empty"].hidden = state.items.length > 0;
  invalidateFallbackFeedPanelHeight("clipboard");
}

function createClipboardCard(item) {
  const card = document.createElement("article");
  card.className = "clipboard-card";

  const main = document.createElement("div");
  main.className = "clipboard-card-main";
  const kind = document.createElement("div");
  kind.className = "kind-icon";
  const icon = document.createElement("img");
  icon.src = iconForKind(item.kind);
  icon.alt = "";
  kind.append(icon);

  const copy = document.createElement("div");
  copy.className = "clipboard-copy";
  const title = document.createElement("strong");
  title.textContent = item.title || kindLabel(item.kind);
  const content = document.createElement("p");
  content.textContent = item.sensitive
    ? "敏感内容未自动同步"
    : item.fileName
      ? `${item.fileName} · ${formatBytes(item.fileSize)}`
      : item.content || "内容不可用";
  copy.append(title, content);

  const action = document.createElement("button");
  action.className = "card-copy";
  action.type = "button";
  if (item.fileName) {
    action.textContent = item.downloadable === false ? "过大" : "下载";
    action.disabled = item.downloadable === false || !state.connected;
    action.addEventListener("click", () => requestFile(item));
  } else {
    const actionIcon = document.createElement("img");
    actionIcon.src = "../assets/symbols/copy.png";
    actionIcon.alt = "";
    action.append(actionIcon, document.createTextNode("复制"));
    action.disabled = item.sensitive || typeof item.content !== "string";
    action.addEventListener("click", () => copyItem(item, action));
  }
  main.append(kind, copy, action);

  const meta = document.createElement("div");
  meta.className = "clipboard-meta";
  const source = document.createElement("span");
  source.textContent = item.sources?.at(-1) || state.pair.hostName;
  const time = document.createElement("span");
  time.textContent = formatTime(item.updatedAt ? new Date(item.updatedAt) : new Date());
  meta.append(source, time);
  card.append(main, meta);
  return card;
}

function renderAgentEvents() {
  elements["agent-count"].textContent = String(state.agentEvents.length);
  elements["agent-list"].replaceChildren(
    ...state.agentEvents.map(createAgentCard),
  );
  elements["agent-empty"].hidden = state.agentEvents.length > 0;
  invalidateFallbackFeedPanelHeight("agent");
}

function createAgentCard(event) {
  const card = document.createElement("article");
  card.className = "agent-card";
  const header = document.createElement("div");
  header.className = "agent-card-header";
  const mascot = document.createElement("img");
  mascot.src = "../assets/dingdong-mobile-alert-icon-2.png";
  mascot.alt = "DingDong 提醒";
  const heading = document.createElement("div");
  const title = document.createElement("strong");
  title.textContent = event.title || "Agent 完成啦";
  const meta = document.createElement("span");
  meta.textContent = `${event.source || "Agent"} · ${formatTime(
    new Date(event.completedAt || Date.now()),
  )}`;
  heading.append(title, meta);
  header.append(mascot, heading);

  const summary = document.createElement("p");
  summary.className = "agent-summary";
  summary.textContent = event.summary || "本轮任务已经完成。";
  const detail = document.createElement("p");
  detail.className = "agent-detail";
  detail.textContent = event.detail || event.summary || "";
  card.append(header, summary);
  if (detail.textContent && detail.textContent !== summary.textContent) card.append(detail);
  if (event.workspacePath) {
    const workspace = document.createElement("p");
    workspace.className = "agent-workspace";
    workspace.textContent = `项目 · ${event.workspacePath.split(/[\\/]/).filter(Boolean).at(-1)}`;
    card.append(workspace);
  }
  return card;
}

function renderSelectedFile() {
  const file = state.selectedFile;
  elements["selected-file"].hidden = !file;
  elements["selected-file-name"].textContent = file
    ? `${file.name} · ${formatBytes(file.size)}`
    : "";
}

function clearSelectedFile() {
  state.selectedFile = null;
  elements["file-input"].value = "";
  renderSelectedFile();
  updateSendButton();
}

function resizeComposerInput() {
  const input = elements["message-input"];
  input.style.height = "auto";
  input.style.height = `${Math.min(input.scrollHeight, 112)}px`;
}

function updateSendButton() {
  elements["send-button"].disabled =
    !state.connected ||
    (!state.selectedFile && !elements["message-input"].value.trim());
}

async function enableAgentNotifications({
  requestPermission = true,
  markPreference = true,
  sendTest = true,
  syncEnabledToDesktop = true,
} = {}) {
  if (!state.pair) return false;
  const generation = state.notificationGeneration + 1;
  state.notificationGeneration = generation;
  if (sendTest) state.notificationVerificationInProgress = true;
  state.pair.agentNotificationsEnabled = true;
  state.pair.notificationEpoch = createNotificationEpoch();
  if (markPreference) state.pair.agentNotificationPreferenceSet = true;
  const pair = { ...state.pair };
  savePair();
  const workerPairWrite = persistPairForWorker(pair).then(
    () => true,
    () => false,
  );
  try {
    if (isIos() && !isStandalone()) {
      if (elements["notification-help-dialog"].open) {
        elements["notification-help-dialog"].close();
      }
      showInstallDialog({
        eyebrow: "iPhone / iPad 通知",
        title: "先添加到主屏幕",
        instructions:
          "iOS 只允许主屏幕 Web App 接收通知。请在 Safari 点“分享”→“添加到主屏幕”，再从桌面 DingDong 图标打开并开启提醒；不添加也能继续使用连接和内容传递。",
      });
      return false;
    }
    if (
      !("Notification" in window) ||
      !("serviceWorker" in navigator) ||
      !("PushManager" in window)
    ) {
      await showNotificationPermissionHelp("unsupported", "capability");
      return false;
    }
    let permission = Notification.permission;
    if (permission !== "granted" && requestPermission) {
      try {
        permission = await Notification.requestPermission();
      } catch {
        await showNotificationPermissionHelp("default", "permission");
        return false;
      }
    }
    if (!notificationContextIsCurrent(pair, generation)) return false;
    if (permission !== "granted") {
      await showNotificationPermissionHelp(permission, "permission");
      return false;
    }
    if (!(await workerPairWrite)) {
      if (!notificationContextIsCurrent(pair, generation)) return false;
      state.pushSubscriptionReady = false;
      await showNotificationPermissionHelp(
        "granted",
        "subscription",
        new Error("浏览器没有保存推送状态"),
      );
      return false;
    }
    ensureNotificationContext(pair, generation);
    try {
      await registerPushSubscription({ pair, generation });
      if (!notificationContextIsCurrent(pair, generation)) return false;
      state.pushSubscriptionReady = true;
    } catch (error) {
      if (isStaleNotificationOperation(error)) return false;
      state.pushSubscriptionReady = false;
      await showNotificationPermissionHelp("granted", "subscription", error);
      return false;
    }
    if (sendTest) {
      try {
        await sendTestPush({ pair, generation });
        if (!notificationContextIsCurrent(pair, generation)) return false;
        state.pushSubscriptionReady = true;
        state.notificationDeliveryHealthy = true;
        showToast("浏览器已创建测试通知；横幅与震动由系统设置控制");
      } catch (error) {
        if (isStaleNotificationOperation(error)) return false;
        state.pushSubscriptionReady = error?.channelBroken !== true;
        state.notificationDeliveryHealthy = false;
        try {
          await sendSettings();
        } catch {}
        await showNotificationPermissionHelp("granted", "delivery", error);
        return agentNotificationsActive();
      }
    }
    if (syncEnabledToDesktop) {
      try {
        await sendSettings();
      } catch {
        // An explicit phone setting is resent after the next user retry.
      }
    }
    return agentNotificationsActive();
  } finally {
    if (notificationContextIsCurrent(pair, generation)) {
      if (sendTest) state.notificationVerificationInProgress = false;
      if (!agentNotificationsActive()) sendSettings().catch(() => {});
    }
  }
}

async function recheckAgentNotifications() {
  if (state.notificationCheckInProgress) return;
  state.notificationCheckInProgress = true;
  const button = elements["notification-recheck"];
  const previousLabel = button.textContent;
  button.disabled = true;
  button.textContent = "检查中";
  try {
    const enabled = await enableAgentNotifications();
    if (
      enabled &&
      state.notificationDeliveryHealthy === true &&
      elements["notification-help-dialog"].open
    ) {
      elements["notification-help-dialog"].close();
    }
    render();
  } finally {
    state.notificationCheckInProgress = false;
    button.disabled = false;
    button.textContent = previousLabel;
  }
}

async function disableAgentNotifications() {
  if (!state.pair) return;
  const pair = state.pair;
  invalidateNotificationOperations();
  state.notificationDeliveryHealthy = null;
  state.pushSubscriptionReady = false;
  state.pushProviderStatus = null;
  state.pushDeviceReceipt = null;
  pair.agentNotificationsEnabled = false;
  pair.notificationEpoch = createNotificationEpoch();
  pair.agentNotificationPreferenceSet = true;
  const cleanupPair = { ...pair };
  savePair();
  try {
    await persistPairForWorker();
  } catch {}
  try {
    await sendSettings();
  } catch {}
  await cleanupPushSubscription(cleanupPair);
}

function cleanupPushSubscription(pair) {
  return queuePushMutation(() => performPushSubscriptionCleanup(pair));
}

async function performPushSubscriptionCleanup(pair) {
  if (await cleanupSupersededByActivePair(pair)) return;
  try {
    const registration =
      state.serviceWorkerRegistration ||
      (await navigator.serviceWorker?.getRegistration("./"));
    const subscription = await registration?.pushManager?.getSubscription();
    if (subscription) {
      await withTimeout(subscription.unsubscribe(), 5000, "取消旧推送订阅超时");
    }
  } catch {}
  if (await cleanupSupersededByActivePair(pair)) return;
  try {
    const token = await pushToken(pair.secret);
    await fetchWithTimeout(
      apiUrl(pair.relay, `v1/rooms/${pair.room}/subscription`),
      {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      },
      5000,
      "删除旧推送登记超时",
    );
  } catch {}
}

async function resetNotificationRuntime() {
  state.notificationDeliveryHealthy = null;
  state.pushSubscriptionReady = false;
  state.pushProvider = null;
  state.pushProviderStatus = null;
  state.pushDeviceReceipt = null;
  state.notificationVerificationInProgress = false;
  await idbDelete("push-health").catch(() => {});
}

function registerPushSubscription({
  force = false,
  pair = state.pair,
  generation = state.notificationGeneration,
} = {}) {
  return queuePushMutation(() =>
    createPushSubscription({ force, pair, generation }),
  );
}

async function createPushSubscription({ force, pair, generation }) {
  ensureNotificationContext(pair, generation);
  const configResponse = await fetchWithTimeout(
    apiUrl(pair.relay, "v1/config"),
    {},
    8000,
    "连接推送服务超时",
  );
  ensureNotificationContext(pair, generation);
  if (!configResponse.ok) throw new Error("无法读取推送服务配置");
  const config = await configResponse.json();
  if (!config.pushAvailable || !config.vapidPublicKey) {
    throw new Error("推送服务尚未配置");
  }
  const registration = await withTimeout(
    navigator.serviceWorker.ready,
    8000,
    "浏览器没有完成 Service Worker 启动",
  );
  ensureNotificationContext(pair, generation);
  const applicationServerKey = base64UrlDecode(config.vapidPublicKey);
  let subscription = await registration.pushManager.getSubscription();
  ensureNotificationContext(pair, generation);
  if (
    subscription &&
    (force ||
      !applicationServerKeysMatch(
        subscription.options?.applicationServerKey,
        applicationServerKey,
      ))
  ) {
    await subscription.unsubscribe();
    ensureNotificationContext(pair, generation);
    subscription = null;
  }
  if (!subscription) {
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey,
    });
    ensureNotificationContext(pair, generation);
  }
  const token = await pushToken(pair.secret);
  ensureNotificationContext(pair, generation);
  await ensureSharedNotificationContext(pair, generation);
  const response = await fetchWithTimeout(
    apiUrl(pair.relay, `v1/rooms/${pair.room}/subscription`),
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        token,
        subscription: subscription.toJSON(),
        supportedContentEncodings: Array.from(
          PushManager.supportedContentEncodings || [],
        ),
      }),
    },
    8000,
    "保存推送订阅超时",
  );
  ensureNotificationContext(pair, generation);
  await ensureSharedNotificationContext(pair, generation);
  const result = await response.json().catch(() => null);
  if (!response.ok || result?.registered !== true) {
    throw new Error("推送订阅保存失败");
  }
  state.pushProvider = result.provider || null;
  return subscription;
}

async function sendTestPush({
  pair,
  generation,
  allowSubscriptionRefresh = true,
}) {
  ensureNotificationContext(pair, generation);
  await ensureSharedNotificationContext(pair, generation);
  const key = await importAesKey(pair.secret);
  const messageId = `notification-test-${Date.now()}`;
  const envelope = await sealEnvelope(
    {
      type: "agent.completed",
      id: messageId,
      title: "DingDong 提醒已开启",
      detail: "以后 Agent 完成时，这里会显示更完整的任务结果。",
      vibrate: pair.vibrationEnabled !== false,
    },
    key,
  );
  ensureNotificationContext(pair, generation);
  const response = await fetchWithTimeout(
    apiUrl(pair.relay, `v1/push/${pair.room}`),
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${await pushToken(pair.secret)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ envelope, messageId }),
    },
    8000,
    "测试通知发送超时",
  );
  ensureNotificationContext(pair, generation);
  const result = await response.json().catch(() => null);
  if (
    allowSubscriptionRefresh &&
    (response.status === 404 || result?.reason === "subscription-expired")
  ) {
    await registerPushSubscription({ force: true, pair, generation });
    return sendTestPush({
      pair,
      generation,
      allowSubscriptionRefresh: false,
    });
  }
  state.pushProviderStatus = result;
  if (!response.ok || result?.accepted !== true) {
    throw notificationError("推送服务拒绝了测试消息，请重新登记通道", true);
  }
  const status = await waitForPushReceipt(messageId, pair, generation);
  if (status?.receipt?.stage === "created") return status;
  if (status?.receipt?.stage === "failed") {
    throw notificationError(
      `手机收到推送，但系统通知显示失败（${status.receipt.errorCode || "未知原因"}）`,
      false,
    );
  }
  throw notificationError(
    "推送服务已接收，但手机后台没有收到。中国版 Android 上通常是 Chrome 的 Google 基础服务或后台联网受限。",
    false,
  );
}

async function waitForPushReceipt(messageId, pair, generation) {
  const deadline = Date.now() + 12000;
  let status = null;
  while (Date.now() < deadline) {
    ensureNotificationContext(pair, generation);
    status = await readPushStatus(messageId, pair, generation).catch(
      (error) => {
        if (isStaleNotificationOperation(error)) throw error;
        return status;
      },
    );
    if (
      status?.receipt?.messageId === messageId &&
      ["created", "failed"].includes(status.receipt.stage)
    ) {
      return status;
    }
    await new Promise((resolve) => setTimeout(resolve, 650));
  }
  return status;
}

async function readPushStatus(
  messageId,
  pair = state.pair,
  generation = state.notificationGeneration,
) {
  if (!pair) return null;
  ensureNotificationContext(pair, generation);
  const statusUrl = new URL(
    apiUrl(pair.relay, `v1/push/${pair.room}/status`),
  );
  if (messageId) statusUrl.searchParams.set("messageId", messageId);
  const response = await fetchWithTimeout(
    statusUrl,
    {
      headers: {
        Authorization: `Bearer ${await pushToken(pair.secret)}`,
      },
    },
    5000,
    "读取手机通知状态超时",
  );
  ensureNotificationContext(pair, generation);
  if (!response.ok) return null;
  const status = await response.json();
  state.pushProvider = status.provider || state.pushProvider;
  state.pushProviderStatus = status.providerStatus || null;
  state.pushDeviceReceipt = status.receipt || null;
  return status;
}

function notificationError(message, channelBroken) {
  const error = new Error(message);
  error.channelBroken = channelBroken;
  return error;
}

function notificationContextIsCurrent(pair, generation) {
  return (
    generation === state.notificationGeneration &&
    pair?.agentNotificationsEnabled === true &&
    pairingsMatch(pair, state.pair) &&
    pair.notificationEpoch === state.pair?.notificationEpoch
  );
}

async function ensureSharedNotificationContext(pair, generation) {
  ensureNotificationContext(pair, generation);
  const workerPair = await idbGet("pair");
  ensureNotificationContext(pair, generation);
  if (workerNotificationPairMatches(pair, workerPair)) return;
  const error = new Error("通知操作已被另一个 DingDong 页面更新");
  error.code = "notification-operation-stale";
  throw error;
}

function workerNotificationPairMatches(expected, current) {
  return (
    expected?.agentNotificationsEnabled === true &&
    current?.agentNotificationsEnabled === true &&
    pairingsMatch(expected, current) &&
    expected.notificationEpoch === current.notificationEpoch
  );
}

async function cleanupSupersededByActivePair(cleanupPair) {
  const workerPair = await idbGet("pair").catch(() => null);
  return (
    workerPair?.agentNotificationsEnabled === true &&
    pairingsMatch(cleanupPair, workerPair)
  );
}

function ensureNotificationContext(pair, generation) {
  if (notificationContextIsCurrent(pair, generation)) return;
  const error = new Error("通知操作已过期");
  error.code = "notification-operation-stale";
  throw error;
}

function isStaleNotificationOperation(error) {
  return error?.code === "notification-operation-stale";
}

function invalidateNotificationOperations() {
  state.notificationGeneration += 1;
  state.notificationVerificationInProgress = false;
}

function createNotificationEpoch() {
  return typeof crypto.randomUUID === "function"
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function queuePushMutation(operation) {
  const run = () =>
    navigator.locks?.request
      ? navigator.locks.request("dingdong-push-mutation", operation)
      : operation();
  const pending = state.pushMutationTail.catch(() => {}).then(run);
  state.pushMutationTail = pending.catch(() => {});
  return pending;
}

function applicationServerKeysMatch(stored, configured) {
  if (!stored) return false;
  const left = new Uint8Array(stored);
  const right = new Uint8Array(configured);
  if (left.length !== right.length) return false;
  return left.every((value, index) => value === right[index]);
}

async function sendSettings() {
  await persistPairForWorker();
  if (!state.connected) return;
  await sendMessage({
    type: "settings.update",
    agentNotificationsEnabled: wantsAgentNotifications(state.pair),
    vibrationEnabled: state.pair.vibrationEnabled !== false,
  });
}

async function deleteDevice() {
  if (!state.pair) return;
  if (!confirm("删除后需要重新扫描电脑二维码才能连接。确定删除吗？")) return;
  await disableAgentNotifications();
  closeConnection();
  localStorage.removeItem(storageKeys.pair);
  await deletePairForWorker();
  state.pair = null;
  state.items = [];
  state.agentEvents = [];
  await resetNotificationRuntime();
  elements["settings-dialog"].close();
  render();
}

function closeConnection() {
  state.connectionGeneration += 1;
  state.relayGeneration += 1;
  clearTimeout(state.reconnectTimer);
  state.reconnectTimer = null;
  state.socket?.close();
  state.socket = null;
  closePeer();
  state.signalKey = null;
  state.relayFrames = Promise.resolve();
  state.incomingMessages = Promise.resolve();
  state.connected = false;
  state.connecting = false;
  state.relayHostPresent = false;
  state.helloSent = false;
  state.items = [];
  state.downloads.clear();
  state.outgoingRequests.clear();
}

function closePeer() {
  const channel = state.channel;
  const peer = state.peer;
  state.channel = null;
  state.peer = null;
  state.remoteCandidates = [];
  channel?.close();
  peer?.close();
}

function connectionError(error) {
  console.error(error);
  state.connecting = false;
  state.connected =
    state.channel?.readyState === "open" ||
    (state.relayHostPresent && state.socket?.readyState === WebSocket.OPEN);
  if (!state.connected) state.items = [];
  render();
}

function savePair() {
  if (!state.pair) return;
  localStorage.setItem(storageKeys.pair, JSON.stringify(state.pair));
  persistPairForWorker().catch(() => {});
}

async function restorePairFromWorker() {
  if (isStoredPairing(state.pair)) return;
  try {
    const persisted = await idbGet("pair");
    if (!isStoredPairing(persisted)) {
      state.pair = null;
      return;
    }
    state.pair = persisted;
    localStorage.setItem(storageKeys.pair, JSON.stringify(persisted));
  } catch {
    state.pair = null;
  }
}

async function restoreAgentLaunchIntent() {
  let intent;
  try {
    intent = await idbGet(agentLaunchIntentKey);
    await idbDelete(agentLaunchIntentKey);
  } catch {
    return;
  }
  if (
    intent?.tab !== "agent" ||
    !Number.isFinite(intent.createdAt) ||
    Date.now() - intent.createdAt > agentLaunchIntentTtlMs
  ) {
    return;
  }
  state.activeTab = "agent";
  if (
    typeof intent.room === "string" &&
    intent.room === state.pair?.room &&
    typeof intent.message?.id === "string"
  ) {
    receiveAgentEvent(intent.message, { requestNotification: false });
  }
}

async function restorePushHealthFromWorker() {
  try {
    const health = await idbGet("push-health");
    if (
      !health ||
      typeof health.stage !== "string" ||
      health.room !== state.pair?.room ||
      health.notificationEpoch !== state.pair?.notificationEpoch
    ) {
      return;
    }
    state.pushDeviceReceipt = health;
    state.notificationDeliveryHealthy =
      health.stage === "created"
        ? true
        : health.stage === "failed"
          ? false
          : null;
  } catch {}
}

function clearPairingFragment() {
  if (!location.hash) return;
  history.replaceState(null, "", location.pathname + location.search);
}

function loadIdentity() {
  const existing = loadJson(storageKeys.identity);
  if (existing?.id) return existing;
  const identity = {
    id: `phone-${crypto.randomUUID()}`,
    name: defaultDeviceName(),
    nameSource: "automatic",
    platform: isIos() ? "ios-pwa" : "mobile-pwa",
  };
  localStorage.setItem(storageKeys.identity, JSON.stringify(identity));
  return identity;
}

async function upgradeDefaultIdentityName() {
  if (!shouldUpgradeAutomaticDeviceName(state.identity)) return;
  const name = await detectDeviceName();
  if (!name || name === state.identity.name) return;
  state.identity.name = name;
  state.identity.nameSource = "automatic";
  localStorage.setItem(storageKeys.identity, JSON.stringify(state.identity));
}

function loadJson(key) {
  try {
    return JSON.parse(localStorage.getItem(key));
  } catch {
    return null;
  }
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
  const value = base64UrlDecode(envelope);
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
    const error = new Error("内容加密后超过传输上限，请改为选择文件发送");
    error.code = "relay-frame-too-large";
    throw error;
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

function iconForKind(kind) {
  const icons = {
    url: "../assets/symbols/link.png",
    command: "../assets/symbols/command.png",
    code: "../assets/symbols/code.png",
    json: "../assets/symbols/code.png",
    path: "../assets/symbols/path.png",
    file: "../assets/symbols/path.png",
    image: "../assets/symbols/image.png",
  };
  return icons[kind] || "../assets/symbols/text.png";
}

function kindLabel(kind) {
  const labels = {
    url: "链接",
    command: "命令",
    code: "代码",
    json: "JSON",
    path: "路径",
    file: "文件",
    image: "图片",
  };
  return labels[kind] || "文本";
}

function formatTime(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return "";
  return new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(value);
}

function formatBytes(value) {
  if (!Number.isFinite(value)) return "";
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${Math.round(value / 1024)} KB`;
  return `${(value / (1024 * 1024)).toFixed(1)} MB`;
}

function showToast(message) {
  clearTimeout(state.toastTimer);
  elements.toast.textContent = message;
  elements.toast.hidden = false;
  state.toastTimer = setTimeout(() => (elements.toast.hidden = true), 2200);
}

function isIos() {
  return (
    /iPhone|iPad|iPod/i.test(navigator.userAgent) ||
    (/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1)
  );
}

function isAndroid() {
  return /Android/i.test(navigator.userAgent);
}

function isStandalone() {
  return (
    window.matchMedia("(display-mode: standalone)").matches ||
    window.navigator.standalone === true
  );
}

function isMobileBrowser() {
  return (
    navigator.userAgentData?.mobile === true ||
    isAndroid() ||
    isIos()
  );
}

function initializeInstallState() {
  if (isStandalone()) {
    markInstallVerified();
    return;
  }
  if (!state.installRequestedAt) return;
  state.installStatus =
    Date.now() - state.installRequestedAt < installVerificationTimeoutMs
      ? "requested"
      : "stalled";
  scheduleInstallVerification();
}

function renderInstallPromotion() {
  const hidden = !isMobileBrowser() || isStandalone();
  elements["install-app-banner"].hidden = hidden;
  if (hidden) return;

  const presentations = {
    idle: {
      title: "添加到主屏幕（可选）",
      copy: isIos()
        ? "添加后可像 App 打开并接收完成提醒。"
        : "不添加也能直接连接、传内容和接收提醒。",
      button: state.installPrompt ? "添加" : "查看方法",
    },
    available: {
      title: "添加到主屏幕（可选）",
      copy: "不添加也能直接连接、传内容和接收提醒。",
      button: "添加",
    },
    prompting: {
      title: "等待浏览器确认",
      copy: "请完成浏览器显示的添加步骤。",
      button: "处理中",
    },
    requested: {
      title: "Chrome 正在添加 DingDong",
      copy: "请求已提交；网页可以继续使用。",
      button: "检查",
    },
    stalled: {
      title: "Chrome 没有完成添加",
      copy: "不影响网页使用，可以查看原因和重试方法。",
      button: "查看",
    },
    installed: {
      title: "系统中已找到 DingDong",
      copy: "当前仍在浏览器中，请从桌面图标打开 App 模式。",
      button: "查看",
    },
  };
  const presentation = presentations[state.installStatus] || presentations.idle;
  elements["install-app-title"].textContent = presentation.title;
  elements["install-app-copy"].textContent = presentation.copy;
  elements["install-app-button"].textContent = presentation.button;
  elements["install-app-button"].disabled = state.installStatus === "prompting";
}

async function installApp() {
  if (state.installStatus === "installed") {
    showInstallDialog({
      eyebrow: "已验证安装状态",
      title: "系统中已经有 DingDong",
      instructions: isAndroid()
        ? "请回到桌面查找 DingDong。若桌面仍没有入口，可在“设置 → 应用 → 管理应用”搜索 DingDong：能搜到表示应用已装好，只是桌面入口没有放置；再到系统的“管理桌面快捷方式”里允许 Chrome 添加入口。"
        : "请从手机桌面的 DingDong 图标打开；从图标启动后会进入独立的 App 界面。",
    });
    return;
  }
  if (state.installStatus === "requested") {
    await refreshInstallState();
    if (state.installStatus === "installed") return installApp();
    showInstallDialog({
      eyebrow: "安装状态",
      title: "Chrome 仍在处理",
      instructions:
        "Chrome 已经接收添加请求，但 WebAPK 还没有被系统确认安装。这个过程不影响网页连接、内容传递或 Android 通知；稍后可以再点“检查”。超过一分钟仍未完成时，会显示具体诊断方法。",
    });
    return;
  }
  if (state.installStatus === "stalled") {
    showInstallDialog({
      eyebrow: "安装没有完成",
      title: "卡在 Chrome 的应用安装阶段",
      instructions:
        "网页本身已通过安装检查，但 Chrome 没有完成 WebAPK 安装。你可以继续直接使用网页，或重启 Chrome 后从菜单重新选择“安装应用 / 添加到主屏幕”。要定位系统原因，可在 Chrome 地址栏打开 chrome://histograms/WebApk.Install.InstallResult 和 chrome://histograms/WebApk.Install.GooglePlayInstallResult，查看最新一项。",
    });
    return;
  }
  const prompt = state.installPrompt;
  if (prompt) {
    state.installStatus = "prompting";
    renderInstallPromotion();
    try {
      await prompt.prompt();
      const choice = await prompt.userChoice;
      state.installPrompt = null;
      if (choice?.outcome === "accepted") {
        markInstallRequested();
        showInstallDialog({
          eyebrow: "请求已提交",
          title: "等待 Chrome 完成添加",
          instructions:
            "接受安装请求不等于图标已经生成。DingDong 会继续检查系统状态；这段时间网页可以照常连接、传内容，Android 的完成提醒也不依赖安装。",
        });
        return;
      }
      clearInstallRequest();
      renderInstallPromotion();
      return;
    } catch {
      state.installPrompt = null;
      clearInstallRequest();
      renderInstallPromotion();
      return;
    }
  }
  showInstallDialog({
    eyebrow: "可选的主屏幕入口",
    title: "添加 DingDong",
    instructions: isIos()
      ? "在 Safari 中点“分享”，选择“添加到主屏幕”，再点“添加”。从桌面 DingDong 图标打开后会进入独立 App 界面，并且可以开启完成提醒；不添加也能继续使用网页。"
      : isAndroid()
        ? "打开 Chrome 右上角“⋮”，选择“安装应用”或“添加到主屏幕”。添加是可选的：普通网页也能连接、传内容并开启完成提醒。若 Chrome 一直显示“安装中”，请稍后再点这里查看安装状态。"
        : "请从浏览器菜单选择“添加到主屏幕”或“安装应用”。不添加也能继续使用网页。",
  });
}

function markInstallRequested() {
  if (state.installStatus === "installed") return;
  state.installRequestedAt = Date.now();
  state.installStatus = "requested";
  localStorage.setItem(storageKeys.installRequest, String(state.installRequestedAt));
  renderInstallPromotion();
  scheduleInstallVerification();
}

function markInstallVerified() {
  clearInstallRequest();
  state.installStatus = "installed";
  renderInstallPromotion();
}

function clearInstallRequest() {
  clearTimeout(state.installVerificationTimer);
  state.installVerificationTimer = null;
  state.installRequestedAt = 0;
  state.installStatus = "idle";
  localStorage.removeItem(storageKeys.installRequest);
}

async function refreshInstallState() {
  if (isStandalone()) {
    markInstallVerified();
    return true;
  }
  if (isAndroid() && typeof navigator.getInstalledRelatedApps === "function") {
    try {
      const applications = await navigator.getInstalledRelatedApps();
      if (applications.some(isCurrentWebApp)) {
        markInstallVerified();
        return true;
      }
    } catch {}
  }
  if (
    state.installRequestedAt &&
    Date.now() - state.installRequestedAt >= installVerificationTimeoutMs
  ) {
    clearTimeout(state.installVerificationTimer);
    state.installVerificationTimer = null;
    state.installStatus = "stalled";
    renderInstallPromotion();
    return false;
  }
  scheduleInstallVerification();
  return false;
}

function isCurrentWebApp(application) {
  if (application?.platform !== "webapp" || !application.url) return false;
  try {
    const manifestUrl = new URL("./manifest.webmanifest", window.location.href).href;
    const installedManifestUrl = new URL(application.url, window.location.href).href;
    if (installedManifestUrl !== manifestUrl) return false;
    if (!application.id) return true;
    const expectedId = new URL("/", window.location.origin).href;
    return new URL(application.id, window.location.href).href === expectedId;
  } catch {
    return false;
  }
}

function scheduleInstallVerification() {
  clearTimeout(state.installVerificationTimer);
  state.installVerificationTimer = null;
  if (state.installStatus !== "requested") return;
  const remaining = Math.max(
    0,
    installVerificationTimeoutMs - (Date.now() - state.installRequestedAt),
  );
  state.installVerificationTimer = setTimeout(
    () => refreshInstallState().catch(() => {}),
    Math.min(installVerificationIntervalMs, remaining || 1),
  );
}

function showInstallDialog({ eyebrow, title, instructions }) {
  elements["install-dialog-eyebrow"].textContent = eyebrow;
  elements["install-dialog-title"].textContent = title;
  elements["install-instructions"].textContent = instructions;
  if (!elements["install-dialog"].open) {
    elements["install-dialog"].showModal();
  }
}

async function showNotificationPermissionHelp(permission, stage, error) {
  const actualPermission =
    "Notification" in window ? Notification.permission : "unsupported";
  const subscription = await currentPushSubscription();
  if (actualPermission === "granted" && subscription) {
    await readPushStatus().catch(() => {});
  }
  const steps = [];
  let eyebrow = "通知设置";
  let title = "浏览器没有完成授权";
  let reason = "DingDong 读取到的网页通知权限还不是“允许”。";
  let note = "";

  if (permission === "unsupported" || stage === "capability") {
    title = "这个浏览器缺少推送能力";
    reason = "当前环境没有同时提供通知、Service Worker 和 Push API。";
    steps.push("请用最新版 Safari（iPhone / iPad）或 Chrome、Edge 等支持 Web Push 的浏览器打开。", "连接和内容传递仍然可以继续使用。");
  } else if (isIos() && !isStandalone()) {
    eyebrow = "iPhone / iPad 通知";
    title = "先从主屏幕打开 DingDong";
    reason = "iOS 只允许添加到主屏幕的 Web App 请求通知权限。";
    steps.push("在 Safari 点“分享”→“添加到主屏幕”。", "从桌面 DingDong 图标打开，再点“开启”。");
  } else if (stage === "subscription") {
    title = "通知已允许，推送通道未建立";
    reason = error?.message || "浏览器没有完成 Push 订阅。";
    steps.push("确认当前网络可以正常访问 DingDong。", "确认 Chrome 的系统通知仍然开启，然后点“重新检查”。");
  } else if (stage === "delivery") {
    title = state.pushProviderStatus?.accepted
      ? "推送服务已接收，手机后台没有回执"
      : "推送通道已建立，测试消息未送达";
    reason = error?.message || "手机没有确认系统通知已经显示。";
    if (state.pushProviderStatus?.accepted && isAndroid()) {
      steps.push(
        "确认 Chrome 的系统通知和 DingDong 网站通知都已允许。",
        "在系统里允许 Chrome 后台联网，并把 Chrome 的电池策略改为“不限制”后再测试。",
        "无需关闭所有悬浮窗；这一步检查的是 Chrome / Google 推送后台链路。",
      );
    } else {
      steps.push(
        "保持网络连接，确认 Chrome 的系统通知已允许。",
        "点“重新检查”会重新登记通道并发送一条测试提醒。",
      );
    }
  } else if (permission === "denied" || actualPermission === "denied") {
    title = "这个网站的通知被关闭了";
    reason = "请在系统或浏览器设置里把 DingDong 的网站通知改成“允许”。";
    if (isIos()) {
      steps.push("打开系统“设置 → 通知 → DingDong”。", "允许通知后回到 DingDong，页面会自动重新检查。");
    } else {
      steps.push("点 Chrome 地址栏左侧的网站信息图标。", "进入“权限 → 通知”，选择“允许”，然后回到本页。", "若网站权限已经允许，再确认系统“设置 → 通知 → Chrome”也已开启。");
    }
  } else {
    if (isAndroid()) {
      steps.push("点 Chrome 地址栏左侧的网站信息图标。", "进入“权限 → 通知”，选择“允许”，然后回到本页。", "也可以在 Chrome“设置 → 网站设置 → 通知”中为 DingDong 单独允许。");
      note = "如果系统明确提示有气泡或小窗遮挡，只需先收起当前可见的气泡 / 小窗再重试；无需关闭所有应用的悬浮窗权限。";
    } else {
      steps.push("在浏览器的网站权限中把 DingDong 通知改为“允许”。", "返回本页后点“重新检查”。");
    }
  }

  elements["notification-help-eyebrow"].textContent = eyebrow;
  elements["notification-help-title"].textContent = title;
  elements["notification-help-reason"].textContent = reason;
  setNotificationStatus(
    elements["notification-permission-status"],
    notificationPermissionLabel(actualPermission),
    actualPermission === "granted"
      ? "ready"
      : actualPermission === "denied"
        ? "blocked"
        : "waiting",
  );
  setNotificationStatus(
    elements["notification-subscription-status"],
    subscription ? "已建立" : "未建立",
    subscription ? "ready" : "waiting",
  );
  const providerAccepted = state.pushProviderStatus?.accepted === true;
  const providerFailed = state.pushProviderStatus?.accepted === false;
  setNotificationStatus(
    elements["notification-provider-status"],
    providerAccepted
      ? `${state.pushProvider || "推送服务"} 已接收`
      : providerFailed
        ? "发送失败"
        : "待测试",
    providerAccepted ? "ready" : providerFailed ? "blocked" : "waiting",
  );
  const receiptMatchesProvider =
    state.pushDeviceReceipt?.messageId &&
    state.pushDeviceReceipt.messageId === state.pushProviderStatus?.messageId;
  const receiptStage = receiptMatchesProvider
    ? state.pushDeviceReceipt.stage
    : null;
  setNotificationStatus(
    elements["notification-device-status"],
    receiptStage === "created"
      ? "浏览器已创建"
      : receiptStage === "received"
        ? "已收到，未确认显示"
        : receiptStage === "failed"
          ? "显示失败"
          : providerAccepted
            ? "未收到回执"
            : "待测试",
    receiptStage === "created"
      ? "ready"
      : receiptStage === "failed" || (providerAccepted && !receiptStage)
        ? "blocked"
        : "waiting",
  );
  elements["notification-help-steps"].replaceChildren(
    ...steps.map((step) => {
      const item = document.createElement("li");
      item.textContent = step;
      return item;
    }),
  );
  elements["notification-help-note"].textContent = note;
  elements["notification-help-note"].hidden = !note;
  if (!elements["notification-help-dialog"].open) {
    elements["notification-help-dialog"].showModal();
  }
}

function notificationPermissionLabel(permission) {
  return {
    granted: "已允许",
    denied: "已拒绝",
    default: "尚未允许",
    unsupported: "不支持",
  }[permission] || "未知";
}

function setNotificationStatus(element, label, status) {
  element.textContent = label;
  element.dataset.state = status;
}

async function currentPushSubscription() {
  if (!("serviceWorker" in navigator) || !("PushManager" in window)) return null;
  try {
    const registration =
      state.serviceWorkerRegistration ||
      (await navigator.serviceWorker.getRegistration("./"));
    return (await registration?.pushManager.getSubscription()) || null;
  } catch {
    return null;
  }
}

function handleVisibilityChange() {
  if (document.visibilityState !== "visible") return;
  refreshInstallState().catch(() => {});
  if (!("Notification" in window) || !elements["notification-help-dialog"].open) {
    render();
    return;
  }
  if (
    !state.notificationCheckInProgress &&
    state.pair &&
    wantsAgentNotifications(state.pair) &&
    Notification.permission === "granted" &&
    !agentNotificationsActive()
  ) {
    enableAgentNotifications({
      requestPermission: false,
      markPreference: false,
    }).then((enabled) => {
      if (
        enabled &&
        state.notificationDeliveryHealthy === true &&
        elements["notification-help-dialog"].open
      ) {
        elements["notification-help-dialog"].close();
      }
      render();
    });
    return;
  }
  showNotificationPermissionHelp(Notification.permission, "permission").catch(
    () => {},
  );
  render();
}

async function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) return null;
  try {
    return await navigator.serviceWorker.register("./service-worker.js", {
      scope: "./",
    });
  } catch {
    return null;
  }
}

async function persistPairForWorker(pair = state.pair) {
  if (!pair) return;
  await idbSet("pair", pair);
}

async function deletePairForWorker() {
  await idbDelete("pair");
}

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open("dingdong-device-link", 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains("settings")) {
        request.result.createObjectStore("settings");
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function idbSet(key, value) {
  const database = await openDatabase();
  await new Promise((resolve, reject) => {
    const transaction = database.transaction("settings", "readwrite");
    transaction.objectStore("settings").put(value, key);
    transaction.oncomplete = resolve;
    transaction.onerror = () => reject(transaction.error);
  });
  database.close();
}

async function idbGet(key) {
  const database = await openDatabase();
  const value = await new Promise((resolve, reject) => {
    const transaction = database.transaction("settings", "readonly");
    const request = transaction.objectStore("settings").get(key);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  database.close();
  return value;
}

async function idbDelete(key) {
  const database = await openDatabase();
  await new Promise((resolve, reject) => {
    const transaction = database.transaction("settings", "readwrite");
    transaction.objectStore("settings").delete(key);
    transaction.oncomplete = resolve;
    transaction.onerror = () => reject(transaction.error);
  });
  database.close();
}
