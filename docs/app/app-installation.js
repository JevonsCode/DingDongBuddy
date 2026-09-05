import {
  isAndroid,
  isIos,
  isMobileBrowser,
  isStandalone,
} from "./app-platform.js?shell=40";

// PWA installation and shell-update lifecycle.
export function createInstallationController({
  state,
  elements,
  storageKeys,
  installVerificationIntervalMs,
  installVerificationTimeoutMs,
  currentPwaVersion,
  currentPwaShellVersion,
  pwaUpdateCheckIntervalMs,
  closeConnection,
  invalidateNotificationOperations,
  persistPairingsForWorker,
  showToast,
}) {
  function isBrowserPwaLauncher() {
    return !isStandalone() && state.installStatus === "installed";
  }

  function notificationsCanRunInCurrentSurface() {
    return !isBrowserPwaLauncher();
  }

  function renderPwaUpdateStatus() {
    elements["pwa-update-status"].textContent = state.pwaUpdateStatusMessage;
    elements["pwa-update-button"].disabled = state.pwaUpdateCheckInProgress;
    elements["pwa-update-button"].textContent =
      state.pwaUpdateStatusMessage.startsWith("正在升级")
        ? "升级中…"
        : state.pwaUpdateCheckInProgress
          ? "检查中…"
          : "手动升级";
  }


  function initializeInstallState() {
    if (isStandalone()) {
      markInstallVerified();
      return;
    }
    if (localStorage.getItem(storageKeys.pwaInstalled) === "true") {
      state.installStatus = "installed";
      stopBrowserRuntimeForInstalledPwa();
      return;
    }
    if (!state.installRequestedAt) return;
    state.installStatus =
      Date.now() - state.installRequestedAt < installVerificationTimeoutMs
        ? "requested"
        : "stalled";
    scheduleInstallVerification();
  }

  function renderInstallPromotion() {
    const hidden =
      !isMobileBrowser() || isStandalone() || isBrowserPwaLauncher();
    elements["install-app-banner"].hidden = hidden;
    if (hidden) return;

    const presentations = {
      idle: {
        title: "添加到主屏幕（可选）",
        copy: isIos()
          ? "添加后可像 App 打开并接收完成提醒。"
          : "不添加也能直接连接、传内容和接收提醒。",
        button: state.installPrompt ? "添加" : "查看方法",
      },
      available: {
        title: "添加到主屏幕（可选）",
        copy: "不添加也能直接连接、传内容和接收提醒。",
        button: "添加",
      },
      prompting: {
        title: "等待浏览器确认",
        copy: "请完成浏览器显示的添加步骤。",
        button: "处理中",
      },
      requested: {
        title: "Chrome 正在添加 DingDong",
        copy: "请求已提交；网页可以继续使用。",
        button: "检查",
      },
      stalled: {
        title: "Chrome 没有完成添加",
        copy: "不影响网页使用，可以查看原因和重试方法。",
        button: "查看",
      },
      installed: {
        title: "系统中已找到 DingDong",
        copy: "当前仍在浏览器中，请从桌面图标打开 App 模式。",
        button: "查看",
      },
    };
    const presentation = presentations[state.installStatus] || presentations.idle;
    elements["install-app-title"].textContent = presentation.title;
    elements["install-app-copy"].textContent = presentation.copy;
    elements["install-app-button"].textContent = presentation.button;
    elements["install-app-button"].disabled = state.installStatus === "prompting";
  }

  async function installApp() {
    if (state.installStatus === "installed") {
      showInstallDialog({
        eyebrow: "已验证安装状态",
        title: "系统中已经有 DingDong",
        instructions: isAndroid()
          ? "请回到桌面查找 DingDong。若桌面仍没有入口，可在“设置 → 应用 → 管理应用”搜索 DingDong：能搜到表示应用已装好，只是桌面入口没有放置；再到系统的“管理桌面快捷方式”里允许 Chrome 添加入口。"
          : "请从手机桌面的 DingDong 图标打开；从图标启动后会进入独立的 App 界面。",
      });
      return;
    }
    if (state.installStatus === "requested") {
      await refreshInstallState();
      if (state.installStatus === "installed") return installApp();
      showInstallDialog({
        eyebrow: "安装状态",
        title: "Chrome 仍在处理",
        instructions:
          "Chrome 已经接收添加请求，但 WebAPK 还没有被系统确认安装。这个过程不影响网页连接、内容传递或 Android 通知；稍后可以再点“检查”。超过一分钟仍未完成时，会显示具体诊断方法。",
      });
      return;
    }
    if (state.installStatus === "stalled") {
      showInstallDialog({
        eyebrow: "安装没有完成",
        title: "卡在 Chrome 的应用安装阶段",
        instructions:
          "网页本身已通过安装检查，但 Chrome 没有完成 WebAPK 安装。你可以继续直接使用网页，或重启 Chrome 后从菜单重新选择“安装应用 / 添加到主屏幕”。要定位系统原因，可在 Chrome 地址栏打开 chrome://histograms/WebApk.Install.InstallResult 和 chrome://histograms/WebApk.Install.GooglePlayInstallResult，查看最新一项。",
      });
      return;
    }
    const prompt = state.installPrompt;
    if (prompt) {
      state.installStatus = "prompting";
      renderInstallPromotion();
      try {
        await prompt.prompt();
        const choice = await prompt.userChoice;
        state.installPrompt = null;
        if (choice?.outcome === "accepted") {
          markInstallRequested();
          showInstallDialog({
            eyebrow: "请求已提交",
            title: "等待 Chrome 完成添加",
            instructions:
              "接受安装请求不等于图标已经生成。DingDong 会继续检查系统状态；这段时间网页可以照常连接、传内容，Android 的完成提醒也不依赖安装。",
          });
          return;
        }
        clearInstallRequest();
        renderInstallPromotion();
        return;
      } catch {
        state.installPrompt = null;
        clearInstallRequest();
        renderInstallPromotion();
        return;
      }
    }
    showInstallDialog({
      eyebrow: "可选的主屏幕入口",
      title: "添加 DingDong",
      instructions: isIos()
        ? "在 Safari 中点“分享”，选择“添加到主屏幕”，再点“添加”。从桌面 DingDong 图标打开后会进入独立 App 界面，并且可以开启完成提醒；不添加也能继续使用网页。"
        : isAndroid()
          ? "打开 Chrome 右上角“⋮”，选择“安装应用”或“添加到主屏幕”。添加是可选的：普通网页也能连接、传内容并开启完成提醒。若 Chrome 一直显示“安装中”，请稍后再点这里查看安装状态。"
          : "请从浏览器菜单选择“添加到主屏幕”或“安装应用”。不添加也能继续使用网页。",
    });
  }

  function openPwaApp() {
    const target = new URL("./", window.location.href);
    target.search = window.location.search;
    target.hash = window.location.hash;
    const opened = window.open(target.href, "_blank", "noopener,noreferrer");
    if (!opened) window.location.assign(target.href);
  }

  function markInstallRequested() {
    if (state.installStatus === "installed") return;
    state.installRequestedAt = Date.now();
    state.installStatus = "requested";
    localStorage.setItem(storageKeys.installRequest, String(state.installRequestedAt));
    renderInstallPromotion();
    scheduleInstallVerification();
  }

  function markInstallVerified() {
    clearInstallRequest();
    state.installStatus = "installed";
    localStorage.setItem(storageKeys.pwaInstalled, "true");
    stopBrowserRuntimeForInstalledPwa();
    renderInstallPromotion();
  }

  function clearInstallRequest() {
    clearTimeout(state.installVerificationTimer);
    state.installVerificationTimer = null;
    state.installRequestedAt = 0;
    state.installStatus = "idle";
    localStorage.removeItem(storageKeys.installRequest);
  }

  async function refreshInstallState() {
    if (isStandalone()) {
      markInstallVerified();
      return true;
    }
    if (typeof navigator.getInstalledRelatedApps === "function") {
      try {
        const applications = await navigator.getInstalledRelatedApps();
        if (applications.some(isCurrentWebApp)) {
          markInstallVerified();
          return true;
        }
      } catch {}
    }
    if (state.installStatus === "installed") return true;
    if (
      state.installRequestedAt &&
      Date.now() - state.installRequestedAt >= installVerificationTimeoutMs
    ) {
      clearTimeout(state.installVerificationTimer);
      state.installVerificationTimer = null;
      state.installStatus = "stalled";
      renderInstallPromotion();
      return false;
    }
    scheduleInstallVerification();
    return false;
  }

  function stopBrowserRuntimeForInstalledPwa() {
    if (isStandalone() || !isBrowserPwaLauncher()) return;
    for (const session of state.sessions.values()) {
      invalidateNotificationOperations(session);
      closeConnection(session);
    }
    document.querySelectorAll("dialog[open]").forEach((dialog) => dialog.close());
  }

  function isCurrentWebApp(application) {
    if (application?.platform !== "webapp" || !application.url) return false;
    try {
      const manifestUrl = new URL("./manifest.webmanifest", window.location.href).href;
      const installedManifestUrl = new URL(application.url, window.location.href).href;
      if (installedManifestUrl !== manifestUrl) return false;
      if (!application.id) return true;
      const expectedId = new URL("/", window.location.origin).href;
      return new URL(application.id, window.location.href).href === expectedId;
    } catch {
      return false;
    }
  }

  function scheduleInstallVerification() {
    clearTimeout(state.installVerificationTimer);
    state.installVerificationTimer = null;
    if (state.installStatus !== "requested") return;
    const remaining = Math.max(
      0,
      installVerificationTimeoutMs - (Date.now() - state.installRequestedAt),
    );
    state.installVerificationTimer = setTimeout(
      () => refreshInstallState().catch(() => {}),
      Math.min(installVerificationIntervalMs, remaining || 1),
    );
  }

  function showInstallDialog({ eyebrow, title, instructions }) {
    elements["install-dialog-eyebrow"].textContent = eyebrow;
    elements["install-dialog-title"].textContent = title;
    elements["install-instructions"].textContent = instructions;
    if (!elements["install-dialog"].open) {
      elements["install-dialog"].showModal();
    }
  }


  async function registerServiceWorker() {
    if (!("serviceWorker" in navigator)) return null;
    try {
      return await navigator.serviceWorker.register("./service-worker.js", {
        scope: "./",
        updateViaCache: "none",
      });
    } catch {
      return null;
    }
  }

  async function fetchPwaVersion() {
    const url = new URL("./version.json", location.href);
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) throw new Error(`PWA version check failed: ${response.status}`);
    const value = await response.json();
    if (
      typeof value?.version !== "string" ||
      !Number.isSafeInteger(value?.shell) ||
      value.shell < 1
    ) {
      throw new Error("PWA version descriptor is invalid");
    }
    return value;
  }

  async function checkPwaUpdate({ force = false, silent = false } = {}) {
    const now = Date.now();
    if (
      state.pwaUpdateCheckInProgress ||
      (!force && now - state.lastPwaUpdateCheckAt < pwaUpdateCheckIntervalMs)
    ) {
      return state.pwaUpdateAvailable;
    }

    state.pwaUpdateCheckInProgress = true;
    if (!silent) state.pwaUpdateStatusMessage = "正在检查 PWA 更新…";
    renderPwaUpdateStatus();

    try {
      const registration =
        state.serviceWorkerRegistration ||
        (await navigator.serviceWorker?.getRegistration("./"));
      const [version] = await Promise.all([
        fetchPwaVersion(),
        registration?.update(),
      ]);
      state.lastPwaUpdateCheckAt = now;
      state.pwaUpdateAvailable =
        version.shell > currentPwaShellVersion ? version : null;
      state.pwaUpdateStatusMessage = state.pwaUpdateAvailable
        ? `发现新版本 ${version.version}，可立即升级`
        : `已是最新版本 · ${currentPwaVersion}`;
      return state.pwaUpdateAvailable;
    } catch {
      state.pwaUpdateStatusMessage = silent
        ? `当前版本 ${currentPwaVersion} · 联网后自动重试`
        : "检查失败，请确认网络后重试";
      return null;
    } finally {
      state.pwaUpdateCheckInProgress = false;
      renderPwaUpdateStatus();
    }
  }

  async function upgradePwaManually() {
    const version = await checkPwaUpdate({ force: true });
    if (!version) {
      showToast(
        state.pwaUpdateStatusMessage.startsWith("已是最新版本")
          ? "已经是最新版本"
          : "暂时无法升级，请稍后重试",
      );
      return;
    }

    state.pwaUpdateCheckInProgress = true;
    state.pwaUpdateStatusMessage = `正在升级到 ${version.version}…`;
    renderPwaUpdateStatus();
    try {
      await persistPairingsForWorker();
      await state.serviceWorkerRegistration?.update();
      location.reload();
    } catch {
      state.pwaUpdateCheckInProgress = false;
      state.pwaUpdateStatusMessage = "升级失败，配对信息未受影响，请重试";
      renderPwaUpdateStatus();
    }
  }


    return {
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
    };
}
