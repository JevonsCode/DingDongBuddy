# DingDong First-Run Onboarding

This checklist keeps the first session focused on the product's core loop: manage reusable agent resources, use clipboard history, and receive final-task notifications.

## First Session

1. Open DingDong from the macOS menu bar.
2. Open Settings and confirm the local API is running.
3. Turn on Clipboard if the user wants history capture.
4. Grant Accessibility only when quick paste back to the previous input field is needed.
5. Open Resource Manager and add one Prompt, Skill, or MCP reference.
6. Install the DingDong MCP in the target agent.
7. Start a small agent task and confirm it calls `dingdong_bridge` at task start.
8. Confirm the agent calls `dingdong_notify` once when the whole task is complete, blocked, or waiting for user attention.

## Good Empty States

- Library: explain that resources are user-managed and no default packs are installed.
- Clipboard: explain retention defaults, supported content types, and privacy behavior.
- Settings: show API status, MCP setup help, launch-at-login, retention, permissions, and update status.

## Privacy Baseline

- Clipboard history is local-only by default. Copied image files retain only
  their source paths, while screenshots without a source path use managed local
  storage and follow clipboard retention.
- Agent clipboard content access is off by default and is controlled in
  DingDong Settings; metadata remains available while it is off.
- Skills and MCP resources should be summary-first.
- Full resource content is loaded only by explicit id or user intent.
- Sensitive clipboard records require an additional explicit request even after
  Agent clipboard content access is enabled.
