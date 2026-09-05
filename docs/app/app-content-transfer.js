import {
  base64UrlDecode,
  bytesToBase64,
  utf8ByteLength,
} from "./app-codecs.js?shell=40";
import { formatBytes, validDate } from "./app-formatters.js?shell=40";

// Bounded clipboard/file transfer plus in-memory Agent feed reconciliation.
export function createContentTransferController({
  elements,
  maximumFileBytes,
  maximumClipboardTextBytes,
  maximumClipboardItemBytes,
  fileChunkBytes,
  maximumConcurrentDownloads,
  maximumEncodedFileChunkLength,
  downloadIdleTimeoutMs = 60_000,
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
}) {
  function receiveClipboardSnapshot(message, session) {
    if (message.reset !== false) session.items = [];
    let rejected = false;
    for (const item of Array.isArray(message.items) ? message.items : []) {
      if (!clipboardItemFitsTransferBoundary(item)) {
        rejected = true;
        continue;
      }
      mergeClipboardItem(item, session);
    }
    sortItems(session);
    session.items = session.items.slice(0, 50);
    if (message.complete !== false) {
      session.lastSyncAt = new Date();
    }
    session.clipboardRenderRevision += 1;
    if (sessionIsActive(session)) renderClipboard();
    if (rejected && sessionIsActive(session)) {
      showToast("部分文字超过传输上限，请在电脑上改为发送文件");
    }
  }

  function upsertClipboardItem(item, session) {
    if (!clipboardItemFitsTransferBoundary(item)) {
      if (sessionIsActive(session)) {
        showToast("这条文字超过传输上限，请在电脑上改为发送文件");
      }
      return;
    }
    mergeClipboardItem(item, session);
    sortItems(session);
    session.items = session.items.slice(0, 50);
    session.lastSyncAt = new Date();
    session.clipboardRenderRevision += 1;
    if (sessionIsActive(session)) renderClipboard();
  }

  function mergeClipboardItem(item, session) {
    const index = session.items.findIndex((value) => value.id === item.id);
    if (index >= 0) session.items[index] = item;
    else session.items.unshift(item);
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

  function handleRequestRejected(message, session) {
    const requestId = message.requestId;
    if (
      message.requestType !== "clipboard.create" ||
      message.code !== "text_too_large" ||
      typeof requestId !== "string" ||
      !session.outgoingRequests.delete(requestId)
    ) {
      return;
    }
    const maximumBytes = Number.isSafeInteger(message.maximumBytes)
      ? message.maximumBytes
      : maximumClipboardTextBytes;
    if (sessionIsActive(session)) {
      showToast(`电脑拒绝了过大的文字（上限 ${formatBytes(maximumBytes)}），请改为发送文件`);
    }
  }

  function rememberOutgoingRequest(requestId, session) {
    session.outgoingRequests.add(requestId);
    setTimeout(() => session.outgoingRequests.delete(requestId), 30_000);
  }

  function sortItems(session) {
    session.items.sort(
      (left, right) =>
        new Date(right.updatedAt || 0).getTime() -
        new Date(left.updatedAt || 0).getTime(),
    );
  }

  function receiveAgentEvent(
    message,
    { requestNotification = true, session = activeSession() } = {},
  ) {
    if (!session) return;
    if (!message?.id) return;
    const key = agentActivityKey(message);
    const index = session.agentEvents.findIndex(
      (value) => agentActivityKey(value) === key,
    );
    const existing = index >= 0 ? session.agentEvents[index] : null;
    const incomingCompletedAt = validDate(message.completedAt)?.getTime() || 0;
    const existingCompletedAt = validDate(existing?.completedAt)?.getTime() || 0;
    const event = {
      ...existing,
      ...message,
      unseen:
        existing && incomingCompletedAt <= existingCompletedAt
          ? existing.unseen !== false
          : message.unseen !== false,
    };
    if (index >= 0) session.agentEvents[index] = event;
    else session.agentEvents.unshift(event);
    sortAgentEvents(session);
    session.agentEvents = session.agentEvents.slice(0, 50);
    session.agentRenderRevision += 1;
    if (sessionIsActive(session)) renderAgentEvents();
    else updateAppBadge();
    if (requestNotification) notifyAgentCompletion(message, session);
  }

  function receiveAgentState(message, session) {
    if (!session) return;
    session.agentRuns = (Array.isArray(message.running) ? message.running : [])
      .filter((run) => run && typeof run.id === "string")
      .sort(
        (left, right) =>
          (validDate(right.startedAt)?.getTime() || 0) -
          (validDate(left.startedAt)?.getTime() || 0),
      )
      .slice(0, 50);
    session.agentEvents = (
      Array.isArray(message.completed) ? message.completed : []
    )
      .filter((event) => event && typeof event.id === "string")
      .slice(0, 50);
    sortAgentEvents(session);
    session.agentRenderRevision += 1;
    if (sessionIsActive(session)) renderAgentEvents();
    else updateAppBadge();
  }

  function agentActivityKey(event) {
    return event?.activityId || event?.id || "";
  }

  function sortAgentEvents(session) {
    session.agentEvents.sort(
      (left, right) =>
        (validDate(right.completedAt)?.getTime() || 0) -
        (validDate(left.completedAt)?.getTime() || 0),
    );
  }

  async function sendComposerContent() {
    const session = activeSession();
    if (session?.sending) return;
    if (!session?.connected) {
      showToast("电脑离线，暂时不能发送");
      return;
    }
    const draft = elements["message-input"].value;
    const text = draft.trim();
    const file = session.selectedFile;
    if (!file && !text) return;
    const context = currentSessionContext(session);
    session.sending = true;
    updateSendButton();
    try {
      if (file) {
        await sendFile(file, session, context);
        showToast(`文件已发送到 ${session.pair.hostName}`);
      } else if (text) {
        if (utf8ByteLength(text) > maximumClipboardTextBytes) {
          throw new Error("文字超过 128 KB，请改为选择文件发送");
        }
        const requestId = `clipboard-${crypto.randomUUID()}`;
        rememberOutgoingRequest(requestId, session);
        try {
          await sendMessage(
            {
              type: "clipboard.create",
              requestId,
              content: text,
            },
            context,
          );
        } catch (error) {
          session.outgoingRequests.delete(requestId);
          throw error;
        }
        showToast(`内容已发送到 ${session.pair.hostName}`);
      } else {
        return;
      }
      // A user may keep typing or select the next file during the transfer.
      // Only retire the content this operation actually sent.
      if (!file && session.draftText === draft) session.draftText = "";
      const clearFile = file && session.selectedFile === file;
      if (clearFile) session.selectedFile = null;
      if (sessionIsActive(session)) {
        if (!file && elements["message-input"].value === draft) {
          elements["message-input"].value = "";
          resizeComposerInput();
        }
        if (clearFile) clearSelectedFile();
      }
    } catch (error) {
      showToast(["NotReadableError", "NotFoundError"].includes(error?.name)
        ? "无法读取这个文件，请重新选择后发送"
        : error?.message || "发送失败，请检查连接");
    } finally {
      session.sending = false;
      updateSendButton();
    }
  }

  async function sendFile(file, session, context) {
    if (file.size > maximumFileBytes) throw new Error("文件超过 25 MB");
    const transferId = `upload-${crypto.randomUUID()}`;
    const transport = await sendMessage(
      {
        type: "file.start",
        transferId,
        name: file.name,
        size: file.size,
        mime: file.type || "application/octet-stream",
      },
      context,
    );
    // Keep every part on the transport that carried file.start. Switching
    // from a buffered RTC channel to relay (or the reverse) can let file.end
    // overtake chunks that are still queued on the first transport.
    const transferContext = transport
      ? { ...context, transport }
      : context;
    let index = 0;
    for (let offset = 0; offset < file.size; offset += fileChunkBytes) {
      const bytes = new Uint8Array(
        await file.slice(offset, offset + fileChunkBytes).arrayBuffer(),
      );
      await waitForTransportBuffer(session, transferContext);
      await sendMessage(
        {
          type: "file.chunk",
          transferId,
          index,
          data: bytesToBase64(bytes),
        },
        transferContext,
      );
      index += 1;
    }
    await sendMessage(
      { type: "file.end", transferId },
      transferContext,
    );
  }

  async function waitForTransportBuffer(session, context) {
    const startedAt = Date.now();
    while (true) {
      const current = currentSessionContext(session);
      if (!session.connected || current?.key !== context?.key ||
          current?.connectionGeneration !== context?.connectionGeneration ||
          current?.contentGeneration !== context?.contentGeneration) {
        throw new Error("连接已经变化，请重新发送文件");
      }
      const transport = context?.transport;
      const kind = transport?.kind;
      const target = transport
        ? transport.target
        : session.channel?.readyState === "open"
          ? session.channel
          : session.socket;
      const currentTarget = kind === "channel" ? session.channel : session.socket;
      const pinnedTransportReady =
        kind === "channel"
          ? target?.readyState === "open" && currentTarget === target
          : kind === "relay"
            ? target?.readyState === WebSocket.OPEN &&
              session.relayHostPresent &&
              currentTarget === target
            : false;
      if (transport && !pinnedTransportReady) {
        throw new Error("连接传输已经变化，请重新发送文件");
      }
      if (!(target?.bufferedAmount > 1024 * 1024)) return;
      if (Date.now() - startedAt >= 15_000) {
        throw new Error("文件发送超时，请检查连接后重试");
      }
      await new Promise((resolve) => setTimeout(resolve, 12));
    }
  }

  function receiveDownloadChunk(message, session) {
    const download = session.downloads.get(message.transferId);
    if (
      !download ||
      !Number.isSafeInteger(message.index) ||
      message.index < 0 ||
      message.index >= download.expectedChunks ||
      download.chunks[message.index] ||
      typeof message.data !== "string" ||
      message.data.length > maximumEncodedFileChunkLength
    ) {
      rejectDownload(message.transferId, session);
      return;
    }
    let bytes;
    try {
      bytes = base64UrlDecode(message.data.replace(/\+/g, "-").replace(/\//g, "_"));
    } catch {
      rejectDownload(message.transferId, session);
      return;
    }
    if (
      bytes.byteLength > fileChunkBytes ||
      download.received + bytes.byteLength > download.size ||
      download.received + bytes.byteLength > maximumFileBytes
    ) {
      rejectDownload(message.transferId, session);
      return;
    }
    download.chunks[message.index] = bytes;
    download.received += bytes.byteLength;
    refreshDownloadTimeout(message.transferId, download, session);
  }

  function beginDownload(message, session) {
    const transferId = message.transferId;
    const size = message.size;
    if (
      typeof transferId !== "string" ||
      transferId.length < 1 ||
      transferId.length > 128 ||
      !Number.isSafeInteger(size) ||
      size < 0 ||
      size > maximumFileBytes ||
      session.downloads.size >= maximumConcurrentDownloads
    ) {
      rejectDownload(transferId, session);
      return;
    }
    const rawName = typeof message.name === "string" ? message.name : "DingDong 文件";
    const safeName = rawName.split(/[\\/]/).filter(Boolean).at(-1)?.slice(0, 180);
    removeDownload(transferId, session);
    const download = {
      itemId: message.itemId,
      name: safeName || "DingDong 文件",
      size,
      expectedChunks: Math.ceil(size / fileChunkBytes),
      chunks: [],
      received: 0,
      timer: null,
    };
    session.downloads.set(transferId, download);
    refreshDownloadTimeout(transferId, download, session);
  }

  function refreshDownloadTimeout(transferId, download, session) {
    clearTimeout(download.timer);
    download.timer = setTimeout(() => {
      removeDownload(transferId, session);
      if (sessionIsActive(session)) showToast("文件接收超时，请重新下载");
    }, downloadIdleTimeoutMs);
  }

  function removeDownload(transferId, session) {
    const download = session.downloads.get(transferId);
    clearTimeout(download?.timer);
    session.downloads.delete(transferId);
    return download;
  }

  function clearDownloads(session) {
    for (const transferId of session.downloads.keys()) removeDownload(transferId, session);
  }

  function rejectDownload(transferId, session) {
    if (typeof transferId === "string") removeDownload(transferId, session);
    if (sessionIsActive(session)) {
      showToast("文件数据无效或超过 25 MB，已停止接收");
    }
  }

  function finishDownload(transferId, session) {
    const download = removeDownload(transferId, session);
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
      if (sessionIsActive(session)) showToast("文件接收不完整，请重试");
      return;
    }
    const blob = new Blob(completeChunks);
    if (blob.size !== download.size) {
      if (sessionIsActive(session)) showToast("文件接收不完整，请重试");
      return;
    }
    const url = URL.createObjectURL(blob);
    const revokeTimer = setTimeout(() => URL.revokeObjectURL(url), 30_000);
    try {
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = download.name;
      anchor.click();
    } catch {
      clearTimeout(revokeTimer);
      URL.revokeObjectURL(url);
      showToast("无法保存文件，请重新下载");
      return;
    }
    showToast(`${session.pair.hostName} 的文件已准备好，请保存到手机`);
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
      let copied = false;
      try {
        textarea.select();
        copied = document.execCommand("copy");
      } catch {
        // Both clipboard APIs may be unavailable in a restricted browser.
      } finally {
        textarea.remove();
      }
      if (!copied) {
        showToast("复制失败，请长按文字手动复制");
        return false;
      }
    }
    const previous = button.innerHTML;
    button.textContent = "已复制";
    setTimeout(() => (button.innerHTML = previous), 900);
    return true;
  }

  function requestFile(item, session = activeSession()) {
    sendMessage(
      { type: "file.request", itemId: item.id },
      currentSessionContext(session),
    ).catch((error) => showToast(error?.message || "无法下载文件"));
    showToast("正在从电脑获取文件…");
  }


    return {
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
    };
}
