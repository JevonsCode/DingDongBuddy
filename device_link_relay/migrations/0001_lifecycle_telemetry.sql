-- DingDong's opt-in lifecycle statistics. Raw installation identifiers and
-- client IP addresses are deliberately never persisted.
CREATE TABLE IF NOT EXISTS lifecycle_events (
  event_id TEXT PRIMARY KEY,
  installation_hash TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('install', 'upgrade')),
  current_version TEXT NOT NULL,
  current_build TEXT NOT NULL,
  previous_version TEXT,
  previous_build TEXT,
  platform TEXT NOT NULL CHECK (platform IN ('macos', 'windows')),
  architecture TEXT NOT NULL CHECK (
    architecture IN ('arm64', 'x64', 'x86', 'other')
  ),
  occurred_at TEXT NOT NULL,
  received_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS lifecycle_events_type_version_idx
  ON lifecycle_events(event_type, current_version, occurred_at);

CREATE INDEX IF NOT EXISTS lifecycle_events_installation_idx
  ON lifecycle_events(installation_hash, occurred_at);

CREATE TABLE IF NOT EXISTS lifecycle_installations (
  installation_hash TEXT PRIMARY KEY,
  first_seen_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  first_event_at TEXT NOT NULL,
  last_event_at TEXT NOT NULL,
  first_version TEXT NOT NULL,
  current_version TEXT NOT NULL,
  current_build TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('macos', 'windows')),
  architecture TEXT NOT NULL CHECK (
    architecture IN ('arm64', 'x64', 'x86', 'other')
  )
);

CREATE INDEX IF NOT EXISTS lifecycle_installations_version_idx
  ON lifecycle_installations(current_version, platform);
