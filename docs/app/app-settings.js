import { wantsAgentNotifications } from "./notification-policy.js?shell=47";

// Connected-device settings, capability diagnostics, and destructive actions.
export function createDeviceSettingsController({
  clearDownloadHistory = () => {},
  state,
  elements,
  activeSession,
  sessionForRoom,
  showToast,
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
}) {
  function openSettingsDialog() {
    const session = activeSession();
    if (!session) {
      showToast("请先扫描电脑上的连接二维码");
      return;
    }
    elements["settings-device-name"].textContent =
      session.pair.hostName || "连接设置";
    elements["agent-notification-toggle"].checked =
      wantsAgentNotifications(session.pair);
    elements["vibration-toggle"].checked =
      session.pair.vibrationEnabled !== false;
    elements["vibration-toggle"].disabled =
      !wantsAgentNotifications(session.pair);
    renderAgentNotificationStatus();
    renderPwaUpdateStatus();
    if (!elements["settings-dialog"].open) {
      elements["settings-dialog"].showModal();
    }
  }


  async function sendSettings(session = activeSession()) {
    if (!session) return;
    await persistPairingsForWorker();
    if (!session.connected) return;
    await sendMessage(
      {
        type: "settings.update",
        agentNotificationsEnabled: wantsAgentNotifications(session.pair),
        vibrationEnabled: session.pair.vibrationEnabled !== false,
      },
      currentSessionContext(session),
    );
  }

  function requestDeleteDevice() {
    const session = activeSession();
    if (!session) return;
    state.pendingDeleteRoom = session.pair.room;
    elements["delete-device-name"].textContent =
      session.pair.hostName || "这台电脑";
    elements["settings-dialog"].close();
    elements["delete-device-dialog"].showModal();
  }

  async function confirmDeleteDevice() {
    const session = sessionForRoom(state.pendingDeleteRoom);
    if (!session || state.deleteInProgress) return;
    state.deleteInProgress = true;
    elements["confirm-delete-device"].disabled = true;
    elements["confirm-delete-device"].textContent = "删除中…";
    try {
      await disableAgentNotifications(session);
      await session.fileTransfers?.dispose({ remove: true });
      closeConnection(session);
      state.sessions.delete(session.pair.room);
      clearDownloadHistory(session.pair.room);
      state.activeRoom = state.sessions.keys().next().value || null;
      await resetNotificationRuntime(session);
      savePairings();
      state.pendingDeleteRoom = null;
      elements["delete-device-dialog"].close();
      render();
    } catch (error) {
      showToast(error?.message || "删除设备失败，请稍后重试");
    } finally {
      state.deleteInProgress = false;
      elements["confirm-delete-device"].disabled = false;
      elements["confirm-delete-device"].textContent = "删除设备";
    }
  }


    return {
      confirmDeleteDevice,
      openSettingsDialog,
      requestDeleteDevice,
      sendSettings,
    };
}
