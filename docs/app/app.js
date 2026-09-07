import { createFileActions, downloadHistoryKey } from "./app-file-actions.js?shell=41";
import {
  defaultDeviceName,
  detectDeviceName,
  shouldUpgradeAutomaticDeviceName,
} from "./device-name.js";
import {
  applyAgentNotificationDefault,
  wantsAgentNotifications,
} from "./notification-policy.js?shell=41";
import {
  normalizePairingRegistry,
  pairingRegistryVersion,
  pairingsMatch,
} from "./pairing-state.js?shell=41";
import {
  adjacentContentTab,
  contentScrollIsSnapped,
  contentTabAtScrollPosition,
  contentTabs,
  isContentTab,
  parseContentTabLaunch,
} from "./content-navigation.js";
import { idbDelete, idbGet, idbSetMany } from "./app-storage.js?shell=41";
import { createInstallationController } from "./app-installation.js?shell=41";
import { createAgentNotificationController } from "./app-notifications.js?shell=41";
import { createAppRenderer } from "./app-rendering.js?shell=41";
import { createConnectionController } from "./app-connection.js?shell=41";
import { createDeviceSettingsController } from "./app-settings.js?shell=41";
import { createPairingController } from "./app-pairing.js?shell=41";
import { createContentTransferController } from "./app-content-transfer.js?shell=41";
import {
  isAndroid,
  isIos,
  isMobileBrowser,
  isStandalone,
} from "./app-platform.js?shell=41";

const storageKeys = {
  identity: "dingdong.identity.v1",
  pair: "dingdong.pair.v1",
  pairings: "dingdong.pairings.v2",
  iconStyle: "dingdong.icon-style.v1",
  pendingPair: "dingdong.pending-pair.v1",
  installRequest: "dingdong.install-request.v1",
  pwaInstalled: "dingdong.pwa-installed.v1",
};
const maximumFileBytes = 25 * 1024 * 1024;
const maximumClipboardTextBytes = 128 * 1024;
const maximumClipboardItemBytes = 160 * 1024;
const fileChunkBytes = 32 * 1024;
const maximumConcurrentDownloads = 4;
const maximumEncodedFileChunkLength = Math.ceil(fileChunkBytes / 3) * 4 + 4;
const initialReconnectDelayMs = 2400;
const maximumReconnectDelayMs = 30_000;
const installVerificationIntervalMs = 3000;
const installVerificationTimeoutMs = 60 * 1000;
const currentPwaVersion = "1.5.7";
const currentPwaShellVersion = 41;
const pwaUpdateCheckIntervalMs = 60 * 60 * 1000;
const notificationPermissionSettleIntervalMs = 160;
const notificationPermissionSettleAttempts = 10;
const directVibrationPattern = [300, 100, 300, 100, 600];
const maximumAgentSeenBatchSize = 40;
const agentLaunchIntentKey = "agent-launch-intent";
const agentLaunchIntentTtlMs = 5 * 60 * 1000;
const initialContentTab = consumeContentTabLaunch() || "clipboard";
const initialPairingRegistry = normalizePairingRegistry(
  loadJson(storageKeys.pairings),
  loadJson(storageKeys.pair),
);

const state = {
  booting: true,
  identity: loadIdentity(),
  sessions: new Map(
    initialPairingRegistry.pairings.map((pair) => [
      pair.room,
      createDeviceSession(pair),
    ]),
  ),
  activeRoom: initialPairingRegistry.activeRoom,
  iconStyle:
    localStorage.getItem(storageKeys.iconStyle) === "white" ? "white" : "soft",
  activeTab: initialContentTab,
  toastTimer: null,
  serviceWorkerRegistration: null,
  installPrompt: null,
  installStatus: "idle",
  installRequestedAt: Number(localStorage.getItem(storageKeys.installRequest)) || 0,
  installVerificationTimer: null,
  pwaUpdateAvailable: null,
  pwaUpdateCheckInProgress: false,
  pwaUpdateStatusMessage: `当前版本 ${currentPwaVersion} · 联网时自动保持最新`,
  lastPwaUpdateCheckAt: 0,
  pushMutationTail: Promise.resolve(),
  pendingPair: null,
  notificationPermissionStatus: "checking",
  notificationPermissionCheck: null,
  notificationPermissionHasResolved: false,
  lastBadgeCount: null,
  pendingDeleteRoom: null,
  deleteInProgress: false,
  clipboardRenderSignature: null,
  agentRenderSignature: null,
};

