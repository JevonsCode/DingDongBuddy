import { parseContentTabLaunch } from "./content-navigation.js";
import { base64UrlDecode } from "./app-codecs.js?shell=35";
import {
  isScannedPairing,
  pairingsMatch,
} from "./pairing-state.js?shell=35";

// QR launch capture, multi-device replacement, and explicit pairing confirmation.
export function createPairingController({
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
}) {
  function pairingFromFragment() {
    const raw = location.hash.startsWith("#pair=")
      ? location.hash.slice("#pair=".length)
      : null;
    if (!raw) return null;
    try {
      const decoded = JSON.parse(
        new TextDecoder().decode(base64UrlDecode(raw)),
      );
      if (!isScannedPairing(decoded)) {
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
      isScannedPairing(pending?.pair) &&
      Number.isFinite(pending?.capturedAt) &&
      Date.now() - pending.capturedAt <= 10 * 60 * 1000
    ) {
      return pending.pair;
    }
    clearPendingPairingLaunch();
    return null;
  }

  function handleRuntimePairingLaunch() {
    const scannedPair = capturePairingLaunch();
    if (!scannedPair) return false;
    const existingSession = sessionForRoom(scannedPair.room);
    if (existingSession && pairingsMatch(existingSession.pair, scannedPair)) {
      selectDevice(existingSession.pair.room, { closeDialog: false });
      clearPairingFragment();
      clearPendingPairingLaunch();
      return true;
    }
    showPairConfirmation(scannedPair);
    return true;
  }

  function initializeLaunchQueue() {
    if (!window.launchQueue?.setConsumer) return;
    window.launchQueue.setConsumer(({ targetURL }) => {
      let target;
      try {
        target = new URL(targetURL, location.href);
      } catch {
        return;
      }
      if (target.origin !== location.origin || target.pathname !== location.pathname) {
        return;
      }
      const contentLaunch = parseContentTabLaunch(target.href, location.origin);
      if (contentLaunch) {
        history.replaceState(null, "", contentLaunch.cleanPath);
        selectContentTab(contentLaunch.tab, { animate: false });
      }
      if (target.hash.startsWith("#pair=")) {
        history.replaceState(
          null,
          "",
          `${target.pathname}${target.search}${target.hash}`,
        );
        handleRuntimePairingLaunch();
      }
    });
  }

  function clearPendingPairingLaunch() {
    localStorage.removeItem(storageKeys.pendingPair);
  }

  function showPairConfirmation(pair) {
    state.pendingPair = pair;
    const existing = sessionForRoom(pair.room);
    elements["pair-title"].textContent = existing
      ? `重新连接“${pair.hostName || existing.pair.hostName || "DingDong 电脑"}”？`
      : `添加“${pair.hostName || "DingDong 电脑"}”？`;
    elements["pair-description"].textContent =
      "添加后会与已有电脑并列保存，各设备的剪贴板、文件和 Agent 提醒互不混合。优先局域网直连；无法直连时使用端到端加密中继，中继不保存内容。";
    elements["device-name"].value = state.identity.name;
    render();
  }

  async function confirmPairing() {
    const pair = state.pendingPair;
    if (!pair) return;
    const name = elements["device-name"].value.trim();
    if (!name) {
      elements["device-name"].focus();
      return;
    }
    const previousSession = sessionForRoom(pair.room);
    if (previousSession && !pairingsMatch(previousSession.pair, pair)) {
      invalidateNotificationOperations(previousSession);
      closeConnection(previousSession);
      const previousPairSnapshot = { ...previousSession.pair };
      state.sessions.delete(previousPairSnapshot.room);
      await persistPairingsForWorker().catch(() => {});
      await cleanupPushSubscription(previousPairSnapshot, previousSession);
      await resetNotificationRuntime(previousSession);
    }
    if (name !== state.identity.name) {
      state.identity.nameSource = "user";
    }
    state.identity.name = name;
    localStorage.setItem(storageKeys.identity, JSON.stringify(state.identity));
    const nextPair = {
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
    const session = createDeviceSession(nextPair);
    state.sessions.set(nextPair.room, session);
    state.activeRoom = nextPair.room;
    state.pendingPair = null;
    clearPairingFragment();
    clearPendingPairingLaunch();
    savePairings();
    render();
    const notificationSetup =
      notificationsCanRunInCurrentSurface() && (!isIos() || isStandalone())
        ? enableAgentNotifications({ session, markPreference: false })
        : Promise.resolve(false);
    connect(session);
    notificationSetup.then(() => render());
  }


  function clearPairingFragment() {
    if (!location.hash) return;
    history.replaceState(null, "", location.pathname + location.search);
  }


    return {
      capturePairingLaunch,
      clearPairingFragment,
      clearPendingPairingLaunch,
      confirmPairing,
      handleRuntimePairingLaunch,
      initializeLaunchQueue,
      showPairConfirmation,
    };
}
