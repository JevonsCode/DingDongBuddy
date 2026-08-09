export function isStoredPairing(value) {
  if (!value || typeof value !== "object") return false;
  const version = value.version ?? value.v;
  return (
    version === 1 &&
    typeof value.room === "string" &&
    value.room.length > 0 &&
    typeof value.secret === "string" &&
    value.secret.length > 0 &&
    typeof value.relay === "string" &&
    value.relay.length > 0
  );
}

export function pairingsMatch(stored, scanned) {
  return (
    isStoredPairing(stored) &&
    isStoredPairing(scanned) &&
    stored.room === scanned.room &&
    stored.secret === scanned.secret &&
    stored.relay === scanned.relay
  );
}
