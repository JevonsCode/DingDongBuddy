---
name: DingDong
description: A dense, calm desktop workspace for local resource operations.
colors:
  primary: "#2F6F8F"
  primary-soft: "rgba(47, 111, 143, 0.10)"
  on-primary: "#FFFFFF"
  surface: "#FFFFFF"
  surface-dim: "#F7F7F5"
  surface-low: "#F4F4F2"
  surface-container: "#F1F1EF"
  surface-high: "#EDEDEB"
  surface-highest: "#E6E6E3"
  on-surface: "#37352F"
  on-surface-variant: "#6B6A67"
  outline: "#D0D0CC"
  outline-variant: "#E9E9E7"
  dark-primary: "#8CB9CF"
  dark-on-primary: "#10242D"
  dark-background: "#202C33"
  dark-surface: "#293840"
  dark-surface-soft: "#25333B"
  dark-field: "#31424C"
  dark-border: "#445761"
  dark-text-primary: "#EDF2F4"
  dark-text-secondary: "#ABB8BE"
  dark-text-tertiary: "#74848C"
  dark-accent-soft: "#243E4C"
  prompt-light: "#A97822"
  skill-light: "#4C63A1"
  mcp-light: "#2F7651"
  prompt-dark: "#D8A64A"
  skill-dark: "#91A8E8"
  mcp-dark: "#8BB29E"
typography:
  headline:
    fontFamily: ".AppleSystemUIFont, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "22px"
    fontWeight: 600
  title:
    fontFamily: ".AppleSystemUIFont, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "17px"
    fontWeight: 600
  body:
    fontFamily: ".AppleSystemUIFont, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "13px"
    fontWeight: 400
  label:
    fontFamily: ".AppleSystemUIFont, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "12px"
    fontWeight: 600
  metadata:
    fontFamily: ".AppleSystemUIFont, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "11px"
    fontWeight: 400
  column-label:
    fontFamily: ".AppleSystemUIFont, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif"
    fontSize: "10px"
    fontWeight: 600
    letterSpacing: "0.15px"
rounded:
  navigation: "6px"
  control: "7px"
  field: "8px"
  dialog: "14px"
spacing:
  compact: "6px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  dialog: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 11px"
    height: "34px"
  button-primary-compact:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 9px"
    height: "30px"
  button-neutral:
    backgroundColor: "{colors.surface-high}"
    textColor: "{colors.on-surface}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0 11px"
    height: "34px"
  search-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    rounded: "{rounded.control}"
    padding: "0 11px"
    height: "36px"
  choice-selected:
    backgroundColor: "{colors.primary-soft}"
    textColor: "{colors.primary}"
    typography: "{typography.metadata}"
    rounded: "{rounded.navigation}"
    padding: "0 10px"
    height: "30px"
  navigation-sidebar:
    backgroundColor: "{colors.surface-dim}"
    textColor: "{colors.on-surface-variant}"
    width: "176px"
  resource-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    height: "58px"
  dialog:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.dialog}"
---

# Design System: DingDong

## Overview

**Creative North Star: "The Quiet Workbench"**

DingDong is a dense, calm desktop workspace for focused local resource operations. Its interface stays out of the way so people can scan real resources, understand state, and act quickly. Quiet navigation, compact tools, stable columns, and complete editing flows make the product feel native to sustained desktop work rather than like a generic administration dashboard.

The visual world is matte and restrained. Warm light neutrals and deep blue-gray dark surfaces carry most of the screen; DingDong blue marks interaction, while Prompt, Skill, and MCP hues identify resource meaning. Linear is a craft benchmark for calm density, continuous lists, restrained boundaries, and keyboard speed, but DingDong does not copy its brand, palette, assets, or product structure.

The primary story is stable across the system: filter a continuous list, select items for bulk work, then open one item in a complete page-like editor. Detail is not a persistent inspector; it replaces the list inside the window, preserves complete information and complex editing controls, and provides an obvious route back.

