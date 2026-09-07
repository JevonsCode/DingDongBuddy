import { formatTime } from "./app-formatters.js?shell=41";

export const downloadHistoryKey = "dingdong.download-history.v1";
const maximumHistoryEntries = 300;
const imageTypes = {
  png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg",
  gif: "image/gif", webp: "image/webp", avif: "image/avif",
  bmp: "image/bmp", ico: "image/x-icon", svg: "image/svg+xml",
};

export function imageMimeType(item) {
  const extension = item?.fileName?.split(".").at(-1)?.toLowerCase();
  return Object.hasOwn(imageTypes, extension) ? imageTypes[extension] : null;
}

function recordKey(session, item) {
  if (!session?.pair?.room || !item?.id || !item.fileName) return null;
  return JSON.stringify([
    session.pair.room, item.id, item.fileName, item.fileSize, item.updatedAt || "",
  ]);
}

// Only bounded receipt metadata is persisted; never file bodies or Blob URLs.
export function createDownloadHistory(storage = () => globalThis.localStorage) {
  let cachedRaw;
  let records = new Map();
  function refresh() {
    try {
      const raw = storage()?.getItem(downloadHistoryKey) || null;
      if (raw === cachedRaw) return;
      cachedRaw = raw;
      let entries;
      try { entries = JSON.parse(raw); } catch { entries = []; }
      records = new Map((Array.isArray(entries) ? entries : [])
        .filter((entry) => Array.isArray(entry) && typeof entry[0] === "string" &&
          entry[0].length <= 2048 && Number.isFinite(entry[1]) && entry[1] > 0)
        .slice(-maximumHistoryEntries));
    } catch { /* A blocked store must not prevent saving a file. */ }
  }
  function persist() {
    while (records.size > maximumHistoryEntries) records.delete(records.keys().next().value);
    try {
      const target = storage();
      if (!target) return false;
      const raw = JSON.stringify([...records]);
      target.setItem(downloadHistoryKey, raw);
      cachedRaw = raw;
      return true;
    } catch { return false; }
  }
  return {
    get(session, item) {
      refresh();
      return records.get(recordKey(session, item)) || null;
    },
    mark(session, item, at = Date.now()) {
      refresh();
      const key = recordKey(session, item);
      if (!key || key.length > 2048) return false;
      records.delete(key);
      records.set(key, at);
      return persist();
    },
    clearRoom(room) {
      refresh();
      for (const key of records.keys()) {
        try { if (JSON.parse(key)[0] === room) records.delete(key); } catch {}
      }
      return persist();
    },
  };
}

export function createFileActions({ elements = {}, showToast, onChange = () => {},
  history = createDownloadHistory() } = {}) {
  const dialog = elements["image-preview-dialog"];
  const image = elements["image-preview-image"];
  const status = elements["image-preview-status"];
  const saveButton = elements["image-preview-save"];
  let preview = null;

  function releasePreview() {
    if (!preview) return;
    if (preview.url) URL.revokeObjectURL(preview.url);
    preview.cancelled = true;
    preview.blob = null;
    preview.download = null;
    preview.url = null;
    preview = null;
    image?.removeAttribute("src");
    if (image) image.hidden = true;
  }

  function closePreview(session) {
    if (session && preview?.session !== session) return;
    releasePreview();
    if (dialog?.open) dialog.close();
  }

  function openPreview(item, session) {
    closePreview();
    if (!dialog || !imageMimeType(item)) return null;
    preview = { item: { ...item }, session, cancelled: false, blob: null, url: null };
    elements["image-preview-title"].textContent = item.fileName;
    image.alt = item.fileName;
    status.textContent = "正在从电脑获取图片…";
    saveButton.disabled = true;
    dialog.showModal();
    return preview;
  }

  function failPreview(token, message) {
    if (!token || token !== preview || token.cancelled) return;
    status.textContent = message;
  }

  function showPreview(token, blob, download) {
    if (!token || token !== preview || token.cancelled || !dialog.open) return;
    token.blob = blob.slice(0, blob.size, imageMimeType(token.item));
    // Do not retain the transfer's chunk array after the preview closes.
    token.download = { item: download.item, itemId: download.itemId, name: download.name };
    token.url = URL.createObjectURL(token.blob);
    image.src = token.url;
    image.hidden = false;
    saveButton.disabled = false;
    status.textContent = "正在显示图片…";
  }

  function saveFile(blob, download, session) {
    const url = URL.createObjectURL(blob);
    const timer = setTimeout(() => URL.revokeObjectURL(url), 30_000);
    try {
      const anchor = document.createElement("a");
      anchor.href = url;
      anchor.download = download.name;
      anchor.click();
    } catch {
      clearTimeout(timer);
      URL.revokeObjectURL(url);
      showToast("无法保存文件，请重新下载");
      return false;
    }
    const item = download.item || session.items?.find((item) => item.id === download.itemId);
    const persisted = item ? history.mark(session, item) : true;
    onChange(session);
    showToast(persisted
      ? "已发起下载，请在系统下载中确认保存结果"
      : "已发起下载，但下载记录无法保留，请检查浏览器存储设置");
    return true;
  }

  if (dialog) {
    dialog.addEventListener("close", releasePreview);
    elements["image-preview-close"].addEventListener("click", () => closePreview());
    image.addEventListener("load", () => {
      if (preview) status.textContent = "预览不会自动保存，下载后可在系统下载中查看。";
    });
    image.addEventListener("error", () => {
      if (!preview) return;
      image.hidden = true;
      status.textContent = "此图片无法预览，可下载后使用其他应用打开。";
    });
    saveButton.addEventListener("click", () => {
      if (!preview?.blob) return;
      if (saveFile(preview.blob, preview.download, preview.session)) {
        status.textContent = `已下载 · ${formatTime(new Date())}，请在系统下载中确认保存结果。`;
      }
    });
  }
  return { history, openPreview, showPreview, failPreview, closePreview, saveFile };
}