function createDeviceSession(pair) {
  applyAgentNotificationDefault(pair);
  return {
    pair,
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
    contentGeneration: 0,
    relayGeneration: 0,
    items: [],
    clipboardRenderRevision: 0,
    agentRuns: [],
    agentEvents: [],
    agentRenderRevision: 0,
    downloads: new Map(),
    outgoingRequests: new Set(),
    selectedFile: null,
    sending: false,
    draftText: "",
    lastSyncAt: null,
    reconnectTimer: null,
    reconnectDelayMs: initialReconnectDelayMs,
    notificationCheckInProgress: false,
    notificationDeliveryHealthy: null,
    pushSubscriptionReady: false,
    pushProvider: null,
    pushProviderStatus: null,
    pushDeviceReceipt: null,
    notificationGeneration: 0,
    notificationVerificationInProgress: false,
    agentSeenAcknowledgementScheduled: false,
    agentSeenAcknowledgementInFlight: false,
  };
}

function activeSession() {
  return state.sessions.get(state.activeRoom) || null;
}

function sessionForRoom(room) {
  return typeof room === "string" ? state.sessions.get(room) || null : null;
}

function sessionIsActive(session) {
  return Boolean(session && session === activeSession());
}

function pairingRegistrySnapshot() {
  return {
    version: pairingRegistryVersion,
    activeRoom: state.activeRoom,
    pairings: Array.from(state.sessions.values(), (session) => ({
      ...session.pair,
    })),
  };
}

const elements = Object.fromEntries(
  [
    "app-header",
    "connection-label",
    "device-status-button",
    "online-dot",
    "online-count",
    "app-mascot-frame",
    "settings-button",
    "install-app-banner",
    "install-app-title",
    "install-app-copy",
    "install-app-button",
    "boot-view",
    "pwa-launcher-view",
    "open-pwa-app-button",
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
    "notification-onboarding-title",
    "notification-onboarding-copy",
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
    "running-count",
    "agent-unseen-count",
    "last-sync-label",
    "clipboard-list",
    "clipboard-empty",
    "agent-list",
    "agent-empty",
    "agent-running-list",
    "agent-running-empty",
    "composer",
    "attach-button",
    "selected-file",
    "selected-file-name",
    "clear-file",
    "file-input",
    "message-input",
    "send-button",
    "composer-target",
    "device-switcher-dialog",
    "device-switcher-summary",
    "device-switcher-list",
    "settings-dialog",
    "settings-device-name",
    "agent-notification-toggle",
    "agent-notification-status",
    "vibration-toggle",
    "vibration-support-label",
    "vibration-test",
    "vibration-test-result",
    "pwa-update-button",
    "pwa-update-status",
    "icon-style-soft",
    "icon-style-white",
    "icon-style-note",
    "disconnect-device",
    "delete-device",
    "delete-device-dialog",
    "delete-device-name",
    "confirm-delete-device",
    "image-preview-dialog",
    "image-preview-title",
    "image-preview-image",
    "image-preview-status",
    "image-preview-close",
    "image-preview-save",
    "toast",
  ].map((id) => [id, document.getElementById(id)]),
);

const fileActions = createFileActions({
  elements,
  showToast,
  onChange(session) {
    session.clipboardRenderRevision += 1;
    if (sessionIsActive(session)) renderClipboard();
  },
});
window.addEventListener("pagehide", () => fileActions.closePreview());
window.addEventListener("storage", (event) => {
  if (event.key !== downloadHistoryKey && event.key !== null) return;
  for (const session of state.sessions.values()) session.clipboardRenderRevision += 1;
  renderClipboard();
});

