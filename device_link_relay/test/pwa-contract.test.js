import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  defaultDeviceName,
  detectDeviceName,
  modelFromUserAgent,
  normalizeDeviceModel,
  shouldUpgradeAutomaticDeviceName,
} from "../../docs/app/device-name.js";
import {
  isStoredPairing,
  pairingsMatch,
} from "../../docs/app/pairing-state.js";
import {
  adjacentContentTab,
  contentScrollIsSnapped,
  contentTabAtScrollPosition,
  parseContentTabLaunch,
} from "../../docs/app/content-navigation.js";
import {
  relayConnectionWasReplaced,
  shouldReconnectRelay,
} from "../../docs/app/connection-policy.js";
import {
  agentNotificationsAreActive,
  applyAgentNotificationDefault,
  wantsAgentNotifications,
} from "../../docs/app/notification-policy.js";

const appSource = readFileSync(new URL("../../docs/app/app.js", import.meta.url), "utf8");
const pageSource = readFileSync(new URL("../../docs/app/index.html", import.meta.url), "utf8");
const stylesSource = readFileSync(
  new URL("../../docs/app/styles.css", import.meta.url),
  "utf8",
);
const manifest = JSON.parse(
  readFileSync(
    new URL("../../docs/app/manifest.webmanifest", import.meta.url),
    "utf8",
  ),
);
const serviceWorkerSource = readFileSync(
  new URL("../../docs/app/service-worker.js", import.meta.url),
  "utf8",
);
const desktopSessionSource = readFileSync(
  new URL(
    "../../lib/features/device_link/data/device_link_session.dart",
    import.meta.url,
  ),
  "utf8",
);
const desktopControllerSource = readFileSync(
  new URL(
    "../../lib/features/device_link/ui/device_link_controller.dart",
    import.meta.url,
  ),
  "utf8",
);
const desktopMainSource = readFileSync(
  new URL("../../lib/main.dart", import.meta.url),
  "utf8",
);
const wranglerSource = readFileSync(
  new URL("../wrangler.jsonc", import.meta.url),
  "utf8",
);
const assetsIgnoreSource = readFileSync(
  new URL("../../docs/.assetsignore", import.meta.url),
  "utf8",
);
const assetHeadersSource = readFileSync(
  new URL("../../docs/_headers", import.meta.url),
  "utf8",
);

