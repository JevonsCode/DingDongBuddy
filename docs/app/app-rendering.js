import {
  agentEventNeedsAttention,
  agentNotificationTitle,
} from "./notification-policy.js?shell=35";
import {
  formatBytes,
  formatDuration,
  formatLifecycleTime,
  formatTime,
  iconForKind,
  kindLabel,
  validDate,
} from "./app-formatters.js?shell=35";

// Feed rendering and direct UI interactions. Network and persistence stay injected.
export function createAppRenderer({
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
  requestFile,
  copyItem,
  agentActivityKey,
  notificationsCanRunInCurrentSurface,
  sendMessage,
  currentSessionContext,
}) {
  function renderConnectionState(session = activeSession()) {
    if (!session) return;
    elements["connection-label"].textContent = session.connectionSuperseded
      ? `${session.pair.hostName} · 已在另一窗口打开`
      : session.connected
        ? `${session.pair.hostName} · 在线`
        : session.connecting
          ? `${session.pair.hostName} · 连接中`
          : `${session.pair.hostName} · 离线`;
    elements["offline-title"].textContent = session.connectionSuperseded
      ? "连接已转移到另一个页面"
      : "电脑当前离线";
    elements["offline-copy"].textContent = session.connectionSuperseded
      ? "同一设备只保留最新打开的 DingDong；需要时可在这个页面重新连接。"
      : "断开后不会缓存电脑里的剪贴板内容。";
    elements["reconnect-button"].textContent = session.connectionSuperseded
      ? "在此连接"
      : "重新连接";
    elements["offline-banner"].hidden = session.connected;
  }

  function renderConnectionSummary() {
    const onlineCount = Array.from(state.sessions.values()).filter(
      (session) => session.connected,
    ).length;
    elements["online-dot"].dataset.online = String(onlineCount > 0);
    elements["online-count"].textContent = `${onlineCount} 台在线`;
    elements["device-status-button"].setAttribute(
      "aria-label",
      `${elements["connection-label"].textContent}，${onlineCount} 台在线，点击切换电脑`,
    );
  }

  function renderDeviceSwitcher() {
    const onlineCount = Array.from(state.sessions.values()).filter(
      (session) => session.connected,
    ).length;
    elements["device-switcher-summary"].textContent =
      `${onlineCount} 台在线 · 共 ${state.sessions.size} 台电脑`;
    elements["device-switcher-list"].replaceChildren(
      ...Array.from(state.sessions.values(), createDeviceSwitcherItem),
    );
  }

  function createDeviceSwitcherItem(session) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "device-switcher-item";
    button.classList.toggle("is-active", sessionIsActive(session));
    button.setAttribute("aria-current", sessionIsActive(session) ? "true" : "false");

    const icon = document.createElement("img");
    icon.src = "../assets/symbols/manage.png";
    icon.alt = "";
    const copy = document.createElement("span");
    copy.className = "device-switcher-copy";
    const name = document.createElement("strong");
    name.textContent = session.pair.hostName || "DingDong 电脑";
    const status = document.createElement("span");
    status.className = "device-switcher-status";
    const dot = document.createElement("i");
    dot.dataset.online = String(session.connected);
    const transport = session.connected
      ? session.channel?.readyState === "open"
        ? "在线 · 局域网直连"
        : "在线 · 端到端加密中继"
      : session.connecting
        ? "连接中"
        : session.connectionSuperseded
          ? "已在另一窗口打开"
          : "离线";
    status.append(dot, document.createTextNode(transport));
    copy.append(name, status);
    const current = document.createElement("span");
    current.className = "device-current-mark";
    current.textContent = sessionIsActive(session) ? "当前" : "切换";
    button.append(icon, copy, current);
    button.addEventListener("click", () => selectDevice(session.pair.room));
    return button;
  }

  function selectDevice(room, { closeDialog = true } = {}) {
    const session = sessionForRoom(room);
    if (!session) return false;
    const previousSession = activeSession();
    if (previousSession) {
      previousSession.draftText = elements["message-input"].value;
    }
    state.activeRoom = room;
    localStorage.setItem(storageKeys.pairings, JSON.stringify(pairingRegistrySnapshot()));
    localStorage.setItem(storageKeys.pair, JSON.stringify(session.pair));
    persistPairingsForWorker().catch(() => {});
    elements["file-input"].value = "";
    render();
    resizeComposerInput();
    if (closeDialog && elements["device-switcher-dialog"].open) {
      elements["device-switcher-dialog"].close();
    }
    return true;
  }

  function setIconStyle(style) {
    state.iconStyle = style === "white" ? "white" : "soft";
    localStorage.setItem(storageKeys.iconStyle, state.iconStyle);
    renderIconStyleChoices();
  }

  function renderIconStyleChoices() {
    document.documentElement.dataset.iconStyle = state.iconStyle;
    elements["app-mascot-frame"].dataset.iconStyle = state.iconStyle;
    for (const style of ["soft", "white"]) {
      const button = elements[`icon-style-${style}`];
      const selected = state.iconStyle === style;
      button.classList.toggle("is-selected", selected);
      button.setAttribute("aria-pressed", String(selected));
    }
    elements["icon-style-note"].textContent =
      state.iconStyle === "white"
        ? "已使用白色背景；主屏幕图标需重新添加后才可能由系统更新。"
        : "已使用浅蓝背景；主屏幕图标仍由手机系统在安装时生成。";
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
    const session = activeSession();
    if (!session) return;
    elements["clipboard-count"].textContent = String(session.items.length);
    elements["clipboard-list"].replaceChildren(
      ...session.items.map((item) => createClipboardCard(item, session)),
    );
    elements["clipboard-empty"].hidden = session.items.length > 0;
    elements["last-sync-label"].textContent = session.lastSyncAt
      ? formatTime(session.lastSyncAt)
      : "尚未同步";
    invalidateFallbackFeedPanelHeight("clipboard");
  }

  function createClipboardCard(item, session) {
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
      action.disabled = item.downloadable === false || !session.connected;
      action.addEventListener("click", () => requestFile(item, session));
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
    source.textContent = item.sources?.at(-1) || session.pair.hostName;
    const time = document.createElement("span");
    time.textContent = formatTime(item.updatedAt ? new Date(item.updatedAt) : new Date());
    meta.append(source, time);
    card.append(main, meta);
    return card;
  }

  function renderAgentEvents() {
    const session = activeSession();
    if (!session) return;
    const unseenCount = session.agentEvents.filter(
      (event) => event.unseen !== false,
    ).length;
    elements["agent-count"].textContent = String(unseenCount);
    elements["running-count"].textContent = String(session.agentRuns.length);
    elements["agent-unseen-count"].textContent = String(unseenCount);
    elements["agent-running-list"].replaceChildren(
      ...session.agentRuns.map(createAgentRunCard),
    );
    elements["agent-list"].replaceChildren(
      ...session.agentEvents.map(createAgentCard),
    );
    elements["agent-running-empty"].hidden = session.agentRuns.length > 0;
    elements["agent-empty"].hidden = session.agentEvents.length > 0;
    updateAppBadge();
    scheduleAgentSeenAcknowledgement(session);
    invalidateFallbackFeedPanelHeight("agent");
  }

  function updateAppBadge() {
    if (!notificationsCanRunInCurrentSurface()) return;
    const unseenCount = Array.from(state.sessions.values()).reduce(
      (count, session) =>
        count + session.agentEvents.filter((event) => event.unseen !== false).length,
      0,
    );
    if (state.lastBadgeCount === unseenCount) return;
    const method =
      unseenCount > 0 ? navigator.setAppBadge : navigator.clearAppBadge;
    if (typeof method !== "function") return;
    state.lastBadgeCount = unseenCount;
    const operation =
      unseenCount > 0
        ? method.call(navigator, unseenCount)
        : method.call(navigator);
    Promise.resolve(operation).catch(() => {
      state.lastBadgeCount = null;
    });
  }

  function scheduleAgentSeenAcknowledgement(session) {
    if (
      !sessionIsActive(session) ||
      state.activeTab !== "agent" ||
      document.visibilityState !== "visible" ||
      !session.connected ||
      session.agentSeenAcknowledgementScheduled ||
      session.agentSeenAcknowledgementInFlight
    ) {
      return;
    }
    session.agentSeenAcknowledgementScheduled = true;
    queueMicrotask(() => acknowledgeVisibleAgentEvents(session));
  }

  async function acknowledgeVisibleAgentEvents(session) {
    session.agentSeenAcknowledgementScheduled = false;
    if (
      !sessionIsActive(session) ||
      state.activeTab !== "agent" ||
      document.visibilityState !== "visible" ||
      !session.connected ||
      session.agentSeenAcknowledgementInFlight
    ) {
      return;
    }
    const activityIds = Array.from(
      new Set(
        session.agentEvents
          .filter((event) => event.unseen !== false)
          .map(agentActivityKey)
          .filter(
            (id) =>
              typeof id === "string" && id.length > 0 && id.length <= 160,
          ),
      ),
    ).slice(0, maximumAgentSeenBatchSize);
    if (activityIds.length === 0) return;

    session.agentSeenAcknowledgementInFlight = true;
    let sent = false;
    try {
      await sendMessage(
        { type: "agent.seen", activityIds },
        currentSessionContext(session),
      );
      sent = true;
    } catch {
      // Keep the unread state. A later render or reconnect will retry safely.
    } finally {
      session.agentSeenAcknowledgementInFlight = false;
    }
    if (!sent) return;

    const seenIds = new Set(activityIds);
    for (const event of session.agentEvents) {
      if (seenIds.has(agentActivityKey(event))) event.unseen = false;
    }
    if (sessionIsActive(session)) renderAgentEvents();
    else updateAppBadge();
  }

  function createAgentRunCard(run) {
    const card = document.createElement("article");
    card.className = "agent-card agent-card-running";
    const header = document.createElement("div");
    header.className = "agent-card-header";
    const mascot = document.createElement("img");
    mascot.src = "../assets/dingdong-thinking-icon.png";
    mascot.alt = "DingDong 正在运行";
    const heading = document.createElement("div");
    const title = document.createElement("strong");
    title.className = "agent-status";
    title.textContent = "正在运行";
    const meta = document.createElement("span");
    meta.textContent = run.source || "Agent";
    heading.append(title, meta);
    header.append(mascot, heading);

    const task = document.createElement("p");
    task.className = "agent-summary";
    task.textContent = run.task || "当前任务";
    card.append(header, task, createAgentTimeline(run, { running: true }));
    appendAgentWorkspace(card, run.workspacePath);
    return card;
  }

  function createAgentCard(event) {
    const card = document.createElement("article");
    const needsUserAttention = agentEventNeedsAttention(event);
    card.className = `agent-card${event.unseen === false ? "" : " is-unseen"}${needsUserAttention ? " needs-attention" : ""}`;
    const header = document.createElement("div");
    header.className = "agent-card-header";
    const mascot = document.createElement("img");
    mascot.src = "../assets/dingdong-mobile-alert-icon-2.png";
    mascot.alt = needsUserAttention ? "DingDong 等待你处理" : "DingDong 提醒";
    const heading = document.createElement("div");
    const title = document.createElement("strong");
    title.textContent = agentNotificationTitle(event);
    const meta = document.createElement("span");
    meta.textContent = `${event.source || "Agent"} · ${needsUserAttention ? "需要你处理" : "已完成"}`;
    heading.append(title, meta);
    header.append(mascot, heading);

    const summary = document.createElement("p");
    summary.className = "agent-summary";
    summary.textContent =
      event.summary ||
      (needsUserAttention ? "请查看详情并继续处理。" : "本轮任务已经完成。");
    const detail = document.createElement("p");
    detail.className = "agent-detail";
    detail.textContent = event.detail || event.summary || "";
    card.append(header, summary, createAgentTimeline(event));
    if (detail.textContent && detail.textContent !== summary.textContent) card.append(detail);
    appendAgentWorkspace(card, event.workspacePath);
    return card;
  }

  function createAgentTimeline(event, { running = false } = {}) {
    const timeline = document.createElement("div");
    timeline.className = "agent-timeline";
    const startedAt = validDate(event.startedAt);
    const completedAt = running ? null : validDate(event.completedAt);
    timeline.append(
      createAgentTimeItem("开始", startedAt ? formatLifecycleTime(startedAt) : "未记录"),
      createAgentTimeItem("结束", running ? "运行中" : completedAt ? formatLifecycleTime(completedAt) : "未记录"),
    );
    if (startedAt && completedAt && completedAt >= startedAt) {
      timeline.append(
        createAgentTimeItem(
          "总耗时",
          formatDuration(completedAt.getTime() - startedAt.getTime()),
          "agent-duration",
        ),
      );
    }
    return timeline;
  }

  function createAgentTimeItem(label, value, extraClass = "") {
    const item = document.createElement("div");
    item.className = `agent-time-item${extraClass ? ` ${extraClass}` : ""}`;
    const name = document.createElement("span");
    name.textContent = label;
    const text = document.createElement("strong");
    text.textContent = value;
    item.append(name, text);
    return item;
  }

  function appendAgentWorkspace(card, workspacePath) {
    if (!workspacePath) return;
    const workspace = document.createElement("p");
    workspace.className = "agent-workspace";
    workspace.textContent = `项目 · ${workspacePath.split(/[\\/]/).filter(Boolean).at(-1)}`;
    card.append(workspace);
  }

  function renderSelectedFile() {
    const file = activeSession()?.selectedFile || null;
    elements["selected-file"].hidden = !file;
    elements["selected-file-name"].textContent = file
      ? `${file.name} · ${formatBytes(file.size)}`
      : "";
  }

  function clearSelectedFile() {
    const session = activeSession();
    if (session) session.selectedFile = null;
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
    const session = activeSession();
    elements["send-button"].disabled =
      !session?.connected ||
      (!session.selectedFile && !elements["message-input"].value.trim());
  }


    return {
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
    };
}
