const maximumDeviceNameLength = 32;
const legacyAutomaticNames = new Set([
  "",
  "我的手机",
  "Android 手机",
  "移动设备",
]);

export function defaultDeviceName(navigatorLike = globalThis.navigator) {
  const userAgent = String(navigatorLike?.userAgent || "");
  if (
    /iPad/i.test(userAgent) ||
    (/Macintosh/i.test(userAgent) && Number(navigatorLike?.maxTouchPoints) > 1)
  ) {
    return "iPad";
  }
  if (/iPhone|iPod/i.test(userAgent)) return "iPhone";
  if (/Android/i.test(userAgent)) return "Android 手机";
  return "移动设备";
}

export function shouldUpgradeAutomaticDeviceName(identity) {
  if (identity?.nameSource === "user") return false;
  if (identity?.nameSource === "automatic") return true;
  return legacyAutomaticNames.has(String(identity?.name || "").trim());
}

export async function detectDeviceName(
  navigatorLike = globalThis.navigator,
) {
  const fallback = defaultDeviceName(navigatorLike);
  if (fallback !== "Android 手机") return fallback;

  try {
    const userAgentData = navigatorLike?.userAgentData;
    if (typeof userAgentData?.getHighEntropyValues === "function") {
      const values = await userAgentData.getHighEntropyValues(["model"]);
      const model = normalizeDeviceModel(values?.model);
      if (model) return model;
    }
  } catch {
    // Some browsers expose the API but withhold high-entropy values. The
    // legacy user agent remains a best-effort fallback in that case.
  }

  return modelFromUserAgent(navigatorLike?.userAgent) || fallback;
}

export function modelFromUserAgent(value) {
  const userAgent = String(value || "");
  const androidSection = userAgent.match(/\(([^)]*\bAndroid\b[^)]*)\)/i)?.[1];
  if (!androidSection) return "";

  const parts = androidSection.split(";");
  const androidIndex = parts.findIndex((part) => /\bAndroid\b/i.test(part));
  for (let index = parts.length - 1; index > androidIndex; index -= 1) {
    const model = normalizeDeviceModel(parts[index]);
    if (model) return model;
  }
  return "";
}

export function normalizeDeviceModel(value) {
  const model = String(value || "")
    .replace(/[\u0000-\u001f\u007f]/g, "")
    .replace(/\s+Build\/.*$/i, "")
    .replace(/^Build\/.*/i, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maximumDeviceNameLength);

  if (
    !model ||
    /^(?:k|android(?:\s+\d+(?:\.\d+)*)?|mobile|unknown|wv|u)$/i.test(model) ||
    /^[a-z]{2}(?:[-_][a-z]{2})?$/i.test(model)
  ) {
    return "";
  }
  return model;
}
