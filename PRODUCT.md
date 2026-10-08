# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

DingDong serves desktop users who combine content work with local AI Agents. They need to organize and reuse copied text, images, and files, keep Agent resources consistent across clients, and review events from connected Agents without losing track of work that needs attention.

## Product Purpose

DingDong is a free, open-source desktop companion for managing reusable clipboard content and Prompt, Skill, and MCP resources in one place. It collects events from connected Agents in a local inbox, lets users choose their notification preferences, and moves selected content or reminders between trusted devices. Local Token history helps users see supported Agent usage over time. Success means less repeated setup, easier content reuse, and fewer missed Agent handoffs.

## Positioning

DingDong combines local clipboard content management, shared cross-Agent resources, a connected-Agent inbox, and trusted-device delivery in one companion. Codex already provides completion notifications; DingDong adds a place to review connected events and choose a consistent sound and notification preference. It does not automatically replace every client's notifications. Resource scope matches the current task and Agent, clipboard and resource data remain local by default, and device content is transferred end-to-end encrypted.

## Operating Context

- The primary desktop application runs on macOS and Windows and adapts to each platform's native conventions.
- Users move among Agent activity, the resource library, clipboard history, resource management, settings, and trusted-device connection flows.
- DingDong integrates with local Agent clients including Codex, Claude Code, Cursor, Gemini CLI, and Kiro through native configuration, MCP, and completion hooks.
- A companion mobile web app receives explicitly shared clipboard content and Agent reminders from paired computers.

## Capabilities and Constraints

- Clipboard content management supports search, classification, groups, matching rules, pinning, previews, system opening, copy, paste, share, QR, and trusted-device delivery for text, links, images, files, paths, and commands. Copied file and image records may reference local source paths; capturing a record does not promise a permanent copy of the source file.
- Prompt, Skill, and MCP resources are maintained once, scoped by global, project, repository, and Agent context, then synchronized or surfaced to compatible clients.
- Agent activity records completed, blocked, and decision-needed work with unread state and configurable notification sound.
- The 1.7.0 development version adds local daily Token history and a heatmap in Resource Manager for supported Codex, Claude Code, and Pi sources. Users can filter by year and source and inspect a day. Only numeric usage aggregates are stored for this history, not conversation text. Missing evidence is unknown, partial totals are lower bounds, and Token counts are not monetary costs.
- Clipboard, resource, settings, and Agent activity data remain local by default; the loopback API listens only on localhost.
- Clipboard monitoring and Agent access to clipboard content are off by default. Anonymous installation and upgrade statistics are enabled by default and can be turned off in Settings; they are separate from local Token history.
- Trusted-device transfer uses direct WebRTC when possible and an end-to-end encrypted relay when necessary. The relay does not retain clipboard or file bodies.
- Existing product behavior, data flow, user-facing terminology, and truthful copy must be preserved during visual redesigns unless explicitly changed.

## Brand Commitments

- The product name is DingDong.
- DingDong is a free public open-source project intended to help people use local Agents. Product copy must not imply paid plans, subscriptions, or a charging roadmap. Optional external model services and plugins may have their own terms.
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