// Browser installation and shell updates own their timers and status UI.
const {
  checkPwaUpdate,
  clearInstallRequest,
  initializeInstallState,
  installApp,
  isBrowserPwaLauncher,
  markInstallVerified,
  notificationsCanRunInCurrentSurface,
  openPwaApp,
  refreshInstallState,
  registerServiceWorker,
  renderInstallPromotion,
  renderPwaUpdateStatus,
  showInstallDialog,
  upgradePwaManually,
} = createInstallationController({
  state,
  elements,
  storageKeys,
  installVerificationIntervalMs,
  installVerificationTimeoutMs,
  currentPwaVersion,
  currentPwaShellVersion,
  pwaUpdateCheckIntervalMs,
  closeConnection: (...args) => closeConnection(...args),
  invalidateNotificationOperations: (...args) =>
    invalidateNotificationOperations(...args),
  persistPairingsForWorker,
  showToast,
});

// Notification state is isolated from connection and feed rendering state.
const {
  agentNotificationsActive,
  cleanupPushSubscription,
  disableAgentNotifications,
  enableAgentNotifications,
  invalidateNotificationOperations,
  notificationPermission,
  notifyAgentCompletion,
  readPushStatus,
  refreshNotificationPermission,
  registerPushSubscription,
  renderAgentNotificationStatus,
  resetNotificationRuntime,
  recheckAgentNotifications,
  showNotificationPermissionHelp,
} = createAgentNotificationController({
  state,
  elements,
  notificationPermissionSettleIntervalMs,
  notificationPermissionSettleAttempts,
  activeSession,
  sessionForRoom,
  sessionIsActive,
  notificationsCanRunInCurrentSurface,
  isAndroid,
  isIos,
  isStandalone,
  showInstallDialog,
  render,
  showToast,
  savePairings,
  persistPairingsForWorker,
  workerPairingRegistry,
  sendSettings: (...args) => sendSettings(...args),
  pushHealthKey,
});

const contentTabButtons = Array.from(document.querySelectorAll(".tab"));
let feedPagerScrollTimer = null;
let feedPagerScrolling = false;
let feedPagerWidth = 0;
let feedPagerSupportsScrollEnd = false;
let feedPagerTouchActive = false;
const feedPanelHeights = new Map();

const {
  clearSelectedFile,
  renderAgentEvents,
  renderClipboard,
  renderConnectionState,
  renderConnectionSummary,
  renderDeviceSwitcher,
  renderIconStyleChoices,
  renderSelectedFile,
  renderTabs,
  resizeComposerInput,
  scheduleAgentSeenAcknowledgement,
  selectDevice,
  setIconStyle,
  updateAppBadge,
  updateSendButton,
} = createAppRenderer({
  fileActions,
  state,
  elements,
  storageKeys,
  contentTabButtons,
  contentTabs,
  maximumAgentSeenBatchSize,
  activeSession,
  sessionForRoom,
  sessionIsActive,
  pairingRegistrySnapshot,
  persistPairingsForWorker,
  render,
  invalidateFallbackFeedPanelHeight,
  requestFile: (...args) => requestFile(...args),
  copyItem: (...args) => copyItem(...args),
  agentActivityKey: (...args) => agentActivityKey(...args),
  notificationsCanRunInCurrentSurface,
  sendMessage: (...args) => sendMessage(...args),
  currentSessionContext: (...args) => currentSessionContext(...args),
});

const { closeConnection, connect, currentSessionContext, sendMessage } =
  createConnectionController({
    state,
    initialReconnectDelayMs,
    maximumReconnectDelayMs,
    activeSession,
    render,
    savePairings,
    notificationPermission,
    sendSettings: (...args) => sendSettings(...args),
    receiveClipboardSnapshot: (...args) => receiveClipboardSnapshot(...args),
    upsertClipboardItem: (...args) => upsertClipboardItem(...args),
    handleRequestRejected: (...args) => handleRequestRejected(...args),
    receiveAgentEvent: (...args) => receiveAgentEvent(...args),
    receiveAgentState: (...args) => receiveAgentState(...args),
    beginDownload: (...args) => beginDownload(...args),
    receiveDownloadChunk: (...args) => receiveDownloadChunk(...args),
    finishDownload: (...args) => finishDownload(...args),
    clearDownloads: (...args) => clearDownloads(...args),
    showToast,
  });

