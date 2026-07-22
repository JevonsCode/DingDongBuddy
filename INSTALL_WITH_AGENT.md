# Install DingDong with a local Agent

This is the canonical, executable installation guide for local coding Agents.
Use it only when the user explicitly asks to install DingDong from
<https://github.com/JevonsCode/DingDongBuddy>. Execute the steps; do not merely
summarize them or tell the user to repeat the setup in another chat.

The required outcome is one local installation with all of the following:

- the latest DingDong release for the computer's supported OS and architecture;
- DingDong running and its loopback health endpoint responding;
- the current Agent connected to DingDong through its native global MCP config;
- one native, persistent task-completion Hook for the current Agent; and
- separate successful tests of the Hook and the `dingdong_notify` MCP tool.

## Safety and support boundaries

1. Continue only in a local Agent session on the computer where DingDong will
   run. A cloud or remote Agent cannot use DingDong's local executable or
   loopback API.
2. Supported first-install targets are macOS on Apple Silicon or Intel, and
   Windows x64. Stop and report the detected platform on any other target.
3. Download only release assets published by
   `https://github.com/JevonsCode/DingDongBuddy`. Do not run a third-party mirror,
   a `curl | shell` command, an appcast, or a NuGet update package as an initial
   installer.
4. Preserve DingDong's local data and every unrelated Agent setting. Replacing
   an existing application bundle or installed version must not remove clipboard
   history, resources, preferences, permissions, or Agent configuration.
5. Do not silently bypass macOS Gatekeeper, Windows SmartScreen, or another OS
   security warning. Ask the user to review and approve an OS prompt when one is
   shown. DingDong's community builds are not Apple-notarized or Authenticode-
   signed, so an initial install may require this confirmation.
6. Do not request Accessibility permission on the user's behalf. It is optional
   and is needed only for Quick Paste; clipboard history, MCP, and completion
   notifications do not require it.

## 1. Resolve the official release

Read the release manifest from:

```text
https://raw.githubusercontent.com/JevonsCode/DingDongBuddy/main/docs/dingdong-release.json
```

Require `app` to equal `DingDong`, and require the selected download URL to begin
with:

```text
https://github.com/JevonsCode/DingDongBuddy/releases/download/
```

Select exactly one `downloads` entry from the detected platform and architecture:

| Local platform | Manifest entry | Expected asset |
| --- | --- | --- |
| macOS `arm64` | `downloads.macOS.arm64.url` | `DingDong-<version>-macos-arm64.dmg` |
| macOS `x86_64` | `downloads.macOS.x86_64.url` | `DingDong-<version>-macos-x64-beta.dmg` |
| Windows `AMD64` / x64 | `downloads.windows.x86_64.url` | `DingDong-<version>-windows-x64-beta-Setup.exe` |

Download the asset over HTTPS to a new temporary directory. Confirm that the
resolved release version and filename match the manifest before opening it.

## 2. Install and start DingDong

### macOS

1. Mount the downloaded DMG and locate its single `DingDong.app`.
2. Verify the app bundle identifier is `com.dingdongbuddy.app`, its short version
   matches `latestVersion`, and `codesign --verify --deep --strict` succeeds.
3. Quit a running DingDong instance gracefully. Replace only the DingDong app at
   `/Applications/DingDong.app`; if that location is not writable, install to
   the current user's `~/Applications/DingDong.app` and use that exact path in
   the remaining steps. There is no need to rename or archive the old app bundle.
4. Unmount the DMG, launch the installed app, and retain the downloaded installer
   only until the verification steps below are complete.
5. The bundled connection executable is:
   `<installed DingDong.app>/Contents/MCP/bundle/bin/dingdong_mcp`.

### Windows

1. Run the downloaded Velopack `Setup.exe` as the current user. It is a per-user
   installation and must not request elevation.
2. Wait for Setup to finish and launch DingDong. Do not use the portable ZIP,
   `.nupkg`, `RELEASES`, or `assets.win.json` as the first installer.
3. Resolve the actual installed `DingDong.exe` from the new installation or its
   Start menu shortcut. The connection executable is relative to that installed
   app directory at `mcp\bundle\bin\dingdong_mcp.exe`. Verify the exact file;
   do not guess an installation directory.

## 3. Verify first launch

