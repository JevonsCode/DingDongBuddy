import {
  agentNotificationsAreActive,
  wantsAgentNotifications,
} from "./notification-policy.js?shell=40";
import {
  pairingForRoom,
  pairingsMatch,
  shouldSkipPairingCleanup,
} from "./pairing-state.js?shell=40";
import {
  apiUrl,
  base64UrlDecode,
  fetchWithTimeout,
  importAesKey,
  pushToken,
  sealEnvelope,
  withTimeout,
} from "./app-codecs.js?shell=40";
import { idbDelete } from "./app-storage.js?shell=40";

// Notification permission, Web Push registration, delivery checks, and help UI.
export function createAgentNotificationController({
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
  sendSettings,
  pushHealthKey,
}) {
  function notifyAgentCompletion(message, session) {
    if (
      !notificationsCanRunInCurrentSurface() ||
      !wantsAgentNotifications(session?.pair) ||
      notificationPermission() !== "granted" ||
      !("serviceWorker" in navigator)
    ) {
      return;
    }
    notifyAgentCompletionThroughWorker(
      message,
      { ...session.pair },
      session.notificationGeneration,
      session,
    ).catch(() => {});
  }

  async function notifyAgentCompletionThroughWorker(
    message,
    pair,
    generation,
    session,
  ) {
    ensureNotificationContext(pair, generation, session);
    const registration = await withTimeout(
      navigator.serviceWorker.ready,
      5000,
      "Service Worker 尚未就绪",
    );
    ensureNotificationContext(pair, generation, session);
    if (!registration.active) throw new Error("Service Worker 尚未激活");
    registration.active.postMessage({
      type: "agent.completed.realtime",
      message,
      room: pair.room,
      notificationEpoch: pair.notificationEpoch,
    });
  }


  function notificationPermission() {
    return state.notificationPermissionStatus;
  }

  function normalizeNotificationPermission(permission) {
    if (permission === "granted" || permission === "denied") return permission;
    if (permission === "prompt" || permission === "default") return "default";
    return "unsupported";
  }

  async function readNotificationPermission({ settle = false } = {}) {
    if (!("Notification" in window)) return "unsupported";
    const directPermission = () =>
      normalizeNotificationPermission(Notification.permission);
    let currentPermission = directPermission();
    if (currentPermission !== "default") return currentPermission;
    let permissionStatus = null;
    try {
      permissionStatus = await navigator.permissions?.query({
        name: "notifications",
      });
      if (permissionStatus?.state === "granted") return "granted";
      if (permissionStatus?.state === "denied") return "denied";
    } catch {}
    if (!settle) return currentPermission;
    for (let attempt = 0; attempt < notificationPermissionSettleAttempts; attempt += 1) {
      await new Promise((resolve) =>
        setTimeout(resolve, notificationPermissionSettleIntervalMs),
      );
      currentPermission = directPermission();
      if (currentPermission !== "default") return currentPermission;
      if (permissionStatus?.state === "granted") return "granted";
      if (permissionStatus?.state === "denied") return "denied";
    }
    return currentPermission;
  }

  function refreshNotificationPermission({ force = false } = {}) {
    if (state.notificationPermissionCheck && !force) {
      return state.notificationPermissionCheck;
    }
    state.notificationPermissionStatus = "checking";
    renderAgentNotificationStatus();
    const check = readNotificationPermission({
      settle: !state.notificationPermissionHasResolved,
    })
      .then((permission) => {
        state.notificationPermissionStatus = permission;
        return permission;
      })
      .catch(() => {
        state.notificationPermissionStatus = "unsupported";
        return state.notificationPermissionStatus;
      })
      .finally(() => {
        if (state.notificationPermissionCheck === check) {
          state.notificationPermissionCheck = null;
        }
        state.notificationPermissionHasResolved = true;
        render();
      });
    state.notificationPermissionCheck = check;
    return check;
  }

  function agentNotificationsActive(session = activeSession()) {
    return agentNotificationsAreActive(
      session?.pair,
      notificationPermission(),
      session?.pushSubscriptionReady === true,
    );
  }

  function renderAgentNotificationStatus() {
    const session = activeSession();
    if (!session) return;
    const desired = wantsAgentNotifications(session.pair);
    const permission = notificationPermission();
    const permissionChecking = permission === "checking";
    elements["agent-notification-toggle"].checked = desired;
    elements["agent-notification-toggle"].disabled = permissionChecking;
    elements["vibration-toggle"].disabled = !desired || permissionChecking;
    elements["agent-notification-status"].textContent = permissionChecking
      ? "正在检查通知权限…"
      : agentNotificationsActive(session)
        ? session.notificationDeliveryHealthy === true
          ? "已开启 · 浏览器已创建通知"
          : session.notificationDeliveryHealthy === false
            ? "已开启 · 后台送达未通过"
            : "已开启 · 等待送达验证"
        : desired
          ? permission === "granted"
            ? "默认开启 · 正在连接推送通道"
            : "默认开启 · 等待系统授权"
          : "已关闭";
  }


  async function enableAgentNotifications({
    session = activeSession(),
    requestPermission = true,
    markPreference = true,
    sendTest = true,
    showHelp = true,
    syncEnabledToDesktop = true,
  } = {}) {
    if (!session || !notificationsCanRunInCurrentSurface()) return false;
    await refreshNotificationPermission();
    const generation = session.notificationGeneration + 1;
    session.notificationGeneration = generation;
    if (sendTest) session.notificationVerificationInProgress = true;
    session.pair.agentNotificationsEnabled = true;
    session.pair.notificationEpoch = createNotificationEpoch();
    if (markPreference) session.pair.agentNotificationPreferenceSet = true;
    const pair = { ...session.pair };
    savePairings();
    const workerPairWrite = persistPairingsForWorker().then(
      () => true,
      () => false,
    );
    try {
      if (isIos() && !isStandalone()) {
        if (!showHelp) return false;
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
        if (showHelp && sessionIsActive(session)) {
          await showNotificationPermissionHelp("unsupported", "capability");
        }
        return false;
      }
      let permission = notificationPermission();
      if (permission !== "granted" && requestPermission) {
        try {
          permission = normalizeNotificationPermission(
            await Notification.requestPermission(),
          );
          state.notificationPermissionStatus = permission;
          renderAgentNotificationStatus();
        } catch {
          state.notificationPermissionStatus = normalizeNotificationPermission(
            Notification.permission,
          );
          if (showHelp && sessionIsActive(session)) {
            await showNotificationPermissionHelp("default", "permission");
          }
          return false;
        }
      }
      if (!notificationContextIsCurrent(pair, generation, session)) return false;
      if (permission !== "granted") {
        if (showHelp && sessionIsActive(session)) {
          await showNotificationPermissionHelp(permission, "permission");
        }
        return false;
      }
      if (!(await workerPairWrite)) {
        if (!notificationContextIsCurrent(pair, generation, session)) return false;
        session.pushSubscriptionReady = false;
        if (showHelp && sessionIsActive(session)) {
          await showNotificationPermissionHelp(
            "granted",
            "subscription",
            new Error("浏览器没有保存推送状态"),
          );
        }
        return false;
      }
      ensureNotificationContext(pair, generation, session);
      try {
        await registerPushSubscription({ session, pair, generation });
        if (!notificationContextIsCurrent(pair, generation, session)) return false;
        session.pushSubscriptionReady = true;
      } catch (error) {
        if (isStaleNotificationOperation(error)) return false;
        session.pushSubscriptionReady = false;
        if (showHelp && sessionIsActive(session)) {
          await showNotificationPermissionHelp("granted", "subscription", error);
        }
        return false;
      }
      if (sendTest) {
        try {
          await sendTestPush({ session, pair, generation });
          if (!notificationContextIsCurrent(pair, generation, session)) return false;
          session.pushSubscriptionReady = true;
          session.notificationDeliveryHealthy = true;
          showToast("浏览器已创建测试通知；横幅与震动由系统设置控制");
        } catch (error) {
          if (isStaleNotificationOperation(error)) return false;
          session.pushSubscriptionReady = error?.channelBroken !== true;
          session.notificationDeliveryHealthy = false;
          try {
            await sendSettings(session);
          } catch {}
          if (showHelp && sessionIsActive(session)) {
            await showNotificationPermissionHelp("granted", "delivery", error);
          }
          return agentNotificationsActive(session);
        }
      }
      if (syncEnabledToDesktop) {
        try {
          await sendSettings(session);
        } catch {
          // An explicit phone setting is resent after the next user retry.
        }
      }
      return agentNotificationsActive(session);
    } finally {
      if (notificationContextIsCurrent(pair, generation, session)) {
        if (sendTest) session.notificationVerificationInProgress = false;
        if (!agentNotificationsActive(session)) {
          sendSettings(session).catch(() => {});
        }
      }
    }
  }

  async function recheckAgentNotifications() {
    const session = activeSession();
    if (!session || session.notificationCheckInProgress) return;
    session.notificationCheckInProgress = true;
    const button = elements["notification-recheck"];
    const previousLabel = button.textContent;
    button.disabled = true;
    button.textContent = "检查中";
    try {
      const enabled = await enableAgentNotifications({ session });
      if (
        enabled &&
        session.notificationDeliveryHealthy === true &&
        elements["notification-help-dialog"].open
      ) {
        elements["notification-help-dialog"].close();
      }
      render();
    } finally {
      session.notificationCheckInProgress = false;
      button.disabled = false;
      button.textContent = previousLabel;
    }
  }

  async function disableAgentNotifications(session = activeSession()) {
    if (!session) return;
    const pair = session.pair;
    invalidateNotificationOperations(session);
    session.notificationDeliveryHealthy = null;
    session.pushSubscriptionReady = false;
    session.pushProviderStatus = null;
    session.pushDeviceReceipt = null;
    pair.agentNotificationsEnabled = false;
    pair.notificationEpoch = createNotificationEpoch();
    pair.agentNotificationPreferenceSet = true;
    const cleanupPair = { ...pair };
    savePairings();
    try {
      await persistPairingsForWorker();
    } catch {}
    try {
      await sendSettings(session);
    } catch {}
    await cleanupPushSubscription(cleanupPair, session);
  }

  function cleanupPushSubscription(pair, session = sessionForRoom(pair?.room)) {
    return queuePushMutation(() => performPushSubscriptionCleanup(pair, session));
  }

  async function performPushSubscriptionCleanup(pair, session) {
    if (await cleanupSupersededByCurrentPair(pair)) return;
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
    if (await cleanupSupersededByCurrentPair(pair)) return;
    const hasOtherEnabledPair = Array.from(state.sessions.values()).some(
      (candidate) =>
        candidate !== session && wantsAgentNotifications(candidate.pair),
    );
    if (hasOtherEnabledPair) return;
    const sharedRegistry = await workerPairingRegistry().catch(() => null);
    if (
      sharedRegistry?.pairings.some(
        (candidate) =>
          candidate.room !== pair.room && wantsAgentNotifications(candidate),
      )
    ) {
      return;
    }
    try {
      const registration =
        state.serviceWorkerRegistration ||
        (await navigator.serviceWorker?.getRegistration("./"));
      const subscription = await registration?.pushManager?.getSubscription();
      if (subscription) {
        await withTimeout(subscription.unsubscribe(), 5000, "取消推送订阅超时");
      }
    } catch {}
  }

  async function resetNotificationRuntime(session) {
    if (!session) return;
    session.notificationDeliveryHealthy = null;
    session.pushSubscriptionReady = false;
    session.pushProvider = null;
    session.pushProviderStatus = null;
    session.pushDeviceReceipt = null;
    session.notificationVerificationInProgress = false;
    await idbDelete(pushHealthKey(session.pair.room)).catch(() => {});
  }

  function registerPushSubscription({
    force = false,
    session = activeSession(),
    pair = session?.pair,
    generation = session?.notificationGeneration,
  } = {}) {
    return queuePushMutation(() =>
      createPushSubscription({ force, pair, generation, session }),
    );
  }

  async function createPushSubscription({ force, pair, generation, session }) {
    ensureNotificationContext(pair, generation, session);
    const configResponse = await fetchWithTimeout(
      apiUrl(pair.relay, "v1/config"),
      {},
      8000,
      "连接推送服务超时",
    );
    ensureNotificationContext(pair, generation, session);
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
    ensureNotificationContext(pair, generation, session);
    const applicationServerKey = base64UrlDecode(config.vapidPublicKey);
    let subscription = await registration.pushManager.getSubscription();
    ensureNotificationContext(pair, generation, session);
    let subscriptionRebuilt = false;
    if (
      subscription &&
      (force ||
        !applicationServerKeysMatch(
          subscription.options?.applicationServerKey,
          applicationServerKey,
        ))
    ) {
      await subscription.unsubscribe();
      ensureNotificationContext(pair, generation, session);
      subscription = null;
      subscriptionRebuilt = true;
    }
    if (!subscription) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey,
      });
      ensureNotificationContext(pair, generation, session);
      subscriptionRebuilt = true;
    }
    const token = await pushToken(pair.secret);
    ensureNotificationContext(pair, generation, session);
    await ensureSharedNotificationContext(pair, generation, session);
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
    ensureNotificationContext(pair, generation, session);
    await ensureSharedNotificationContext(pair, generation, session);
    const result = await response.json().catch(() => null);
    if (!response.ok || result?.registered !== true) {
      throw new Error("推送订阅保存失败");
    }
    session.pushProvider = result.provider || null;
    if (subscriptionRebuilt) {
      await registerSubscriptionForOtherPairs(subscription, session);
    }
    return subscription;
  }

  async function registerSubscriptionForOtherPairs(subscription, currentSession) {
    for (const session of state.sessions.values()) {
      if (
        session === currentSession ||
        !wantsAgentNotifications(session.pair)
      ) {
        continue;
      }
      try {
        const token = await pushToken(session.pair.secret);
        const response = await fetchWithTimeout(
          apiUrl(
            session.pair.relay,
            `v1/rooms/${session.pair.room}/subscription`,
          ),
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
          "恢复其他电脑的推送订阅超时",
        );
        const result = await response.json().catch(() => null);
        session.pushSubscriptionReady =
          response.ok && result?.registered === true;
        session.pushProvider = result?.provider || session.pushProvider;
      } catch {
        session.pushSubscriptionReady = false;
      }
    }
  }

  async function sendTestPush({
    session,
    pair,
    generation,
    allowSubscriptionRefresh = true,
  }) {
    ensureNotificationContext(pair, generation, session);
    await ensureSharedNotificationContext(pair, generation, session);
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
    ensureNotificationContext(pair, generation, session);
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
    ensureNotificationContext(pair, generation, session);
    const result = await response.json().catch(() => null);
    if (
      allowSubscriptionRefresh &&
      (response.status === 404 || result?.reason === "subscription-expired")
    ) {
      await registerPushSubscription({ force: true, session, pair, generation });
      return sendTestPush({
        session,
        pair,
        generation,
        allowSubscriptionRefresh: false,
      });
    }
    session.pushProviderStatus = result;
    if (!response.ok || result?.accepted !== true) {
      throw notificationError("推送服务拒绝了测试消息，请重新登记通道", true);
    }
    const status = await waitForPushReceipt(
      messageId,
      pair,
      generation,
      session,
    );
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

  async function waitForPushReceipt(messageId, pair, generation, session) {
    const deadline = Date.now() + 12000;
    let status = null;
    while (Date.now() < deadline) {
      ensureNotificationContext(pair, generation, session);
      status = await readPushStatus(messageId, pair, generation, session).catch(
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
    pair = activeSession()?.pair,
    generation = activeSession()?.notificationGeneration,
    session = sessionForRoom(pair?.room),
  ) {
    if (!pair) return null;
    ensureNotificationContext(pair, generation, session);
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
    ensureNotificationContext(pair, generation, session);
    if (!response.ok) return null;
    const status = await response.json();
    session.pushProvider = status.provider || session.pushProvider;
    session.pushProviderStatus = status.providerStatus || null;
    session.pushDeviceReceipt = status.receipt || null;
    return status;
  }

  function notificationError(message, channelBroken) {
    const error = new Error(message);
    error.channelBroken = channelBroken;
    return error;
  }

  function notificationContextIsCurrent(pair, generation, session) {
    return (
      Boolean(session) &&
      state.sessions.get(pair?.room) === session &&
      generation === session.notificationGeneration &&
      pair?.agentNotificationsEnabled === true &&
      pairingsMatch(pair, session.pair) &&
      pair.notificationEpoch === session.pair.notificationEpoch
    );
  }

  async function ensureSharedNotificationContext(pair, generation, session) {
    ensureNotificationContext(pair, generation, session);
    const workerRegistry = await workerPairingRegistry();
    ensureNotificationContext(pair, generation, session);
    const workerPair = pairingForRoom(workerRegistry, pair.room);
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

  async function cleanupSupersededByCurrentPair(cleanupPair) {
    const workerRegistry = await workerPairingRegistry().catch(() => null);
    const workerPair = pairingForRoom(workerRegistry, cleanupPair?.room);
    return shouldSkipPairingCleanup(cleanupPair, workerPair);
  }

  function ensureNotificationContext(pair, generation, session) {
    if (notificationContextIsCurrent(pair, generation, session)) return;
    const error = new Error("通知操作已过期");
    error.code = "notification-operation-stale";
    throw error;
  }

  function isStaleNotificationOperation(error) {
    return error?.code === "notification-operation-stale";
  }

  function invalidateNotificationOperations(session = activeSession()) {
    if (!session) return;
    session.notificationGeneration += 1;
    session.notificationVerificationInProgress = false;
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


  async function showNotificationPermissionHelp(permission, stage, error) {
    const session = activeSession();
    const actualPermission = notificationPermission();
    const subscription = await currentPushSubscription();
    if (actualPermission === "granted" && subscription) {
      await readPushStatus().catch(() => {});
    }
    const steps = [];
    let eyebrow = "通知设置";
    let title = "浏览器没有完成授权";
    let reason = "DingDong 读取到的网页通知权限还不是“允许”。";
    let note = "";

    if (permission === "checking") {
      eyebrow = "通知设置";
      title = "正在读取通知权限";
      reason = "DingDong 正在向系统确认当前通知权限，请稍候。";
      steps.push("请保持当前页面打开，读取完成后状态会自动更新。", "如果系统权限已允许，DingDong 会继续检查推送通道。");
    } else if (permission === "unsupported" || stage === "capability") {
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
      title = session?.pushProviderStatus?.accepted
        ? "推送服务已接收，手机后台没有回执"
        : "推送通道已建立，测试消息未送达";
      reason = error?.message || "手机没有确认系统通知已经显示。";
      if (session?.pushProviderStatus?.accepted && isAndroid()) {
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
    const providerAccepted = session?.pushProviderStatus?.accepted === true;
    const providerFailed = session?.pushProviderStatus?.accepted === false;
    setNotificationStatus(
      elements["notification-provider-status"],
      providerAccepted
        ? `${session?.pushProvider || "推送服务"} 已接收`
        : providerFailed
          ? "发送失败"
          : "待测试",
      providerAccepted ? "ready" : providerFailed ? "blocked" : "waiting",
    );
    const receiptMatchesProvider =
      session?.pushDeviceReceipt?.messageId &&
      session.pushDeviceReceipt.messageId ===
        session.pushProviderStatus?.messageId;
    const receiptStage = receiptMatchesProvider
      ? session.pushDeviceReceipt.stage
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
      checking: "检查中…",
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


    return {
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
    };
}