const {
  confirmDeleteDevice,
  openSettingsDialog,
  requestDeleteDevice,
  sendSettings,
  testDeviceVibration,
} = createDeviceSettingsController({
  clearDownloadHistory: (room) => fileActions.history.clearRoom(room),
  state,
  elements,
  directVibrationPattern,
  activeSession,
  sessionForRoom,
  showToast,
  renderIconStyleChoices,
  renderAgentNotificationStatus,
  renderPwaUpdateStatus,
  persistPairingsForWorker,
  sendMessage,
  currentSessionContext,
  disableAgentNotifications,
  closeConnection,
  resetNotificationRuntime,
  savePairings,
  render,
});

const {
  capturePairingLaunch,
  clearPairingFragment,
  clearPendingPairingLaunch,
  confirmPairing,
  handleRuntimePairingLaunch,
  initializeLaunchQueue,
  showPairConfirmation,
} = createPairingController({
  state,
  elements,
  storageKeys,
  loadJson,
  showToast,
  sessionForRoom,
  createDeviceSession,
  selectDevice,
  selectContentTab,
  invalidateNotificationOperations,
  closeConnection,
  persistPairingsForWorker,
  cleanupPushSubscription,
  resetNotificationRuntime,
  savePairings,
  render,
  notificationsCanRunInCurrentSurface,
  isIos,
  isStandalone,
  enableAgentNotifications,
  connect,
});

const {
  agentActivityKey,
  beginDownload,
  clearDownloads,
  copyItem,
  finishDownload,
  handleRequestRejected,
  receiveAgentEvent,
  receiveAgentState,
  receiveClipboardSnapshot,
  receiveDownloadChunk,
  requestFile,
  sendComposerContent,
  upsertClipboardItem,
} = createContentTransferController({
  fileActions,
  elements,
  maximumFileBytes,
  maximumClipboardTextBytes,
  maximumClipboardItemBytes,
  fileChunkBytes,
  maximumConcurrentDownloads,
  maximumEncodedFileChunkLength,
  activeSession,
  sessionIsActive,
  renderClipboard,
  renderAgentEvents,
  updateAppBadge,
  notifyAgentCompletion,
  sendMessage,
  currentSessionContext,
  clearSelectedFile,
  resizeComposerInput,
  updateSendButton,
  showToast,
});

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
  markInstallVerified();
  refreshInstallState().catch(() => {});
});
document.addEventListener("visibilitychange", handleVisibilityChange);
window.addEventListener("hashchange", handleRuntimePairingLaunch);

const launchPair = capturePairingLaunch();
boot(launchPair);

