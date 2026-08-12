# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

DingDong serves desktop users who combine content work with local AI Agents. They need to retrieve and reuse clipboard material quickly, keep Agent resources consistent across clients, and notice when background Agent work finishes, stalls, or needs a decision.

## Product Purpose

DingDong is a desktop companion for managing clipboard history, Prompt, Skill, and MCP resources in one place. It also surfaces Agent activity and moves selected clipboard content or Agent reminders between the user's trusted computers and mobile devices. Success means less repeated setup, less lost context, and fewer missed Agent handoffs.

## Positioning

DingDong combines a local-first clipboard workspace, a single source of truth for cross-Agent resources, and trusted-device delivery in one companion. Resource scope is matched to the current task and Agent, while clipboard and resource data remain local by default and device content is transferred end-to-end encrypted.

## Operating Context

- The primary desktop application runs on macOS and Windows and adapts to each platform's native conventions.
- Users move among Agent activity, the resource library, clipboard history, resource management, settings, and trusted-device connection flows.
- DingDong integrates with local Agent clients including Codex, Claude Code, Cursor, Gemini CLI, and Kiro through native configuration, MCP, and completion hooks.
- A companion mobile web app receives explicitly shared clipboard content and Agent reminders from paired computers.

## Capabilities and Constraints

- Clipboard history supports search, categorization, previews, system opening, copy, share, QR, and trusted-device delivery for text, links, images, files, paths, and commands.
- Prompt, Skill, and MCP resources are maintained once, scoped by global, project, repository, and Agent context, then synchronized or surfaced to compatible clients.
- Agent activity records completed, blocked, and decision-needed work with unread state and configurable notification sound.
- Clipboard, resource, settings, and Agent activity data remain local by default; the loopback API listens only on localhost.
- Trusted-device transfer uses direct WebRTC when possible and an end-to-end encrypted relay when necessary. The relay does not retain clipboard or file bodies.
- Existing product behavior, data flow, user-facing terminology, and truthful copy must be preserved during visual redesigns unless explicitly changed.

## Brand Commitments

- The product name is DingDong.
- Existing DingDong character artwork, application icons, symbol assets, and notification sounds are authoritative brand assets under `Assets/`.
- The interface should feel like a focused desktop companion rather than a generic administration dashboard.
- Default Flutter Material circular hover, ink, ripple, and overlay halos are not part of the product. Deliberate rectangular hover surfaces, borders, tooltips, and keyboard focus indicators remain supported.
- The visual system follows the familiar modern desktop productivity-tool convention, with Linear as the craft benchmark for information density, quiet hierarchy, restrained boundaries, and keyboard-speed interaction. This is a quality and interaction reference, not permission to copy Linear's brand, palette, product structure, or proprietary assets.

## Evidence on Hand

- Product capabilities and privacy commitments: `README.zh.md` and `README.md`.
- Implemented runtime boundaries and data flows: `docs/architecture/ai-companion-architecture.md`.
- Existing brand and interface assets: `Assets/DingDongIP/`, `Assets/Symbols/`, and `Assets/Sounds/`.
- Current desktop behavior and visual regression fixtures: `lib/`, `test/golden/`, and `integration_test/`.
- No fabricated testimonials, customer claims, benchmarks, or usage statistics are available and none should be introduced.

## Product Principles

1. Keep frequent desktop actions fast, legible, and keyboard-friendly.
2. Preserve user control and privacy through local-first storage, explicit sharing, and transparent device state.
3. Maintain one trustworthy resource definition across multiple Agent clients without disturbing unrelated configuration.
4. Make background Agent state visible at the moment the user can act on it.
5. Use the real product model and real operational states; never disguise placeholders or demonstration data as live truth.

## Accessibility & Inclusion

- Core desktop workflows must remain keyboard-operable and expose explicit semantic labels for icon-only actions and compound status controls.
- Visible body and status copy should remain at least 10 px; smaller badges must be represented by a complete accessible label on their parent control.
- Quick Paste requests macOS Accessibility permission only when the user asks DingDong to paste back into the previous application; ordinary clipboard history does not require it.
- The macOS secondary-window accessibility bridge is implemented but still requires a recorded real-device VoiceOver validation pass.