**Key Characteristics:**

- Calm desktop density with compact, predictable control footprints.
- Continuous, border-separated lists instead of card grids.
- Flat tonal layering, with elevation reserved for true overlays.
- Platform-native typography and keyboard-visible rectangular states.
- Semantic resource color used for identity, never decoration.
- Full-page, information-complete editing for complex resources.

## Colors

The palette is a restrained neutral workspace with one low-saturation blue interaction voice and three resource-type accents.

### Primary

- **Workbench Blue:** The primary interaction color for selected controls, focus borders, enabled state, and primary actions. Its soft alpha tint supports selection without turning rows or navigation into pills.
- **Night Workbench Blue:** The dark-mode interaction counterpart, bright enough to remain legible on blue-gray surfaces without glowing.

### Secondary

- **Prompt Amber:** Identifies Prompt resources in light and dark modes.
- **Skill Indigo:** Identifies Skill resources in light and dark modes.
- **MCP Green:** The single canonical MCP identity hue, with a lightened dark-mode counterpart.

These accents belong to icons, compact identity tiles, and semantic badges. They do not color large structural surfaces.

### Neutral

- **Paper Surface:** The main light work surface and field canvas.
- **Warm Workspace Layers:** The dim, low, container, high, and highest neutral steps separate navigation, controls, headers, and selected regions without shadows.
- **Graphite Text:** The primary light-mode reading color.
- **Quiet Graphite:** Secondary copy, metadata, inactive navigation, and subdued iconography.
- **Soft Rules:** Outline and outline-variant roles draw one-pixel boundaries and continuous row separators.
- **Blue-Gray Night:** Dark background, surface, soft surface, and field roles form a clear tonal ladder.
- **Frost Text:** Primary, secondary, and tertiary dark-mode text roles preserve hierarchy without pure-white glare.

### Named Rules

**The One Interaction Voice Rule.** Workbench Blue owns interaction; semantic Prompt, Skill, and MCP colors identify content type and do not compete for primary-action status.

**The Tonal Ladder Rule.** Separate adjacent work areas with the next established surface tone or a one-pixel rule before introducing shadow.

## Typography

**Display Font:** Platform-native UI sans serif (`.AppleSystemUIFont` on macOS, `Segoe UI` on Windows)

**Body Font:** Platform-native UI sans serif (`.AppleSystemUIFont` on macOS, `Segoe UI` on Windows)

**Character:** Native, compact, and workmanlike. Hierarchy comes primarily from weight and neutral contrast, with small size steps that keep dense information stable.

### Hierarchy

- **Headline** (semibold, 22px): Rare top-level emphasis in a desktop panel.
- **Title** (semibold, 17px): Workspace titles and substantial dialog titles.
- **Body** (regular, 13px): Row titles, input text, navigation labels, and primary explanatory copy.
- **Label** (semibold, 12px): Buttons and compact control emphasis.
- **Metadata** (regular, 11px): Summaries, counts, dates, secondary cell content, and tooltips.
- **Column Label** (semibold, 10px, 0.15px tracking): Stable list headers and compact organizational labels.

Use 16–18px dialog titles according to alert, chooser, or editor density. Visible status and body text stays at least 10px; smaller badge text is allowed only when its parent control exposes a complete accessible label.

### Named Rules

**The Small-Step Rule.** Prefer weight and contrast changes before a large size jump; DingDong is a tool for scanning, not a poster.

**The Native Voice Rule.** Keep San Francisco on macOS and Segoe UI on Windows; do not introduce a web display face into operational UI.

## Layout

The desktop shell uses a quiet fixed navigation sidebar (176px) beside a flexible primary pane. The sidebar starts with product identity and a compact workspace group, uses 34px rectangular navigation rows, and keeps local-storage context visually secondary. The primary pane owns the workspace title, view-level actions, one search/filter region, and the content it controls.