async function boot(scannedPair) {
  wireInteractions();
  initializeLaunchQueue();
  initializeInstallState();
  render();
  const installStateReady = refreshInstallState();
  registerServiceWorker().then((registration) => {
    state.serviceWorkerRegistration = registration;
    checkPwaUpdate({ force: true, silent: true }).catch(() => {});
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
      if (!notificationsCanRunInCurrentSurface()) return;
      const session = sessionForRoom(event.data.room);
      if (session) {
        receiveAgentEvent(event.data.message, {
          requestNotification: false,
          session,
        });
      }
    }
    if (event.data?.type === "push.health") {
      if (!notificationsCanRunInCurrentSurface()) return;
      const session = sessionForRoom(event.data.room);
      if (!session) return;
      if (event.data.notificationEpoch !== session.pair.notificationEpoch) return;
      session.pushDeviceReceipt = {
        messageId: event.data.messageId,
        stage: event.data.stage,
        errorCode: event.data.errorCode,
      };
      session.notificationDeliveryHealthy =
        event.data.stage === "created"
          ? true
          : event.data.stage === "failed"
            ? false
            : null;
      if (sessionIsActive(session)) renderAgentNotificationStatus();
    }
  });
  if (isBrowserPwaLauncher()) {
    state.booting = false;
    render();
    await installStateReady;
    renderInstallPromotion();
    return;
  }
  await installStateReady;
  if (isBrowserPwaLauncher()) {
    state.booting = false;
    render();
    return;
  }
  refreshNotificationPermission();
  await Promise.all([upgradeDefaultIdentityName(), restorePairingsFromWorker()]);
  await Promise.all([restoreAgentLaunchIntent(), restorePushHealthFromWorker()]);
  let defaultsChanged = false;
  for (const session of state.sessions.values()) {
    defaultsChanged = applyAgentNotificationDefault(session.pair) || defaultsChanged;
  }
  if (defaultsChanged) savePairings();
  renderInstallPromotion();

  const scannedSession = scannedPair
    ? sessionForRoom(scannedPair.room)
    : null;
  const scannedPairMatches = Boolean(
    scannedSession && pairingsMatch(scannedSession.pair, scannedPair),
  );
  if (scannedPairMatches) {
    selectDevice(scannedSession.pair.room, { closeDialog: false });
    clearPairingFragment();
    clearPendingPairingLaunch();
  }
  try {
    await persistPairingsForWorker();
  } catch {
    // Local storage remains authoritative for this foreground launch. A later
    // mutation will retry the service-worker mirror.
  }
  if (isBrowserPwaLauncher()) {
    state.booting = false;
    render();
    return;
  }
  state.booting = false;
  if (state.sessions.size > 0) {
    for (const session of state.sessions.values()) {
      session.pushSubscriptionReady = false;
    }
    render();
    for (const session of state.sessions.values()) {
      if (!session.pair.manualDisconnect) connect(session);
      if (
        notificationsCanRunInCurrentSurface() &&
        wantsAgentNotifications(session.pair) &&
        notificationPermission() === "granted"
      ) {
        enableAgentNotifications({
          session,
          requestPermission: false,
          markPreference: false,
          sendTest: false,
          showHelp: false,
          syncEnabledToDesktop: true,
        }).then(() => render());
      }
    }
  } else {
    render();
  }
  if (scannedPair && !scannedPairMatches) {
    showPairConfirmation(scannedPair);
  }
  renderInstallPromotion();
}

function wireInteractions() {
  initializeFeedPager();
  elements["install-app-button"].addEventListener("click", installApp);
  elements["open-pwa-app-button"].addEventListener("click", openPwaApp);
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
  elements["device-status-button"].addEventListener("click", () => {
    if (state.booting) return;
    if (state.sessions.size === 0) {
      showToast("请先扫描电脑上的连接二维码");
      return;
    }
    renderDeviceSwitcher();
    elements["device-switcher-dialog"].showModal();
  });
  elements["reconnect-button"].addEventListener("click", () => {
    const session = activeSession();
    if (!session) return;
    session.pair.manualDisconnect = false;
    savePairings();
    connect(session);
  });
  elements["settings-button"].addEventListener("click", () => {
    if (!state.booting) openSettingsDialog();
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
      const session = activeSession();
      event.target.checked = wantsAgentNotifications(session?.pair);
      elements["vibration-toggle"].disabled =
        !wantsAgentNotifications(session?.pair);
      render();
    },
  );
  elements["vibration-toggle"].addEventListener("change", async (event) => {
    const session = activeSession();
    if (!session) return;
    session.pair.vibrationEnabled = event.target.checked;
    session.pair.notificationEpoch = createNotificationEpoch();
    savePairings();
    await sendSettings(session);
  });
  elements["vibration-test"].addEventListener("click", testDeviceVibration);
  elements["pwa-update-button"].addEventListener(
    "click",
    upgradePwaManually,
  );
  elements["icon-style-soft"].addEventListener("click", () => {
    setIconStyle("soft");
  });
  elements["icon-style-white"].addEventListener("click", () => {
    setIconStyle("white");
  });
  elements["disconnect-device"].addEventListener("click", () => {
    const session = activeSession();
    if (!session) return;
    session.pair.manualDisconnect = true;
    savePairings();
    closeConnection(session);
    elements["settings-dialog"].close();
    render();
  });
  elements["delete-device"].addEventListener("click", requestDeleteDevice);
  elements["confirm-delete-device"].addEventListener(
    "click",
    confirmDeleteDevice,
  );
  elements["delete-device-dialog"].addEventListener("close", () => {
    if (state.deleteInProgress || !state.pendingDeleteRoom) return;
    state.pendingDeleteRoom = null;
    openSettingsDialog();
  });
  contentTabButtons.forEach((button) => {
    button.addEventListener("click", () => {
      selectContentTab(button.dataset.tab, { animate: true });
    });
    button.addEventListener("keydown", handleContentTabKeydown);
  });
  elements["message-input"].addEventListener("input", () => {
    const session = activeSession();
    if (session) session.draftText = elements["message-input"].value;
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
    const session = activeSession();
    if (!session) return;
    session.selectedFile = file;
    renderSelectedFile();
    updateSendButton();
  });
  elements["clear-file"].addEventListener("click", clearSelectedFile);
  elements["attach-button"].addEventListener("click", () => {
    elements["file-input"].click();
  });
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
    scheduleAgentSeenAcknowledgement(activeSession());
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
  scheduleAgentSeenAcknowledgement(activeSession());
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
  const targetSession = sessionForRoom(message.room) || activeSession();
  if (typeof message.room === "string" && !sessionForRoom(message.room)) {
    document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close());
    selectContentTab(message.tab, { animate: true, reveal: true });
    return true;
  }
  if (targetSession && targetSession !== activeSession()) {
    selectDevice(targetSession.pair.room, { closeDialog: false });
  }
  if (
    typeof message.room === "string" &&
    message.room === targetSession?.pair.room &&
    message.message
  ) {
    receiveAgentEvent(message.message, {
      requestNotification: false,
      session: targetSession,
    });
  }
  document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close());
  selectContentTab(message.tab, { animate: true, reveal: true });
  return true;
}