DingDong installs its built-in always-on Prompt and `dingdong-configure` Skill
on first launch. It syncs the Prompt into managed blocks in detected Codex
`~/.codex/AGENTS.md` and Claude Code `~/.claude/CLAUDE.md` files, and mirrors the Skill into detected supported clients'
native Skill directories. Do not copy those files manually and do not edit
DingDong's `resource-library.json`.

Read the active loopback port from the platform-specific file:

- macOS: `~/Library/Application Support/DingDong/api-port`
- Windows: `%APPDATA%\DingDong\api-port`

Call `GET http://127.0.0.1:<port>/health` and require a successful response. Use
the port file rather than assuming the default port. If the app does not start
or health fails, stop before changing any Agent configuration and report the
original error.

## 4. Connect the current Agent

Use the verified bundled connection executable as `<DINGDONG_MCP_PATH>` and
perform this setup in the current local Agent or IDE:

1. Find the user-level global MCP configuration actually used by the current
   client. Preserve all existing entries, then add or repair one STDIO MCP server
   named `dingdong`. Its `command` must be the complete
   `<DINGDONG_MCP_PATH>`. Do not add MCP args, environment variables, or a wrapper
   shell.
2. Add exactly one durable native completion Hook, without duplicates, that
   runs:

   ```text
   "<DINGDONG_MCP_PATH>" --notify-stop --source "Current client name"
   ```

   Use the client's native user-level event:

   | Client | MCP configuration | Completion Hook |
   | --- | --- | --- |
   | Codex | `~/.codex/config.toml` | `Stop` command Hook in the same file; set `hooks = true` under `[features]` |
   | Claude Code | user-scope MCP in `~/.claude.json` | `Stop` command Hook in `~/.claude/settings.json` |
   | Cursor | `~/.cursor/mcp.json` | `afterAgentResponse` command Hook in `~/.cursor/hooks.json` |
   | Gemini CLI | `~/.gemini/settings.json` | `AfterAgent` command Hook in the same file |
   | Kiro | `~/.kiro/settings/mcp.json` | Kiro CLI v3 global `Stop` Hook under `~/.kiro/hooks/`, older CLI `hooks.stop` in the active editable custom Agent, or IDE Agent Stop shell-command Hook |

   For another client, verify its native local task-completion Hook first. If it
   has none, configure MCP only and report that automatic completion alerts are
   unsupported. Do not invent a setting. For Kiro versions that expose only a
   project-level Hook, do not modify the project without explicit permission.
3. Validate every changed TOML or JSON file, then reload the client. For Codex,
   restart `dingdong` under **Settings → MCP servers**, then review and trust the
   Hook in `/hooks`. A changed executable path creates a new Hook trust identity.
4. Keep DingDong's resource semantics distinct after connection:
   - Prompt: every active Prompt is delivered in full and applied automatically
     as a required instruction.
   - Skill: match its description first and load the complete Skill only when the
     task fits. Unscoped Skills are global, while strict project Skills are
     synchronized only into native Skill directories below that project; a Skill summary is not an instruction.
   - MCP: configuration only makes tools available; call an MCP tool when the
     task needs it, not automatically on every turn.
5. Confirm the configuration tools `dingdong_install_skill`,
   `dingdong_upsert_trigger_group`, and `dingdong_bind_resource_scope` are
   present. When the user explicitly asks to install a Skill through DingDong
   for one project, use them in that order with an exact existing absolute
   project path and `strictProjectSkill: true`. Do not imitate project isolation
   with a globally synchronized Skill plus a routing hint.

## 5. Test both connections and report

1. Pipe this JSON object as standard input to the exact Hook command and confirm
   DingDong receives the notification:

   ```json
   {"summary":"DingDong task-completion hook is connected"}
   ```

2. Confirm `dingdong_notify` appears in the current client's MCP tools and call
   it once with message `DingDong MCP is connected` and the current client name
   as `source`.
3. Report the installed version and path, the user-level Agent configuration
   files changed, whether the MCP server is available, whether the completion
   Hook is configured (and trusted for Codex), and whether both tests succeeded.
   On failure, preserve the previous configuration and return the original error
   instead of guessing.
4. Remove only the temporary download and mount created during this install.
   Never remove DingDong user data or unrelated Agent configuration.
