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

export const pairingRegistryVersion = 2;

export function normalizePairingRegistry(value, legacyPair = null) {
  const candidates = [];
  if (
    value?.version === pairingRegistryVersion &&
    Array.isArray(value.pairings)
  ) {
    candidates.push(...value.pairings);
  } else if (Array.isArray(value)) {
    candidates.push(...value);
  }
  if (isStoredPairing(legacyPair)) candidates.push(legacyPair);

  const byRoom = new Map();
  for (const candidate of candidates) {
    if (!isStoredPairing(candidate)) continue;
    if (!byRoom.has(candidate.room)) {
      byRoom.set(candidate.room, { ...candidate, version: 1 });
    }
  }
  const pairings = Array.from(byRoom.values());
  const requestedActiveRoom =
    typeof value?.activeRoom === "string" ? value.activeRoom : null;
  const activeRoom = pairings.some(
    (pairing) => pairing.room === requestedActiveRoom,
  )
    ? requestedActiveRoom
    : pairings[0]?.room || null;
  return { version: pairingRegistryVersion, activeRoom, pairings };
}

export function upsertPairing(registry, pairing, { makeActive = true } = {}) {
  if (!isStoredPairing(pairing)) return normalizePairingRegistry(registry);
  const current = normalizePairingRegistry(registry);
  const index = current.pairings.findIndex(
    (candidate) => candidate.room === pairing.room,
  );
  const pairings = current.pairings.map((candidate) => ({ ...candidate }));
  if (index >= 0) pairings[index] = { ...pairing, version: 1 };
  else pairings.push({ ...pairing, version: 1 });
  return {
    version: pairingRegistryVersion,
    activeRoom: makeActive ? pairing.room : current.activeRoom,
    pairings,
  };
}

export function removePairing(registry, room) {
  const current = normalizePairingRegistry(registry);
  const pairings = current.pairings.filter((pairing) => pairing.room !== room);
  return {
    version: pairingRegistryVersion,
    activeRoom:
      current.activeRoom === room
        ? pairings[0]?.room || null
        : current.activeRoom,
    pairings,
  };
}

export function pairingForRoom(registry, room) {
  if (typeof room !== "string") return null;
  return (
    normalizePairingRegistry(registry).pairings.find(
      (pairing) => pairing.room === room,
    ) || null
  );
}

export function shouldSkipPairingCleanup(cleanupPair, currentPair) {
  if (!isStoredPairing(currentPair)) return false;
  return (
    !pairingsMatch(cleanupPair, currentPair) ||
    cleanupPair.notificationEpoch !== currentPair.notificationEpoch ||
    currentPair.agentNotificationsEnabled === true
  );
}