function render() {
  renderInstallPromotion();
  const browserPwaLauncher = isBrowserPwaLauncher();
  elements["device-status-button"].disabled = state.booting;
  elements["settings-button"].disabled = state.booting;
  elements["app-header"].hidden = browserPwaLauncher;
  elements["pwa-launcher-view"].hidden = !browserPwaLauncher;
  elements["boot-view"].hidden = !state.booting || browserPwaLauncher;
  if (state.booting && !browserPwaLauncher) {
    elements["pair-view"].hidden = true;
    elements["empty-view"].hidden = true;
    elements["content-view"].hidden = true;
    elements.composer.hidden = true;
    elements["connection-label"].textContent = "正在恢复设备";
    elements["online-dot"].dataset.online = "loading";
    elements["online-count"].textContent = "读取中";
    elements["device-status-button"].setAttribute(
      "aria-label",
      "正在恢复已保存的设备连接",
    );
    return;
  }
  const session = activeSession();
  const hasPair = Boolean(session);
  const confirmingPair = Boolean(state.pendingPair);
  if (browserPwaLauncher) {
    elements["boot-view"].hidden = true;
    elements["pair-view"].hidden = true;
    elements["empty-view"].hidden = true;
    elements["content-view"].hidden = true;
    elements.composer.hidden = true;
    return;
  }
  elements["pair-view"].hidden = !confirmingPair;
  elements["empty-view"].hidden = confirmingPair || state.sessions.size > 0;
  elements["content-view"].hidden = confirmingPair || !hasPair;
  elements.composer.hidden = confirmingPair || !hasPair;
  if (hasPair) {
    elements["settings-device-name"].textContent = session.pair.hostName;
    if (elements["message-input"].value !== session.draftText) {
      elements["message-input"].value = session.draftText;
    }
    elements["composer-target"].textContent = `发送到 ${session.pair.hostName}`;
    renderConnectionState(session);
    renderTabs();
    renderClipboard();
    renderAgentEvents();
    renderSelectedFile();
    updateSendButton();
    requestAnimationFrame(refreshFeedPagerLayout);
    const notificationsActive = agentNotificationsActive(session);
    const permissionChecking = notificationPermission() === "checking";
    elements["notification-onboarding"].hidden =
      (notificationsActive && session.notificationDeliveryHealthy !== false);
    elements["notification-onboarding-title"].textContent = permissionChecking
      ? "正在检查通知权限"
      : "让任务状态及时提醒";
    elements["notification-onboarding-copy"].textContent = permissionChecking
      ? "请稍候，DingDong 正在确认系统通知权限。"
      : "Agent 完成或需要你处理时，收起 DingDong 也能收到通知。";
    elements["enable-notifications"].textContent = permissionChecking
      ? "检查中…"
      : notificationsActive
        ? "检查"
        : "开启";
    elements["enable-notifications"].disabled = permissionChecking;
    renderAgentNotificationStatus();
  } else {
    elements["connection-label"].textContent = "等待连接";
    elements["composer-target"].textContent = "";
  }
  updateAppBadge();
  renderConnectionSummary();
  renderIconStyleChoices();
  if (elements["device-switcher-dialog"].open) renderDeviceSwitcher();
}

