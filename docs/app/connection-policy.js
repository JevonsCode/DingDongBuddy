const replacementCloseCode = 1008;
const replacementCloseReason = "Replaced by a newer connection";

export function relayConnectionWasReplaced(event) {
  return (
    event?.code === replacementCloseCode &&
    String(event?.reason || "").toLowerCase() ===
      replacementCloseReason.toLowerCase()
  );
}

export function shouldReconnectRelay(event, pair) {
  return Boolean(
    pair &&
      pair.manualDisconnect !== true &&
      !relayConnectionWasReplaced(event),
  );
}
