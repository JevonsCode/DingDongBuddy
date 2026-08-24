export function applyAgentNotificationDefault(pair) {
  if (!pair || Object.hasOwn(pair, "agentNotificationPreferenceSet")) {
    return false;
  }
  pair.agentNotificationsEnabled = true;
  pair.agentNotificationPreferenceSet = false;
  return true;
}

export function wantsAgentNotifications(pair) {
  return pair?.agentNotificationsEnabled === true;
}

export function agentNotificationsAreActive(
  pair,
  permission,
  subscriptionReady,
) {
  return (
    wantsAgentNotifications(pair) &&
    permission === "granted" &&
    subscriptionReady === true
  );
}

export function agentEventNeedsAttention(event) {
  return (
    event?.needsUserAttention === true ||
    event?.notificationKind === "attention"
  );
}

export function agentNotificationTitle(event) {
  const explicitTitle = normalizedNotificationText(event?.title);
  if (explicitTitle) return explicitTitle;
  return agentEventNeedsAttention(event)
    ? "Agent 需要你处理"
    : "Agent 完成啦";
}

export function agentNotificationBody(event, maximumLength = 260) {
  const task = normalizedNotificationText(event?.task);
  const detail = normalizedNotificationText(
    event?.detail || event?.summary,
  );
  const fallback = agentEventNeedsAttention(event)
    ? "请打开 Agent 提醒查看并继续处理。"
    : "本轮任务已经完成。";
  const body =
    task && detail && task !== detail ? `${task}：${detail}` : detail || task || fallback;
  return truncateNotificationText(body, maximumLength);
}

function normalizedNotificationText(value) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function truncateNotificationText(value, maximumLength) {
  const characters = Array.from(value);
  if (characters.length <= maximumLength) return value;
  return `${characters.slice(0, Math.max(0, maximumLength - 1)).join("")}…`;
}