Resources render as a continuous list: a 34px column header followed by 58px rows with a stable type column, a flexible resource column, and optional scope, source, status, and updated columns. As width decreases, optional columns fall away in job order rather than compressing the primary resource text into illegibility. The resource toolbar collapses its individual actions below 520px; search and filters stack below 680px. List columns progressively appear at 560px, 650px, 760px, and 860px according to their importance.

Selection does not reflow the list. A compact bulk-action bar pins 12px above the bottom edge with 16px side insets, while the list reserves the needed scroll padding. Opening or creating a resource replaces the list with a dedicated in-window editor page: a 56px breadcrumb/back header, complete scrollable fields, and stable editor actions. Returning restores the list context.

Use the established 6/8/12/16/20/24px spacing rhythm. Smaller windows reflow tools and remove secondary columns; they do not hide the primary job or convert the workspace into cards. Fixture dimensions such as 1080, 620, or 304 are evidence sizes, not global layout tokens.

### Named Rules

**The Continuous Scan Rule.** Repeated resources share one uninterrupted list plane and aligned columns; never wrap each row in its own card.

**The Complete Detail Rule.** Complex resource detail is a full page-like editor with an explicit back path, never a permanently narrow inspector.

## Elevation & Depth

The system is flat by default. Surface tones and quiet one-pixel boundaries create hierarchy across navigation, toolbars, lists, fields, and selection. Cards have zero elevation, and the desktop panel removes Material surface tint.

True interruption layers are the exception. Dialogs use a soft structural shadow at Flutter elevation 10 with 18% shadow alpha and a 36% scrim; popup menus and floating snackbars use restrained low elevation. Nothing glows, blurs decoratively, or lifts on ordinary hover.

### Shadow Vocabulary

- **Dialog Separation** (`elevation: 10; shadow-color: 18% theme shadow`): Separates modal decisions and editors from the inactive workspace.
- **Floating Utility** (`elevation: 2`): Used by popup menus and floating snackbars only.

### Named Rules

**The Flat-by-Default Rule.** A surface is flat at rest; only a true overlay receives shadow.

## Shapes

DingDong uses compact rounded rectangles with visibly controlled corners. Navigation and tiny state containers use the tightest 6px step, shared buttons and focused controls use 7px, standard fields and grouped controls use 8px, and dialogs use 14px. The silhouette stays rectangular even when compact.

One-pixel borders are functional: they define fields, grouped actions, focus, selection, and modal structure. Continuous list rows do not gain individual radii. Circular geometry is reserved for intrinsically circular details such as switch thumbs and tiny status dots, not control hover surfaces.

### Named Rules

**The Rectangular State Rule.** Hover, pressed, selected, and keyboard focus remain bounded by the control or row rectangle; never use a Material circular halo.

## Components

### Buttons

Compact, confident, and flat.

- **Shape:** Gently rectangular controls (7px radius), 34px standard height or 30px compact height.
- **Primary:** Workbench Blue fill, on-primary text, 11px horizontal padding, and 12px semibold labeling.
- **Soft:** Blue-tinted fill and border for low-emphasis selected or supportive actions.
- **Neutral:** High neutral tonal fill, quiet outline, and primary text.
- **Danger:** Theme error fill with on-error text; use only for a confirmed destructive action.
- **Hover / Pressed:** Rectangular tonal blends increase from hover to pressed without movement, elevation, ink, or ripple.
- **Focus:** A 1.5px rectangular ring replaces the resting border. Primary and danger controls use their on-color for internal focus contrast; other tones use Workbench Blue.
- **Disabled:** Both foreground and background reduce contrast; the cursor returns to the basic pointer.

### Icon Buttons

Icon actions use a 32px square default footprint, 18px icon, and 7px corners. Selected actions receive a soft primary fill and border. Every icon-only action retains a tooltip and semantic label. Hover and focus are rectangular tonal changes, not circular Material overlays.

### Chips

