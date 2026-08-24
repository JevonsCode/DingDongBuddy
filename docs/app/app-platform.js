// Browser and installation-surface capability checks are available before app state loads.
function isIos() {
  return (
    /iPhone|iPad|iPod/i.test(navigator.userAgent) ||
    (/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1)
  );
}

function isAndroid() {
  return /Android/i.test(navigator.userAgent);
}

function isStandalone() {
  return (
    window.matchMedia("(display-mode: standalone)").matches ||
    window.navigator.standalone === true
  );
}

function isMobileBrowser() {
  return (
    navigator.userAgentData?.mobile === true ||
    isAndroid() ||
    isIos()
  );
}

export {
  isAndroid,
  isIos,
  isMobileBrowser,
  isStandalone,
};
