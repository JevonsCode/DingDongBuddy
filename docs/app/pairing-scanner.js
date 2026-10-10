// In-app QR scanning for pairing links. Uses the browser's BarcodeDetector,
// which Chrome on Android provides; elsewhere the entry point stays hidden and
// the system camera or a pasted link remains the way to pair.
const scanIntervalMs = 250;

export function pairingScannerSupported() {
  return (
    typeof window !== "undefined" &&
    "BarcodeDetector" in window &&
    Boolean(navigator.mediaDevices?.getUserMedia)
  );
}

export function createPairingScanner({ elements, onPairingText }) {
  const dialog = elements["pairing-scanner-dialog"];
  const video = elements["pairing-scanner-video"];
  const status = elements["pairing-scanner-status"];
  let stream = null;
  let timer = null;
  let detector = null;
  let generation = 0;

  function stop() {
    generation += 1;
    clearTimeout(timer);
    timer = null;
    stream?.getTracks().forEach((track) => track.stop());
    stream = null;
    video.srcObject = null;
  }

  function close() {
    stop();
    if (dialog.open) dialog.close();
  }

  async function open() {
    if (!pairingScannerSupported()) return false;
    stop();
    const current = generation;
    status.textContent = "正在打开相机…";
    if (!dialog.open) dialog.showModal();
    try {
      detector ??= new window.BarcodeDetector({ formats: ["qr_code"] });
      stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: "environment" } },
        audio: false,
      });
      if (current !== generation) {
        stream.getTracks().forEach((track) => track.stop());
        return false;
      }
      video.srcObject = stream;
      await video.play();
      status.textContent = "对准电脑上“连接设备”里的二维码";
      scan(current);
      return true;
    } catch (error) {
      stop();
      status.textContent =
        error?.name === "NotAllowedError"
          ? "没有相机权限。可以在浏览器的网站设置里允许，或改用“粘贴连接链接”。"
          : "无法打开相机，请改用手机相机扫描或粘贴连接链接。";
      return false;
    }
  }

  async function scan(current) {
    if (current !== generation) return;
    try {
      if (video.readyState >= 2) {
        const codes = await detector.detect(video);
        if (current !== generation) return;
        const value = codes.find((code) => code.rawValue)?.rawValue;
        if (value) {
          if (onPairingText(value)) {
            close();
            return;
          }
          status.textContent = "这不是 DingDong 的连接二维码，请对准电脑上的二维码";
        }
      }
    } catch {
      // A frame can fail to decode while the camera adjusts; keep scanning.
    }
    timer = setTimeout(() => scan(current), scanIntervalMs);
  }

  dialog.addEventListener("close", stop);
  elements["pairing-scanner-close"].addEventListener("click", close);
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden" && dialog.open) close();
  });

  return { open, close };
}