test("the phone never reads or watches its system clipboard", () => {
  assert.doesNotMatch(appSource, /navigator\.clipboard\.(?:read|readText)\s*\(/);
  assert.doesNotMatch(appSource, /addEventListener\(["'](?:copy|paste)["']/);
  assert.match(appSource, /navigator\.clipboard\.writeText\(item\.content\)/);
});

test("phone text and files are uploaded only from the explicit Send action", () => {
  assert.match(
    appSource,
    /\["send-button"\]\.addEventListener\("click", sendComposerContent\)/,
  );
  assert.match(
    appSource,
    /type: "clipboard\.create",\s*requestId,\s*content: text/,
  );
  assert.match(appSource, /await sendFile\(file\)/);
  assert.match(pageSource, /只有点击“发送”后，内容才会进入电脑的剪贴板列表。/);
  assert.match(pageSource, /placeholder="输入或手动粘贴内容…"/);
});

test("clipboard text stays inside the relay frame boundary", async () => {
  const maximumTextBytes = 128 * 1024;
  const maximumRelayFrameBytes = 256 * 1024;
  const unicodeUnit = "界";
  const unicodeBytes = new TextEncoder().encode(unicodeUnit).byteLength;
  const content =
    unicodeUnit.repeat(Math.floor(maximumTextBytes / unicodeBytes)) +
    "a".repeat(maximumTextBytes % unicodeBytes);
  assert.equal(new TextEncoder().encode(content).byteLength, maximumTextBytes);

  const frame = await encryptedRelayDataFrame({
    type: "clipboard.create",
    requestId: "clipboard-boundary-test",
    content,
  });
  assert.ok(
    new TextEncoder().encode(frame).byteLength <= maximumRelayFrameBytes,
    "the final AES-GCM/base64url/JSON relay frame must fit the Worker limit",
  );

  const escapeHeavyContent = "\u0000".repeat(maximumTextBytes);
  assert.equal(
    new TextEncoder().encode(escapeHeavyContent).byteLength,
    maximumTextBytes,
  );
  const escapeHeavyFrame = await encryptedRelayDataFrame({
    type: "clipboard.create",
    requestId: "clipboard-escape-boundary-test",
    content: escapeHeavyContent,
  });
  assert.ok(
    new TextEncoder().encode(escapeHeavyFrame).byteLength >
      maximumRelayFrameBytes,
    "control characters demonstrate why the final encrypted frame needs its own bound",
  );
  assert.equal(
    new TextEncoder().encode(`${content}a`).byteLength,
    maximumTextBytes + 1,
  );
  assert.match(appSource, /const maximumClipboardTextBytes = 128 \* 1024/);
  assert.match(
    appSource,
    /utf8ByteLength\(text\) > maximumClipboardTextBytes/,
  );
  assert.match(appSource, /const relayFrame = encodeRelayFrame\("data", envelope\)/);
  assert.match(appSource, /context\.socket\.send\(encodeRelayFrame\("signal", payload\)\)/);
  assert.match(
    appSource,
    /utf8ByteLength\(frame\) > maximumRelayFrameBytes/,
  );
  assert.match(appSource, /error\.code = "relay-frame-too-large"/);
  assert.match(appSource, /code !== "text_too_large"/);
  assert.match(desktopControllerSource, /deviceLinkMaximumTextBytes = 128 \* 1024/);
  assert.match(desktopControllerSource, /'code': 'text_too_large'/);
});

test("clipboard reconnect history is split into relay-safe item frames", () => {
  assert.match(
    desktopControllerSource,
    /'type': 'clipboard\.snapshot',\s*'items': const <Object\?>\[\]/,
  );
  assert.match(desktopControllerSource, /for \(final ClipboardRecord record in records\.reversed\)/);
  assert.match(desktopControllerSource, /'type': 'clipboard\.upsert'/);
  assert.match(appSource, /case "clipboard\.snapshot":\s*receiveClipboardSnapshot\(message\)/);
  assert.match(appSource, /case "clipboard\.upsert":/);
});

test("incoming phone downloads enforce the same 25 MB safety boundary", () => {
  assert.match(appSource, /size > maximumFileBytes/);
  assert.match(appSource, /state\.downloads\.size >= maximumConcurrentDownloads/);
  assert.match(appSource, /message\.data\.length > maximumEncodedFileChunkLength/);
  assert.match(appSource, /bytes\.byteLength > fileChunkBytes/);
  assert.match(appSource, /message\.index >= download\.expectedChunks/);
  assert.match(appSource, /state\.downloads\.clear\(\)/);
});

test("host clipboard content stays memory-only and is cleared on disconnect", () => {
  assert.doesNotMatch(appSource, /localStorage\.setItem\([^\n]*items/);
  assert.match(appSource, /state\.items = \[\];\s*render\(\)/);
  assert.match(pageSource, /断开后不会缓存电脑里的剪贴板内容。/);
});

test("pairing never promises or displays unsent host history", () => {
  assert.match(
    appSource,
    /连接后只会看到电脑主动发送，或为此设备开启自动发送后产生的内容/,
  );
  assert.match(
    pageSource,
    /只有电脑主动发送，或为此设备开启自动发送后，新内容才会出现在这里/,
  );
  assert.doesNotMatch(pageSource, /主机数据库里的最近内容/);
  assert.match(serviceWorkerSource, /dingdong-app-shell-v19/);
});

test("a superseded PWA page stops reconnecting instead of stealing the room back", () => {
  const replaced = {
    code: 1008,
    reason: "Replaced by a newer connection",
  };
  assert.equal(relayConnectionWasReplaced(replaced), true);
  assert.equal(
    shouldReconnectRelay(replaced, { manualDisconnect: false }),
    false,
  );
  assert.equal(
    shouldReconnectRelay({ code: 1006, reason: "" }, { manualDisconnect: false }),
    true,
  );
  assert.equal(
    shouldReconnectRelay({ code: 1006, reason: "" }, { manualDisconnect: true }),
    false,
  );
  assert.match(appSource, /if \(!relayContextIsCurrent\(context\)\) return/);
  assert.match(appSource, /state\.connectionGeneration \+= 1/);
  assert.match(appSource, /state\.relayGeneration \+= 1/);
  assert.match(appSource, /连接已转移到另一个页面/);
  assert.match(desktopSessionSource, /deviceLinkConnectionWasReplaced/);
});

test("mobile content tabs use native swipe paging and stay accessible", () => {
  assert.equal(contentTabAtScrollPosition(0, 390), "clipboard");
  assert.equal(contentTabAtScrollPosition(230, 390), "agent");
  assert.equal(contentTabAtScrollPosition(390, 390), "agent");
  assert.equal(adjacentContentTab("clipboard", 1), "agent");
  assert.equal(adjacentContentTab("agent", -1), "clipboard");
  assert.equal(adjacentContentTab("clipboard", -1), "clipboard");
  assert.equal(adjacentContentTab("agent", 1), "agent");
  assert.equal(contentScrollIsSnapped(0, 390), true);
  assert.equal(contentScrollIsSnapped(390, 390), true);
  assert.equal(contentScrollIsSnapped(210, 390), false);

  assert.match(pageSource, /id="content-tabs"[^>]*role="tablist"/);
  assert.match(pageSource, /id="clipboard-tab"[\s\S]*?role="tab"[\s\S]*?aria-controls="clipboard-panel"/);
  assert.match(pageSource, /id="agent-tab"[\s\S]*?role="tab"[\s\S]*?aria-controls="agent-panel"/);
  assert.match(pageSource, /id="feed-pager" class="feed-pager"/);
  assert.match(pageSource, /id="clipboard-panel"[\s\S]*?role="tabpanel"/);
  assert.match(pageSource, /id="agent-panel"[\s\S]*?role="tabpanel"/);
  assert.doesNotMatch(pageSource, /id="agent-panel"[^>]*\shidden(?:\s|>)/);

  assert.match(stylesSource, /\.feed-pager\s*{[\s\S]*overflow-x: auto/);
  assert.match(stylesSource, /scroll-snap-type: x mandatory/);
  assert.match(stylesSource, /overscroll-behavior-inline: contain/);
  assert.match(stylesSource, /-webkit-overflow-scrolling: touch/);
  assert.match(stylesSource, /\.feed-panel\s*{[\s\S]*flex: 0 0 100%/);
  assert.match(stylesSource, /scroll-snap-align: start/);
  assert.match(appSource, /pager\.addEventListener\("scroll", handleFeedPagerScroll/);
  assert.match(appSource, /feedPagerSupportsScrollEnd = "onscrollend" in pager/);
  assert.match(appSource, /pager\.addEventListener\("scrollend", finishFeedPagerScroll\)/);
  assert.match(appSource, /touchstart", handleFeedPagerTouchStart/);
  assert.match(appSource, /touchend", handleFeedPagerTouchEnd/);
  assert.match(appSource, /if \(!feedPagerSupportsScrollEnd && !feedPagerTouchActive\)/);
  assert.match(appSource, /!contentScrollIsSnapped\(pager\.scrollLeft, pager\.clientWidth\)/);
  assert.match(appSource, /new ResizeObserver\(handleFeedPagerResize\)/);
  assert.match(appSource, /const feedPanelHeights = new Map\(\)/);
  assert.match(appSource, /feedPanelHeights\.get\(tab\)/);
  assert.match(appSource, /Math\.max\(\.\.\.contentTabs\.map\(contentPanelHeight\)\)/);
  assert.match(appSource, /invalidateFallbackFeedPanelHeight\("clipboard"\)/);
  assert.match(appSource, /invalidateFallbackFeedPanelHeight\("agent"\)/);
  assert.match(appSource, /syncFeedPagerHeight\(\)/);
  assert.match(appSource, /panel\.inert = !active/);
  assert.match(appSource, /event\.key === "ArrowLeft"/);
  assert.match(appSource, /event\.key === "ArrowRight"/);
  assert.match(appSource, /prefers-reduced-motion: reduce/);
});

test("agent notifications open the Agent tab without reloading a live PWA", () => {
  const launch = parseContentTabLaunch(
    "https://dingdong.example/app/?source=push&tab=agent#pair=secret",
    "https://dingdong.example",
  );
  assert.deepEqual(launch, {
    tab: "agent",
    cleanPath: "/app/?source=push#pair=secret",
  });
  assert.equal(
    parseContentTabLaunch(
      "https://dingdong.example/app/?tab=unknown#pair=secret",
      "https://dingdong.example",
    ),
    null,
  );
  assert.equal(
    parseContentTabLaunch(
      "https://attacker.example/app/?tab=agent",
      "https://dingdong.example",
    ),
    null,
  );

  assert.match(appSource, /const initialContentTab = consumeContentTabLaunch\(\) \|\| "clipboard"/);
  assert.match(appSource, /history\.replaceState\(null, "", launch\.cleanPath\)/);
  assert.match(appSource, /event\.data\?\.type === "content-tab\.open"/);
  assert.match(appSource, /type: "content-tab\.opened"/);
  assert.match(appSource, /event\.ports\?\.\[0\]\?\.postMessage/);
  assert.match(appSource, /selectContentTab\(message\.tab, \{ animate: true, reveal: true \}\)/);
  assert.match(
    appSource,
    /typeof message\.room === "string"[\s\S]*message\.room === state\.pair\?\.room[\s\S]*message\.message/,
  );
  assert.match(serviceWorkerSource, /url\.searchParams\.set\("tab", "agent"\)/);
  assert.match(
    serviceWorkerSource,
    /const hasPairingRoom = typeof data\.room === "string"/,
  );
  assert.match(
    serviceWorkerSource,
    /message: hasPairingRoom \? data\.message : undefined/,
  );
  assert.match(serviceWorkerSource, /type: "content-tab\.open"/);
  assert.match(serviceWorkerSource, /appClients\.find\(\(value\) => value\.focused\)/);
  assert.match(serviceWorkerSource, /value\.visibilityState === "visible"/);
  assert.match(serviceWorkerSource, /client\.postMessage\(/);
  assert.match(serviceWorkerSource, /const focusedClient = await focusWindowClient\(client\)/);
  assert.match(serviceWorkerSource, /const acknowledged = await requestContentTabOpen/);
  assert.match(serviceWorkerSource, /new MessageChannel\(\)/);
  assert.match(serviceWorkerSource, /setTimeout\(\(\) => finish\(false\), 1200\)/);
  assert.match(
    serviceWorkerSource,
    /if \(acknowledged\) \{[\s\S]*return refocusedClient \|\| activeClient;\s*\}/,
  );
  assert.match(serviceWorkerSource, /function runClientOperationWithTimeout/);
  assert.match(serviceWorkerSource, /Promise\.race\(/);
  assert.match(
    serviceWorkerSource,
    /navigatedClient === clientOperationTimedOut[\s\S]*return activeClient/,
  );
  assert.match(serviceWorkerSource, /activeClient[\s\S]*\.navigate\(targetUrl\)/);
  assert.match(
    serviceWorkerSource,
    /if \("navigate" in activeClient\)[\s\S]*return self\.clients\.openWindow\(targetUrl\)/,
  );
  assert.match(serviceWorkerSource, /await storeAgentLaunchIntent\(data\)/);
  assert.match(serviceWorkerSource, /idbSet\(agentLaunchIntentKey/);
  assert.match(appSource, /await restorePairFromWorker\(\);\s*await restoreAgentLaunchIntent\(\)/);
  assert.match(appSource, /await idbDelete\(agentLaunchIntentKey\)/);
  assert.match(appSource, /intent\?\.tab !== "agent"/);
  assert.match(appSource, /intent\.room === state\.pair\?\.room/);
  assert.match(appSource, /Date\.now\(\) - intent\.createdAt > agentLaunchIntentTtlMs/);
});

test("stale socket and data-channel callbacks cannot mutate a newer connection", () => {
  assert.match(appSource, /const connectionGeneration = state\.connectionGeneration/);
  assert.match(appSource, /const relayGeneration = state\.relayGeneration \+ 1/);
  assert.match(appSource, /handleRelayFrame\(event\.data, context\)/);
  assert.match(appSource, /openEnvelope\(frame\.payload, context\.key\)/);
  assert.match(appSource, /queueIncomingEnvelope\(event\.data, context\)/);
  assert.match(appSource, /openEnvelope\(envelope, context\.key\)/);
  assert.match(appSource, /if \(!connectionContextIsCurrent\(context\)\) return/);
  assert.match(appSource, /if \(!channelContextIsCurrent\(context\)\) return/);
  assert.doesNotMatch(
    appSource,
    /handleDeviceMessage\(await openEnvelope\(envelope, state\.signalKey\)\)/,
  );
});

test("agent completion reminders default on without claiming delivery before push is ready", () => {
  const legacyPair = { agentNotificationsEnabled: false };
  assert.equal(applyAgentNotificationDefault(legacyPair), true);
  assert.equal(wantsAgentNotifications(legacyPair), true);
  assert.equal(legacyPair.agentNotificationPreferenceSet, false);
  assert.equal(
    agentNotificationsAreActive(legacyPair, "granted", true),
    true,
  );
  assert.equal(
    agentNotificationsAreActive(legacyPair, "default", true),
    false,
  );
  assert.equal(
    agentNotificationsAreActive(legacyPair, "granted", false),
    false,
  );

  const explicitlyDisabled = {
    agentNotificationsEnabled: false,
    agentNotificationPreferenceSet: true,
  };
  assert.equal(applyAgentNotificationDefault(explicitlyDisabled), false);
  assert.equal(wantsAgentNotifications(explicitlyDisabled), false);
  assert.match(appSource, /agentNotificationsEnabled: wantsAgentNotifications\(state\.pair\)/);
  assert.match(appSource, /enableAgentNotifications\(\{ markPreference: false \}\)/);
  assert.match(
    appSource,
    /await registerPushSubscription\(\{ pair, generation \}\);[\s\S]*state\.pushSubscriptionReady = true/,
  );
  assert.match(appSource, /state\.pushSubscriptionReady = false;[\s\S]*await sendSettings\(\)/);
  assert.match(appSource, /const generation = state\.notificationGeneration \+ 1/);
  assert.match(appSource, /await cleanupPushSubscription\(cleanupPair\)/);
  assert.match(appSource, /function queuePushMutation\(operation\)/);
  assert.match(pageSource, /默认开启，等待系统授权/);
  assert.match(serviceWorkerSource, /notification-policy\.js/);
});

test("the PWA shell refreshes from the network before falling back to cache", () => {
  assert.match(serviceWorkerSource, /isApplicationShell \? networkFirst\(request\)/);
  assert.match(serviceWorkerSource, /request\.mode === "navigate"/);
  assert.match(serviceWorkerSource, /const response = await fetch\(request\)/);
  assert.match(serviceWorkerSource, /if \(cached\) return cached/);
  assert.match(serviceWorkerSource, /key\.startsWith\("dingdong-app-shell-"\)/);
});

test("desktop pairing and the Worker share the custom connection domain", () => {
  assert.match(
    desktopMainSource,
    /https:\/\/dingdong\.xn--m8txu\.com\/app\//,
  );
  assert.match(
    desktopMainSource,
    /https:\/\/dingdong\.xn--m8txu\.com'/,
  );
  assert.match(
    wranglerSource,
    /"pattern": "dingdong\.xn--m8txu\.com"/,
  );
  assert.match(wranglerSource, /"custom_domain": true/);
});

test("encrypted relay data is the fallback when local WebRTC cannot connect", () => {
  assert.match(
    appSource,
    /frame\.type === "data" && typeof frame\.payload === "string"/,
  );
  assert.match(
    appSource,
    /const relayFrame = encodeRelayFrame\("data", envelope\)/,
  );
  assert.match(appSource, /state\.socket\.send\(relayFrame\)/);
  assert.match(
    appSource,
    /state\.relayHostPresent && state\.socket\?\.readyState === WebSocket\.OPEN/,
  );
  assert.match(appSource, /state\.relayFrames = state\.relayFrames/);
  assert.match(desktopSessionSource, /frame\['type'\] == 'data'/);
  assert.match(
    desktopSessionSource,
    /encodeDeviceLinkRelayFrame\(\s*type: 'data',\s*envelope: envelope/,
  );
  assert.match(desktopSessionSource, /_relayMessages = _relayMessages\.then/);
  assert.match(
    desktopSessionSource,
    /bool get connected => _dataChannelConnected \|\| _relayConnected/,
  );
});

test("a saved pairing survives refresh and a stale matching QR fragment", () => {
  const stored = {
    version: 1,
    room: "abcdefghijklmnopqrstuvwx",
    secret: "BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc",
    relay: "https://relay.example",
  };
  const scanned = { ...stored, v: 1, version: undefined };
  assert.equal(isStoredPairing(stored), true);
  assert.equal(isStoredPairing(scanned), true);
  assert.equal(pairingsMatch(stored, scanned), true);
  assert.equal(pairingsMatch(stored, { ...scanned, room: "another-room" }), false);
  assert.match(appSource, /await restorePairFromWorker\(\)/);
  assert.match(appSource, /async function idbGet\(key\)/);
  assert.match(appSource, /const launchPair = capturePairingLaunch\(\)/);
  assert.match(appSource, /storageKeys\.pendingPair/);
  assert.match(appSource, /10 \* 60 \* 1000/);
  assert.match(appSource, /scannedPair && pairingsMatch\(state\.pair, scannedPair\)/);
  assert.match(
    appSource,
    /clearPairingFragment\(\);\s*clearPendingPairingLaunch\(\);\s*savePair\(\)/,
  );
  assert.match(serviceWorkerSource, /pairing-state\.js/);
  assert.match(serviceWorkerSource, /content-navigation\.js/);
  assert.doesNotMatch(serviceWorkerSource, /client\.navigate\(client\.url\)/);
});

test("the mobile page exposes a real PWA install experience", () => {
  const iconSizes = new Set(manifest.icons.map((icon) => icon.sizes));
  assert.equal(manifest.id, "./");
  assert.equal(manifest.display, "standalone");
  assert.equal(manifest.handle_links, "preferred");
  assert.equal(manifest.launch_handler.client_mode, "navigate-existing");
  assert.equal(manifest.prefer_related_applications, false);
  assert.deepEqual(manifest.related_applications, [
    {
      platform: "webapp",
      url: "./manifest.webmanifest",
      id: "https://dingdong.xn--m8txu.com/",
    },
  ]);
  assert.deepEqual(iconSizes, new Set(["192x192", "512x512"]));
  assert.deepEqual(
    pngDimensions(
      readFileSync(new URL("../../docs/assets/dingdong-pwa-192.png", import.meta.url)),
    ),
    { width: 192, height: 192 },
  );
  assert.deepEqual(
    pngDimensions(
      readFileSync(new URL("../../docs/assets/dingdong-pwa-512.png", import.meta.url)),
    ),
    { width: 512, height: 512 },
  );
  assert.match(pageSource, /id="install-app-banner"/);
  assert.match(pageSource, /id="install-app-button"/);
  assert.match(pageSource, /添加到主屏幕（可选）/);
  assert.match(pageSource, /不添加也能直接连接和传内容/);
  assert.match(appSource, /"beforeinstallprompt"/);
  assert.match(appSource, /await prompt\.prompt\(\)/);
  assert.match(appSource, /"appinstalled"/);
  assert.match(appSource, /markInstallRequested\(\)/);
  assert.match(appSource, /navigator\.getInstalledRelatedApps\(\)/);
  assert.match(appSource, /applications\.some\(isCurrentWebApp\)/);
  assert.match(appSource, /installedManifestUrl !== manifestUrl/);
  assert.match(appSource, /function markInstallVerified\(\)/);
  assert.match(appSource, /function clearInstallRequest\(\)/);
  assert.match(appSource, /localStorage\.removeItem\(storageKeys\.installRequest\)/);
  assert.match(appSource, /state\.installStatus = "installed"/);
  assert.match(appSource, /Chrome 没有完成添加/);
  assert.match(appSource, /Macintosh[\s\S]*navigator\.maxTouchPoints > 1/);
  assert.doesNotMatch(appSource, /state\.installStatus = "accepted"/);
  assert.doesNotMatch(appSource, /等小米把图标放好/);
  assert.doesNotMatch(appSource, /应用抽屉/);
});

test("notification diagnostics are platform-aware and never require closing all overlays", () => {
  assert.match(pageSource, /id="notification-help-dialog"/);
  assert.match(pageSource, /id="notification-permission-status"/);
  assert.match(pageSource, /id="notification-subscription-status"/);
  assert.match(pageSource, /id="notification-provider-status"/);
  assert.match(pageSource, /id="notification-device-status"/);
  assert.match(pageSource, /id="notification-recheck"/);
  assert.match(pageSource, /id="vibration-test"/);
  assert.match(pageSource, /id="vibration-test-result"/);
  assert.match(appSource, /const directVibrationPattern = \[300, 100, 300, 100, 600\]/);
  assert.match(appSource, /typeof navigator\.vibrate !== "function"/);
  assert.match(appSource, /navigator\.vibrate\(directVibrationPattern\)/);
  assert.match(appSource, /返回值：true/);
  assert.match(appSource, /返回值：false/);
  assert.match(appSource, /!\("Notification" in window\)/);
  assert.match(appSource, /地址栏左侧的网站信息图标/);
  assert.match(appSource, /设置 → 通知 → DingDong/);
  assert.match(appSource, /无需关闭所有应用的悬浮窗权限/);
  assert.match(appSource, /async function sendTestPush\(\{[\s\S]*allowSubscriptionRefresh = true,[\s\S]*\}\)/);
  assert.match(appSource, /浏览器已创建测试通知/);
  assert.match(appSource, /result\?\.accepted !== true/);
  assert.match(appSource, /waitForPushReceipt\(messageId, pair, generation\)/);
  assert.match(appSource, /PushManager\.supportedContentEncodings/);
  assert.match(appSource, /applicationServerKeysMatch/);
  assert.match(appSource, /registration\?\.pushManager\?\.getSubscription\(\)/);
  assert.match(appSource, /navigator\.serviceWorker\?\.getRegistration\("\.\/"\)/);
  assert.match(appSource, /async function withTimeout\(promise, timeoutMs, message\)/);
  assert.doesNotMatch(pageSource, /临时关闭侧边栏、气泡、小窗/);
  assert.doesNotMatch(appSource, /Android 为防止悬浮层遮住授权按钮/);
  assert.doesNotMatch(serviceWorkerSource, /silent:\s*!vibrate/);
  assert.match(serviceWorkerSource, /agent\.completed\.realtime/);
  assert.match(appSource, /notificationEpoch: pair\.notificationEpoch/);
  assert.match(appSource, /navigator\.locks\?\.request/);
  assert.match(serviceWorkerSource, /context\.notificationEpoch !== pair\.notificationEpoch/);
  assert.match(serviceWorkerSource, /notificationResult === "stale"/);
  assert.match(serviceWorkerSource, /postPushReceipt\(pair, messageId, "created"\)/);
  assert.match(serviceWorkerSource, /await receivedHealth;[\s\S]*recordPushHealth\([\s\S]*"created"/);
  assert.match(serviceWorkerSource, /function workerPairMatches\(expected, current\)/);
  assert.match(serviceWorkerSource, /if \(payload\.room !== pair\.room\) return/);
  assert.match(serviceWorkerSource, /"decrypt-failed"/);
  assert.match(serviceWorkerSource, /shouldRevokeBrokenPushSubscription/);
  assert.match(serviceWorkerSource, /pushFailureContextStillCurrent\(pair\)/);
  assert.match(serviceWorkerSource, /workerPairSnapshotMatches\(failedPair, currentPair\)/);
  assert.match(
    serviceWorkerSource,
    /const notificationVibrationPattern = \[250, 100, 250, 100, 450\]/,
  );
  assert.match(serviceWorkerSource, /vibrate: notificationVibrationPattern/);
});

test("a realtime duplicate never masquerades as a Push-created notification", () => {
  const duplicateStart = serviceWorkerSource.indexOf(
    'if (notificationResult === "duplicate")',
  );
  const createdStart = serviceWorkerSource.indexOf(
    'await recordPushHealth(\n      "created"',
    duplicateStart,
  );
  assert.ok(duplicateStart >= 0);
  assert.ok(createdStart > duplicateStart);
  const duplicateBranch = serviceWorkerSource.slice(duplicateStart, createdStart);
  assert.match(duplicateBranch, /postPushReceipt\(pair, messageId, "received"\)/);
  assert.match(duplicateBranch, /stage: "received"/);
  assert.doesNotMatch(duplicateBranch, /postPushReceipt\(pair, messageId, "created"\)/);
  assert.doesNotMatch(duplicateBranch, /recordPushHealth\(\s*"created"/);
});

test("mobile mascots use dark assets and the sleeping mascot alternates frames", () => {
  const mobileAlert = readFileSync(
    new URL("../../docs/assets/dingdong-mobile-alert-icon.png", import.meta.url),
  );
  const darkAlert = readFileSync(
    new URL("../../Assets/DingDongIP/ding.png", import.meta.url),
  );
  const mobileAlert2 = readFileSync(
    new URL("../../docs/assets/dingdong-mobile-alert-icon-2.png", import.meta.url),
  );
  const darkAlert2 = readFileSync(
    new URL("../../Assets/DingDongIP/ding2.png", import.meta.url),
  );
  assert.deepEqual(mobileAlert, darkAlert);
  assert.deepEqual(mobileAlert2, darkAlert2);
  assert.match(pageSource, /dingdong-sleeping-icon\.png/);
  assert.match(pageSource, /dingdong-sleeping-icon-2\.png/);
  assert.match(stylesSource, /@keyframes sleeping-frame-one/);
  assert.match(stylesSource, /@keyframes sleeping-frame-two/);
  assert.match(pageSource, /让完成后提醒/);
  assert.doesNotMatch(pageSource, /敲门/);
  assert.doesNotMatch(pageSource, /dingdong-alert-icon(?:-2)?\.png/);
  assert.doesNotMatch(appSource, /dingdong-alert-icon(?:-2)?\.png/);
  assert.doesNotMatch(serviceWorkerSource, /dingdong-alert-icon(?:-2)?\.png/);
});

test("the phone defaults to the most specific browser-provided device name", async () => {
  const navigatorLike = {
    userAgent: "Mozilla/5.0 (Linux; Android 16; K) AppleWebKit/537.36",
    userAgentData: {
      async getHighEntropyValues(hints) {
        assert.deepEqual(hints, ["model"]);
        return { model: "Xiaomi 17 Ultra" };
      },
    },
  };

  assert.equal(await detectDeviceName(navigatorLike), "Xiaomi 17 Ultra");
  assert.equal(defaultDeviceName(navigatorLike), "Android 手机");
  assert.match(appSource, /await upgradeDefaultIdentityName\(\)/);
  assert.match(serviceWorkerSource, /device-name\.js/);
  assert.doesNotMatch(appSource, /name:\s*isIos\(\)\s*\?\s*"iPhone"\s*:\s*"我的手机"/);
});

test("device-name detection falls back safely without inventing a model", async () => {
  const legacyUserAgent =
    "Mozilla/5.0 (Linux; Android 14; 2304FPN6DG Build/UKQ1.230804.001; wv) AppleWebKit/537.36";
  assert.equal(modelFromUserAgent(legacyUserAgent), "2304FPN6DG");
  assert.equal(
    modelFromUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36"),
    "",
  );
  assert.equal(normalizeDeviceModel("  25128PNA1G Build/ABCD  "), "25128PNA1G");
  assert.equal(
    await detectDeviceName({
      userAgent: legacyUserAgent,
      userAgentData: {
        async getHighEntropyValues() {
          throw new Error("high-entropy values withheld");
        },
      },
    }),
    "2304FPN6DG",
  );
  assert.equal(
    await detectDeviceName({
      userAgent: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36",
    }),
    "Android 手机",
  );
  assert.equal(defaultDeviceName({ userAgent: "Mozilla/5.0 (iPhone)" }), "iPhone");
  assert.equal(
    defaultDeviceName({ userAgent: "Mozilla/5.0 (Macintosh)", maxTouchPoints: 5 }),
    "iPad",
  );
});

test("legacy automatic names migrate while user-selected names stay untouched", () => {
  assert.equal(shouldUpgradeAutomaticDeviceName({ name: "我的手机" }), true);
  assert.equal(
    shouldUpgradeAutomaticDeviceName({ name: "Xiaomi 17 Ultra", nameSource: "automatic" }),
    true,
  );
  assert.equal(
    shouldUpgradeAutomaticDeviceName({ name: "小米工作机", nameSource: "user" }),
    false,
  );
  assert.equal(shouldUpgradeAutomaticDeviceName({ name: "小米工作机" }), false);
});

test("the public asset allowlist excludes project documentation", () => {
  assert.match(assetsIgnoreSource, /^\/\*$/m);
  assert.match(assetsIgnoreSource, /^!\/app\/\*\*$/m);
  assert.match(assetsIgnoreSource, /^!\/assets\/dingdong-icon\.png$/m);
  assert.match(assetsIgnoreSource, /^!\/assets\/dingdong-pwa-192\.png$/m);
  assert.match(assetsIgnoreSource, /^!\/assets\/dingdong-pwa-512\.png$/m);
  assert.match(
    assetsIgnoreSource,
    /^!\/assets\/dingdong-mobile-alert-icon\.png$/m,
  );
  assert.match(assetsIgnoreSource, /^!\/assets\/dingdong-sleeping-icon-2\.png$/m);
  assert.doesNotMatch(assetsIgnoreSource, /^!\/product(?:\/|$)/m);
  assert.doesNotMatch(assetsIgnoreSource, /^!\/superpowers(?:\/|$)/m);
});

test("the deployed PWA declares browser security and cache headers", () => {
  assert.doesNotMatch(assetsIgnoreSource, /!\/_headers/);
  assert.match(assetHeadersSource, /^\/app\/\*/m);
  assert.match(assetHeadersSource, /Content-Security-Policy:/);
  assert.match(assetHeadersSource, /default-src 'self'/);
  assert.match(assetHeadersSource, /style-src 'self'/);
  assert.match(assetHeadersSource, /X-Content-Type-Options: nosniff/);
  assert.match(assetHeadersSource, /Referrer-Policy: no-referrer/);
  assert.match(assetHeadersSource, /Strict-Transport-Security: max-age=31536000/);
  assert.match(assetHeadersSource, /Cache-Control: no-cache/);
});

async function encryptedRelayDataFrame(message) {
  const key = await webcrypto.subtle.importKey(
    "raw",
    new Uint8Array(32).fill(7),
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
  const nonce = new Uint8Array(12);
  const clear = new TextEncoder().encode(JSON.stringify(message));
  const encrypted = new Uint8Array(
    await webcrypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, key, clear),
  );
  const envelope = Buffer.concat([
    Buffer.from(nonce),
    Buffer.from(encrypted),
  ]).toString("base64url");
  return JSON.stringify({ type: "data", payload: envelope });
}

function pngDimensions(value) {
  assert.equal(value.subarray(1, 4).toString("ascii"), "PNG");
  return {
    width: value.readUInt32BE(16),
    height: value.readUInt32BE(20),
  };
}
