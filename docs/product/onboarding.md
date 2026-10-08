# DingDong First-Run Onboarding

This checklist keeps the first session focused on DingDong's free local tools: organize and reuse copied content, manage shared Agent resources, and review connected-Agent events with a notification preference you choose. Codex already has completion notifications; DingDong adds a shared event inbox and does not automatically replace the client's own alerts.

## First Session

1. Open DingDong from the macOS menu bar or Windows system tray.
2. Open Settings and confirm the local API is running.
3. Turn on Clipboard monitoring if the user wants capture. Copy one text snippet, image, or file reference; try classification, search, preview, and reuse. Save and pin a useful item for later.
4. On macOS, grant Accessibility only when quick paste back to the previous input field is needed. Ordinary clipboard capture does not require it; Windows has no corresponding macOS permission step.
5. Open Resource Manager and add one Prompt, Skill, or MCP reference.
6. Connect the DingDong MCP and the supported native completion Hook in the target Agent, preserving unrelated client settings.
7. Start a small Agent task and confirm it calls `dingdong_bridge` at task start.
8. Confirm that the completion Hook records the final event once, then choose which Agent events notify and which sound they use. Do not add a duplicate `dingdong_notify` call for the same completion; use it for a blocker, a request for attention, or a client without a completion Hook.
9. In the 1.7.0 development version, open Resource Manager → Token history to inspect the daily heatmap for supported Codex, Claude Code, and Pi sources. Filter by year or source and select a day. Published 1.6.2 downloads do not include this feature yet.

## Good Empty States

- Library: explain that resources are user-managed and no default packs are installed.
- Clipboard: explain monitoring starts off, classifications and search help retrieve reusable content, saved items can be pinned, and retention follows the local settings.
- Token history: explain that missing local evidence is unknown, and incomplete daily counts are lower bounds marked with `≥`; never imply a zero or estimate a monetary cost.
- Settings: show API status, MCP setup help, launch-at-login, retention, permissions, and update status.

## Privacy Baseline

- Anonymous installation and upgrade statistics are enabled by default and can
  be turned off in Settings. Their payload contains installation/event
  identifiers, version/build, platform/architecture, and event time. It excludes
  clipboard content, resources, conversation text, and local Token history.
- Clipboard history is local-only by default. Copied image files retain only
  their source paths, while screenshots without a source path use managed local
  storage and follow clipboard retention.
- Agent clipboard content access is off by default and is controlled in
  DingDong Settings; metadata remains available while it is off.
- Local Token history stores numeric usage aggregates on this computer, not
  conversation text. It is separate from installation and upgrade statistics.
- Skills and MCP resources should be summary-first.
- Full resource content is loaded only by explicit id or user intent.
- Sensitive clipboard records require an additional explicit request even after
  Agent clipboard content access is enabled.