function savePairings() {
  const registry = pairingRegistrySnapshot();
  localStorage.setItem(storageKeys.pairings, JSON.stringify(registry));
  const activePair = activeSession()?.pair;
  if (activePair) {
    localStorage.setItem(storageKeys.pair, JSON.stringify(activePair));
  } else {
    localStorage.removeItem(storageKeys.pair);
  }
  persistPairingsForWorker().catch(() => {});
}

async function restorePairingsFromWorker() {
  if (state.sessions.size > 0) return;
  try {
    const registry = await workerPairingRegistry();
    for (const pair of registry.pairings) {
      state.sessions.set(pair.room, createDeviceSession(pair));
    }
    state.activeRoom = registry.activeRoom;
    savePairings();
  } catch {
    state.sessions.clear();
    state.activeRoom = null;
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
  const session = sessionForRoom(intent.room);
  if (session) state.activeRoom = session.pair.room;
  if (
    typeof intent.room === "string" &&
    intent.room === session?.pair.room &&
    typeof intent.message?.id === "string"
  ) {
    receiveAgentEvent(intent.message, {
      requestNotification: false,
      session,
    });
  }
}

async function restorePushHealthFromWorker() {
  for (const session of state.sessions.values()) {
    try {
      const health =
        (await idbGet(pushHealthKey(session.pair.room))) ||
        (sessionIsActive(session) ? await idbGet("push-health") : null);
      if (
        !health ||
        typeof health.stage !== "string" ||
        health.room !== session.pair.room ||
        health.notificationEpoch !== session.pair.notificationEpoch
      ) {
        continue;
      }
      session.pushDeviceReceipt = health;
      session.notificationDeliveryHealthy =
        health.stage === "created"
          ? true
          : health.stage === "failed"
            ? false
            : null;
    } catch {}
  }
}

function pushHealthKey(room) {
  return `push-health:${room}`;
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

function showToast(message) {
  clearTimeout(state.toastTimer);
  elements.toast.textContent = message;
  elements.toast.hidden = false;
  state.toastTimer = setTimeout(() => (elements.toast.hidden = true), 2200);
}

async function handleVisibilityChange() {
  if (document.visibilityState !== "visible") return;
  const session = activeSession();
  refreshInstallState().catch(() => {});
  await refreshNotificationPermission({ force: true });
  checkPwaUpdate({ silent: true }).catch(() => {});
  if (!notificationsCanRunInCurrentSurface()) {
    render();
    return;
  }
  if (!("Notification" in window) || !elements["notification-help-dialog"].open) {
    render();
    return;
  }
  if (
    session &&
    !session.notificationCheckInProgress &&
    wantsAgentNotifications(session.pair) &&
    notificationPermission() === "granted" &&
    !agentNotificationsActive(session)
  ) {
    enableAgentNotifications({
      session,
      requestPermission: false,
      markPreference: false,
    }).then((enabled) => {
      if (
        enabled &&
        session.notificationDeliveryHealthy === true &&
        elements["notification-help-dialog"].open
      ) {
        elements["notification-help-dialog"].close();
      }
      render();
    });
    return;
  }
  showNotificationPermissionHelp(notificationPermission(), "permission").catch(
    () => {},
  );
  render();
}

async function persistPairingsForWorker() {
  const registry = pairingRegistrySnapshot();
  const activePair = activeSession()?.pair || null;
  await idbSetMany([
    ["pairings", registry],
    ["active-room", state.activeRoom],
    ["pair", activePair],
  ]);
}

async function workerPairingRegistry() {
  const [registry, legacyPair] = await Promise.all([
    idbGet("pairings").catch(() => null),
    idbGet("pair").catch(() => null),
  ]);
  return normalizePairingRegistry(registry, legacyPair);
}
