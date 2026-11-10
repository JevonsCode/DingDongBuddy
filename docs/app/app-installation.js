import {
  isAndroid,
  isIos,
  isMobileBrowser,
  isStandalone,
} from "./app-platform.js?shell=69";

const browserModeParameter = "in-browser";
const appLaunchFailedParameter = "app-launch-failed";
// Chosen with "继续在浏览器中使用": this tab stays a normal web page even
// though an installed DingDong app exists. Per tab, so a fresh scan still
// offers the app first.
const browserModeKey = "dingdong.browser-mode.v1";
// The native Android companion. An explicit package is the only intent form
// Chrome hands to another app for a same-site https link; without it Chrome
// keeps the navigation in the current tab.
const androidCompanionPackage = "com.dingdongbuddy.companion";
const androidLinkExtra = "dingdong.link";

function browserModeChosen() {
  try {
    return sessionStorage.getItem(browserModeKey) === "1";
  } catch {
    return false;
  }
}

function chooseBrowserMode() {
  try {
    sessionStorage.setItem(browserModeKey, "1");
  } catch {}
}

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
  hasHigherPriorityPrompt = () => false,
}) {
  function isBrowserPwaLauncher() {
    return (
      !isStandalone() &&
      !browserModeChosen() &&
      (state.installStatus === "installed" ||
        (isAndroid() && state.nativeAppInstalled === true))
    );
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
          : state.pwaUpdateAvailable
            ? "立即升级"
            : "检查更新";
  }


  function initializeInstallState() {
    const launchUrl = new URL(window.location.href);
    if (launchUrl.searchParams.get(browserModeParameter) === "1") {
      chooseBrowserMode();
      launchUrl.searchParams.delete(browserModeParameter);
      history.replaceState(null, "", launchUrl.href);
    }
    if (launchUrl.searchParams.get(appLaunchFailedParameter) === "1") {
      // The native app was not found; say so on the launcher instead of
      // silently showing the same two buttons again.
      state.nativeAppInstalled = false;
      state.appLaunchFailed = true;
      launchUrl.searchParams.delete(appLaunchFailedParameter);
      history.replaceState(null, "", launchUrl.href);
    }
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

  function androidAppOffer() {
    // The native app delivers notifications through its own channels, so on
    // Android it is recommended over the browser install once published.
    return isAndroid() && state.androidApp ? state.androidApp : null;
  }

  function renderInstallPromotion() {
    // The optional install suggestion yields to connection and notification
    // prompts; an install the user already started stays visible.
    const optionalSuggestion = ["idle", "available"].includes(
      state.installStatus,
    );
    const nativeOffer = optionalSuggestion ? androidAppOffer() : null;
    const hidden =
      !isMobileBrowser() ||
      (!nativeOffer && (isStandalone() || isBrowserPwaLauncher())) ||
      (!nativeOffer && browserModeChosen() && state.installStatus === "installed") ||
      (optionalSuggestion && hasHigherPriorityPrompt());
    elements["install-app-banner"].hidden = hidden;
    if (hidden) return;
    if (nativeOffer) {
      elements["install-app-title"].textContent = "推荐下载 Android 版";
      elements["install-app-copy"].textContent =
        "通知更稳定，可以分别设置提示音。";
      elements["install-app-button"].textContent = "下载";
      elements["install-app-button"].disabled = false;
      return;
    }

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
    const nativeOffer = ["idle", "available"].includes(state.installStatus)
      ? androidAppOffer()
      : null;
    if (nativeOffer) {
      window.open(nativeOffer.url, "_blank", "noopener");
      return;
    }
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

  function renderPwaLauncher() {
    const canOpenNative = isAndroid() && state.nativeAppInstalled !== false;
    elements["pwa-launcher-title"].textContent = state.appLaunchFailed
      ? "没能自动打开 DingDong"
      : "请在 DingDong App 里使用";
    elements["pwa-launcher-copy"].textContent = state.appLaunchFailed
      ? "没有找到 Android 版 DingDong。可以从桌面的 DingDong 图标打开，或继续在浏览器中使用。"
      : canOpenNative
        ? "这台手机已安装 DingDong App。在 App 里连接，通知更稳定。"
        : "这台手机已安装 DingDong App。浏览器页面不接收通知，请从桌面的 DingDong 图标打开。";
    elements["open-pwa-app-button"].hidden = !canOpenNative;
  }

  // The link handed to the app keeps the pairing fragment, so a scanned QR
  // code still reaches the pairing screen once the app opens.
  function appLaunchLink() {
    const link = new URL(window.location.href);
    link.searchParams.delete(browserModeParameter);
    link.searchParams.delete(appLaunchFailedParameter);
    return link.href;
  }

  function openPwaApp() {
    const target = new URL("./", window.location.href);
    if (isAndroid()) {
      // Chrome keeps a same-site https link in the current tab unless the
      // intent names a package, so a package-less intent (or a plain link)
      // just reloads this screen. The native app is named explicitly and the
      // full link travels as an extra, because an intent URI cannot carry the
      // #pair= fragment in its data. A missing app falls back here with an
      // explanation instead of the same two buttons.
      const fallback = new URL(window.location.href);
      fallback.hash = "";
      fallback.searchParams.set(appLaunchFailedParameter, "1");
      window.location.href =
        `intent://${target.host}${target.pathname}` +
        `#Intent;scheme=${target.protocol.replace(":", "")};` +
        "action=android.intent.action.VIEW;" +
        "category=android.intent.category.BROWSABLE;" +
        `package=${androidCompanionPackage};` +
        `S.${androidLinkExtra}=${encodeURIComponent(appLaunchLink())};` +
        `S.browser_fallback_url=${encodeURIComponent(fallback.href)};end`;
      return;
    }
    target.search = window.location.search;
    target.hash = window.location.hash;
    window.location.assign(target.href);
  }

  // Lets someone who prefers the browser (or whose app is gone) leave the
  // "use the app" screen. Clearing the installed flag is not enough: the
  // installed-app check finds the app again on reload, and replacing the URL
  // with itself is only a fragment navigation when a #pair= link is open. The
  // choice is kept for this tab and a real reload starts the web page,
  // keeping a scanned pairing.
  function continueInBrowser() {
    chooseBrowserMode();
    window.location.reload();
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
        state.nativeAppInstalled = state.appLaunchFailed
          ? false
          : applications.some(isAndroidCompanion);
        if (state.nativeAppInstalled) stopBrowserRuntimeForInstalledPwa();
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

  function isAndroidCompanion(application) {
    return (
      application?.platform === "play" &&
      application.id === androidCompanionPackage
    );
  }

  function isCurrentWebApp(application) {
    if (application?.platform !== "webapp" || !application.url) return false;
    try {
      const manifestUrl = new URL("./manifest.webmanifest", window.location.href).href;
      const installedManifestUrl = new URL(application.url, window.location.href).href;
      if (installedManifestUrl !== manifestUrl) return false;
      if (!application.id) return true;
      // A manifest `id` of "./" resolves against start_url, i.e. the app folder.
      const expectedId = new URL("./", manifestUrl).href;
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

  // Accepts only an HTTPS download on GitHub or this site, so a broken
  // descriptor can never send people to an unexpected host.
  function androidAppDescriptor(version) {
    const app = version?.androidApp;
    if (typeof app?.url !== "string" || typeof app?.version !== "string") {
      return null;
    }
    try {
      const url = new URL(app.url, location.href);
      const trusted =
        url.protocol === "https:" &&
        (url.origin === location.origin || url.hostname === "github.com");
      return trusted ? { url: url.href, version: app.version } : null;
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
      state.androidApp = androidAppDescriptor(version);
      renderInstallPromotion();
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
      continueInBrowser,
      renderPwaLauncher,
      refreshInstallState,
      registerServiceWorker,
      renderInstallPromotion,
      renderPwaUpdateStatus,
      showInstallDialog,
      upgradePwaManually,
    };
}
