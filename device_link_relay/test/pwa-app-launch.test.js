import assert from "node:assert/strict";
import test from "node:test";
import { createInstallationController } from "../../docs/app/app-installation.js";

// Browser fixtures for the "use the app" launcher shown when a scanned link
// opens in Chrome while a DingDong app is installed.
function replaceGlobal(t, name, value) {
  const previous = Object.getOwnPropertyDescriptor(globalThis, name);
  Object.defineProperty(globalThis, name, { configurable: true, value });
  t.after(() => {
    if (previous) Object.defineProperty(globalThis, name, previous);
    else delete globalThis[name];
  });
}

function memoryStorage() {
  const values = new Map();
  return {
    getItem: (key) => (values.has(key) ? values.get(key) : null),
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: (key) => values.delete(key),
  };
}

const pairLink =
  "https://dingdong.xn--m8txu.com/app/#pair=eyJyb29tIjoidGVzdCJ9";

function setUpBrowser(t, { href = pairLink, relatedApps = [] } = {}) {
  const location = {
    href,
    reloads: 0,
    reload() {
      this.reloads += 1;
    },
    assign(url) {
      this.href = url;
    },
  };
  const sessionStorage = memoryStorage();
  const localStorage = memoryStorage();
  replaceGlobal(t, "window", {
    location,
    matchMedia: () => ({ matches: false }),
    navigator: {},
  });
  replaceGlobal(t, "location", location);
  replaceGlobal(t, "navigator", {
    userAgent: "Mozilla/5.0 (Linux; Android 15; 2304FPN6DC) Chrome/140.0 Mobile",
    getInstalledRelatedApps: async () => relatedApps,
  });
  replaceGlobal(t, "sessionStorage", sessionStorage);
  replaceGlobal(t, "localStorage", localStorage);
  replaceGlobal(t, "history", {
    replaceState(_state, _title, url) {
      location.href = new URL(url, location.href).href;
    },
  });
  replaceGlobal(t, "document", { querySelectorAll: () => [] });
  return { location, sessionStorage, localStorage };
}

function element() {
  return { hidden: false, disabled: false, textContent: "" };
}

function createController() {
  const state = {
    installStatus: "idle",
    installRequestedAt: 0,
    sessions: new Map(),
    nativeAppInstalled: null,
    appLaunchFailed: false,
  };
  const elements = Object.fromEntries(
    [
      "install-app-banner",
      "install-app-title",
      "install-app-copy",
      "install-app-button",
      "pwa-launcher-title",
      "pwa-launcher-copy",
      "open-pwa-app-button",
    ].map((id) => [id, element()]),
  );
  const controller = createInstallationController({
    state,
    elements,
    storageKeys: {
      pwaInstalled: "dingdong.pwa-installed.v1",
      installRequest: "dingdong.install-request.v1",
    },
    installVerificationIntervalMs: 1000,
    installVerificationTimeoutMs: 60_000,
    currentPwaVersion: "test",
    currentPwaShellVersion: 1,
    pwaUpdateCheckIntervalMs: 1000,
    closeConnection() {},
    invalidateNotificationOperations() {},
    persistPairingsForWorker: async () => {},
    showToast() {},
  });
  return { controller, state, elements };
}

const installedWebApp = {
  platform: "webapp",
  url: "https://dingdong.xn--m8txu.com/app/manifest.webmanifest",
  id: "https://dingdong.xn--m8txu.com/app/",
};
const installedNativeApp = { platform: "play", id: "com.dingdongbuddy.companion" };

test("continuing in the browser leaves the launcher even though the installed app is found again", async (t) => {
  const browser = setUpBrowser(t, { relatedApps: [installedWebApp] });
  const { controller } = createController();
  controller.initializeInstallState();
  await controller.refreshInstallState();
  assert.equal(controller.isBrowserPwaLauncher(), true);

  controller.continueInBrowser();
  // A real reload, not a replace() to the same #pair= URL (a no-op fragment
  // navigation), and the pairing link is kept for the reloaded page.
  assert.equal(browser.location.reloads, 1);
  assert.equal(browser.location.href, pairLink);

  // After the reload the installed-app check still finds the WebAPK.
  const reloaded = createController();
  reloaded.controller.initializeInstallState();
  await reloaded.controller.refreshInstallState();
  assert.equal(reloaded.state.installStatus, "installed");
  assert.equal(reloaded.controller.isBrowserPwaLauncher(), false);
  assert.equal(reloaded.controller.notificationsCanRunInCurrentSurface(), true);
});

test("opening the app names the Android package and hands over the full pairing link", (t) => {
  const browser = setUpBrowser(t);
  const { controller } = createController();
  controller.openPwaApp();

  const intent = browser.location.href;
  assert.match(intent, /^intent:\/\/dingdong\.xn--m8txu\.com\/app\/#Intent;/);
  assert.match(intent, /;scheme=https;/);
  assert.match(intent, /;package=com\.dingdongbuddy\.companion;/);
  const extra = intent.match(/;S\.dingdong\.link=([^;]+);/);
  assert.ok(extra, intent);
  assert.equal(decodeURIComponent(extra[1]), pairLink);
  const fallback = intent.match(/;S\.browser_fallback_url=([^;]+);end$/);
  assert.ok(fallback, intent);
  const fallbackUrl = new URL(decodeURIComponent(fallback[1]));
  assert.equal(fallbackUrl.searchParams.get("app-launch-failed"), "1");
  assert.equal(fallbackUrl.hash, "");
});

test("an installed native app turns the scanned page into a launcher for it", async (t) => {
  setUpBrowser(t, { relatedApps: [installedNativeApp] });
  const { controller, elements } = createController();
  controller.initializeInstallState();
  await controller.refreshInstallState();
  assert.equal(controller.isBrowserPwaLauncher(), true);
  controller.renderPwaLauncher();
  assert.equal(elements["open-pwa-app-button"].hidden, false);
  assert.match(elements["pwa-launcher-copy"].textContent, /通知更稳定/);
});

test("a failed app launch explains itself instead of repeating the same buttons", async (t) => {
  const browser = setUpBrowser(t, {
    href: "https://dingdong.xn--m8txu.com/app/?app-launch-failed=1",
    relatedApps: [installedWebApp],
  });
  const { controller, elements, state } = createController();
  controller.initializeInstallState();
  await controller.refreshInstallState();
  assert.equal(browser.location.href, "https://dingdong.xn--m8txu.com/app/");
  assert.equal(state.nativeAppInstalled, false);
  assert.equal(controller.isBrowserPwaLauncher(), true);
  controller.renderPwaLauncher();
  assert.equal(elements["pwa-launcher-title"].textContent, "没能自动打开 DingDong");
  assert.equal(elements["open-pwa-app-button"].hidden, true);
});
