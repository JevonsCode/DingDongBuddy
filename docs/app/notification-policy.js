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
