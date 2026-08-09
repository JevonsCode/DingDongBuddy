# DingDong Cloudflare service

This Worker hosts the phone PWA, the encrypted device-link relay, Web Push, and
DingDong's bounded install/upgrade counts. Lifecycle statistics use D1 and are
independent of clipboard relay traffic.

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
