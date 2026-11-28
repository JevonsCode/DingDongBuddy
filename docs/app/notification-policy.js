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

export const agentNotificationKindNames = Object.freeze([
  "completion",
  "attention",
]);

// Reminder kinds this phone rings for. Pairings saved before the choice
// existed receive both.
export function agentNotificationKinds(pair) {
  const kinds = Array.isArray(pair?.agentNotificationKinds)
    ? pair.agentNotificationKinds
    : agentNotificationKindNames;
  return agentNotificationKindNames.filter((kind) => kinds.includes(kind));
}

export function wantsAgentKind(pair, kind) {
  return agentNotificationKinds(pair).includes(kind);
}

export function agentEventKind(event) {
  return agentEventNeedsAttention(event) ? "attention" : "completion";
}

// Reminders that took longer than this to arrive are shown quietly, labelled
// with their delay, instead of ringing as if they were new.
export const lateAgentReminderMs = 10 * 60 * 1000;

export function agentReminderDelayMs(event, now = Date.now()) {
  const from = Math.min(
    ...[event?.sentAt, event?.completedAt]
      .map((value) => new Date(value || 0).getTime())
      .filter((value) => Number.isFinite(value) && value > 0),
  );
  if (!Number.isFinite(from)) return null;
  return Math.max(0, now - from);
}

export function formatReminderDelay(milliseconds) {
  const minutes = Math.floor(milliseconds / 60000);
  if (minutes < 1) return `${Math.max(1, Math.round(milliseconds / 1000))} 秒`;
  if (minutes < 60) return `${minutes} 分钟`;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? `${hours} 小时` : `${hours} 小时 ${rest} 分`;
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

// The system notification body: first what the Agent needs (or finished),
// then its whole message with line breaks, the task and project. Collapsed
// notifications show the first line; expanding shows the rest.
export function agentNotificationBody(event, maximumLength = 1500) {
  const attention = agentEventNeedsAttention(event);
  const message = paragraphText(event?.detail || event?.summary);
  const lead =
    (attention && requestLine(message)) ||
    firstLine(event?.summary || message) ||
    normalizedNotificationText(event?.task) ||
    (attention ? "请打开 Agent 提醒查看并继续处理。" : "本轮任务已经完成。");
  const parts = [lead];
  if (message && normalizedNotificationText(message) !== lead) parts.push(message);
  const task = normalizedNotificationText(event?.task);
  if (task && task !== normalizedNotificationText(message) && task !== lead) {
    parts.push(`任务：${truncateNotificationText(task, 400)}`);
  }
  return truncateNotificationText(parts.join("\n\n"), maximumLength);
}

const requestPattern =
  /(?:^|[，。；！？、,.;!?:：\s🟥])请(?![求假他她它])|需要你|需要您|等你|要你|[?？]$|please |need your|needs your|waiting for you/iu;

function requestLine(text) {
  for (const line of text.split("\n")) {
    const value = normalizedNotificationText(line);
    if (value && requestPattern.test(value)) return value;
  }
  return "";
}

function firstLine(text) {
  for (const line of String(text || "").split("\n")) {
    const value = normalizedNotificationText(line);
    if (value) return value;
  }
  return "";
}

function paragraphText(value) {
  return typeof value === "string"
    ? value
        .replace(/\r/g, "")
        .split("\n")
        .map((line) => line.replace(/[ \t]+/g, " ").trim())
        .join("\n")
        .replace(/\n{3,}/g, "\n\n")
        .trim()
    : "";
}

function normalizedNotificationText(value) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function truncateNotificationText(value, maximumLength) {
  const characters = Array.from(value);
  if (characters.length <= maximumLength) return value;
  return `${characters.slice(0, Math.max(0, maximumLength - 1)).join("")}…`;
}
