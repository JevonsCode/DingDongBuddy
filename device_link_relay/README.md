# DingDong Cloudflare service

This Worker hosts the phone PWA, the encrypted device-link relay, desktop peer
discovery, Web Push, and DingDong's bounded install/upgrade counts. Lifecycle statistics use D1 and are
independent of clipboard relay traffic.

## Desktop peer discovery

Desktop clients open `/v1/discovery/{slot}?side=host|peer` over WSS. The
existing `RELAY_ROOMS` binding uses a separate `discovery:` object name prefix.
Only the first two digits of an invitation appear in its `invite-NN` slot.
The peers authenticate the remaining digits with SRP. A host reserves its
slot for five minutes, with one concurrent peer and five peer admissions total.
When the user cancels or pairing succeeds, the current host sends the local
control frame `{"type":"release"}` and the Worker immediately frees the slot.
An unexpected disconnect keeps the slot and its trial count until expiry.
Each source IP can try eight public reservations and fifteen public lookups per
fixed minute. Phone and private paired-device connections retain their shared
60-connection-per-minute allowance. HTTP 404 means no host is present, 409 means the slot or peer position is
occupied, and 429 indicates a rate or admission limit.

A paired slot uses `pair-` followed by a secret 43-character base64url value.
Either device can connect first. A reconnect replaces that side's old socket.
Each socket receives a `relay` message with event `ready`. When both sides
are present, each receives `host_joined` or `peer_joined` naming its partner.
Clients initiate exchanges on those events and discard outstanding challenges
when their partner changes or leaves.

Invitations forward one `hello`, `challenge`, `proof`, `offer` sequence per
peer. Paired devices exchange `who` and encrypted `addresses` responses.
The Worker validates frame type, allowed fields, direction, size (4 KiB) and
rate (12 frames per minute per socket). Only the random lease ID, expiry and admission count
go into invitation storage. Connection attachments hold protocol state, and
the desktop clients exchange clipboard and file data over their direct link.

## Lifecycle-statistics privacy contract

The public endpoint is `POST /v1/telemetry/lifecycle`. It accepts only
`install` and `upgrade` events with a random installation UUID, event UUID,
app/build version, platform, architecture, and timestamp. The Worker applies a
per-IP rate limit but never writes the IP to D1. It HMACs the installation UUID
with `TELEMETRY_HASH_SECRET`; only the resulting hash is persisted. Event IDs
make offline retries idempotent.

The resulting numbers are approximate observed installation counts, not active
users or license checks. Removing all local app data can create a new random
identifier, and a modified public client can submit synthetic events.

The desktop app enables lifecycle statistics by default and exposes an opt-out
under **Settings → Version**. It has no session, heartbeat, activity,
feature-use, clipboard, file, or Agent-message events.

## D1 setup

Create the production database once, add its real ID to the `TELEMETRY_DB`
binding in `wrangler.jsonc`, then configure and migrate it:

```bash
npx wrangler d1 create dingdong-lifecycle-telemetry
npx wrangler secret put TELEMETRY_HASH_SECRET
npx wrangler d1 migrations apply dingdong-lifecycle-telemetry --remote
```

Use a cryptographically random secret of at least 32 characters. Rotating it
changes all future installation hashes, so treat rotation as starting a new
unique-installation series.

## Reading the counts

These queries expose only aggregate lifecycle data:

```sql
-- New installations observed after this feature was enabled.
SELECT COUNT(*) AS installs
FROM lifecycle_events
WHERE event_type = 'install';

-- Installations seen through either an install or upgrade event.
SELECT COUNT(*) AS known_installations
FROM lifecycle_installations;

-- Upgrade adoption by destination version.
SELECT current_version, COUNT(*) AS upgrades
FROM lifecycle_events
WHERE event_type = 'upgrade'
GROUP BY current_version
ORDER BY current_version DESC;

-- Daily event trend.
SELECT substr(received_at, 1, 10) AS day, event_type, COUNT(*) AS events
FROM lifecycle_events
GROUP BY day, event_type
ORDER BY day DESC, event_type;
```

Run a query with:

```bash
npx wrangler d1 execute dingdong-lifecycle-telemetry --remote \
  --command "SELECT COUNT(*) AS known_installations FROM lifecycle_installations"
```