Filter chips are flat rectangular selectors, not pills. The resource-type grammar is 30px high with 6px corners, 10px horizontal padding, an outlined resting state, and a soft-blue selected state. “All” follows the same grammar as every resource type. Keyboard focus strengthens the border to 1.5px.

### Inputs / Fields

Search is a single 36px compact field in the resource workspace, with a 7px corner, 13px body text, leading search icon, and an in-field clear action. Shared desktop fields use dense 11px horizontal and 10px vertical padding. Focus changes the border to Workbench Blue; it does not add glow or elevation. Multiline editor fields keep the same tonal and border grammar while expanding for complete content.

### Navigation

The sidebar is a quiet 176px support surface. Navigation rows are 34px high with 6px corners, 9px horizontal padding, 16px icons, and 13px labels. The active row uses a very soft blue rectangular fill, blue icon, stronger text weight, and no pill indicator. Hover uses a quieter neutral fill; focus adds a bounded border.

### Resource List

Rows form a continuous 58px table-like list. Each row aligns selection, a compact type identity, title and single-line summary, optional metadata columns, status, and a trailing pin. Quiet separators preserve scanning; selected rows receive a subtle primary wash, hover/focus receive a neutral wash, and keyboard focus outlines the complete row rectangle. Bulk actions appear only when at least one row is selected.

### Full-Page Resource Editor

Clicking a resource or creating one replaces the list with a complete editor page inside the same window. The 56px header carries an explicit back action and breadcrumb. The page exposes all required fields and complex editing controls in a scrollable work area, protects dirty changes before navigation, and keeps its actions stable. Do not reduce this flow to a side inspector or partial preview.

### Dialogs, Disclosure, and Switches

Dialogs share 14px corners and three real density modes: alert (16px title, 34px actions), chooser (17px title, 34px actions), and editor (18px title, 36px actions). Header, body, and footer padding expand from 20px to 24px as the job becomes more complex. Actions align right unless a deliberate filled-action layout is required.

Disclosure headers are 38px high with a 6px rectangular hover/focus surface and a 160ms arrow/content transition. Compact switches use a fixed 36×20px track with a 12px thumb and a 140ms functional transition; their tap semantics include the entire labelled row where present.

Clipboard category rules are a management-window job. The compact clipboard popup may expose category chips for filtering, but its management affordance opens the dedicated Resource Manager clipboard workspace and presents the ordered-rule editor there. Never stack the complex rule editor over the compact popup. Within the management dialog, hierarchy comes from spacing and quiet tonal grouping; avoid repeated header, toolbar, row, and footer dividers.

## Do's and Don'ts

### Do:

- **Do** keep the main resource view a continuous, 58px-row list with stable columns and quiet separators.
- **Do** use the 176px sidebar as subdued support for the primary work surface.
- **Do** use Workbench Blue for interaction and Prompt Amber, Skill Indigo, and MCP Green only for semantic resource identity.
- **Do** preserve explicit rectangular hover, pressed, selected, disabled, and keyboard-focus states.
- **Do** open resource detail as a complete in-window page with a clear back path and full complex-editing capability.
- **Do** deep-link clipboard category management from the compact popup into the Resource Manager clipboard workspace.
- **Do** preserve real repository data, bilingual expansion, platform-native typography, semantic labels, and light/dark hierarchy.

### Don't:

- **Don't** turn resources, settings, or navigation into a decorative card grid or pill cloud.
- **Don't** use Material circular hover, ink, ripple, or overlay halos; deliberate rectangular feedback is the system.
- **Don't** add gradients, glassmorphism, glow, decorative blur, or shadow to resting workspace surfaces.
- **Don't** copy Linear's brand, palette, assets, exact layout, or product structure; use it only as a craft benchmark.
- **Don't** hide complete resource editing inside a narrow persistent inspector.
- **Don't** open the clipboard category-rule editor inside the compact popup.
- **Don't** promote screenshot or fixture dimensions into global tokens.
