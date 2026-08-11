const String dingDongConversationFooterResourceUri =
    'ui://dingdong/conversation-footer/v1.html';

const String dingDongConversationFooterResourceMimeType =
    'text/html;profile=mcp-app';

const String dingDongConversationFooterRenderToolName =
    'dingdong_render_conversation_footer';

const int _maximumConversationFooterItems = 24;
const int _maximumConversationFooterLabelCharacters = 32;
const int _maximumConversationFooterTitleCharacters = 64;
const int _maximumConversationFooterMergeKeyCharacters = 160;

const Map<String, Map<String, String>> dingDongConversationFooterPalette =
    <String, Map<String, String>>{
      'prompt': <String, String>{'light': '#A97822', 'dark': '#D8A64A'},
      'skill': <String, String>{'light': '#4C63A1', 'dark': '#91A8E8'},
      'mcp': <String, String>{'light': '#2F7651', 'dark': '#8BB29E'},
    };

/// Builds every supported presentation from one canonical footer capsule.
///
/// Rich hosts can pass [capsule] to [dingDongConversationFooterRenderToolName].
/// Terminal hosts may use the ANSI line only after confirming ANSI support,
/// while every other host can safely use the Markdown line.
Map<String, Object?> buildDingDongConversationFooter({
  required Iterable<Map<String, Object?>> items,
  String label = 'DingDong',
}) {
  final String normalizedLabel = _boundedFooterText(
    label,
    maximumCharacters: _maximumConversationFooterLabelCharacters,
    fallback: 'DingDong',
  );
  final List<Map<String, Object?>> normalizedItems = items
      .take(_maximumConversationFooterItems)
      .map(normalizeDingDongConversationFooterItem)
      .whereType<Map<String, Object?>>()
      .toList(growable: false);
  final List<String> titles = normalizedItems
      .map((Map<String, Object?> item) => item['title']! as String)
      .toList(growable: false);
  final String markdownLine = normalizedItems.isEmpty
      ? ''
      : '${_markdownSafeFooterText(normalizedLabel)} · ${normalizedItems.map((Map<String, Object?> item) => item['lineToken']! as String).join(' | ')}';
  final String ansiLine = normalizedItems.isEmpty
      ? ''
      : '\u001B[2m$normalizedLabel\u001B[0m · ${normalizedItems.map(_ansiFooterToken).join(' | ')}';
  final Map<String, Object?> capsule = <String, Object?>{
    'label': normalizedLabel,
    'items': normalizedItems,
    'palette': dingDongConversationFooterPalette,
    'confirmedSkillUseMarker': '*',
    'titles': titles,
    'visible': normalizedItems.isNotEmpty,
  };

  return <String, Object?>{
    'capsule': capsule,
    'presentations': <String, Object?>{
      'rich': const <String, Object?>{
        'protocol': 'mcp-apps',
        'resourceUri': dingDongConversationFooterResourceUri,
        'renderTool': dingDongConversationFooterRenderToolName,
        'requiresCapability': 'mcp-apps',
      },
      'ansi': <String, Object?>{
        'format': 'ansi-256',
        'line': ansiLine,
        'requiresCapability': 'ansi-color',
      },
      'markdown': <String, Object?>{'format': 'markdown', 'line': markdownLine},
    },
    'ansiLine': ansiLine,
    'line': markdownLine,
    'titles': titles,
  };
}

/// Removes presentation-controlled fields and recomputes truthful markers.
///
/// A Skill receives `*` only when the item carries the complete evidence shape
/// returned by a successful `dingdong_load_skill` call.
Map<String, Object?>? normalizeDingDongConversationFooterItem(
  Map<String, Object?> item,
) {
  final String type = (item['type'] as String? ?? '').trim().toLowerCase();
  if (!dingDongConversationFooterPalette.containsKey(type)) {
    return null;
  }
  final String title = _boundedFooterText(
    item['title'] as String? ?? '',
    maximumCharacters: _maximumConversationFooterTitleCharacters,
  );
  if (title.isEmpty) {
    return null;
  }
  final bool skill = type == 'skill';
  final String mergeKey = _boundedFooterText(
    item['mergeKey'] as String? ?? '',
    maximumCharacters: _maximumConversationFooterMergeKeyCharacters,
  );
  final bool confirmedSkillUse =
      skill &&
      item['confirmedUse'] == true &&
      item['usage'] == 'loaded' &&
      item['marker'] == '*';
  final String usage = switch (type) {
    'prompt' => 'active',
    'skill' => confirmedSkillUse ? 'loaded' : 'candidate',
    'mcp' => 'available',
    _ => 'available',
  };
  final String marker = confirmedSkillUse ? '*' : '';
  return <String, Object?>{
    'title': title,
    'type': type,
    'tone': type,
    'usage': usage,
    if (mergeKey.isNotEmpty) 'mergeKey': mergeKey,
    if (skill) 'confirmedUse': confirmedSkillUse,
    if (skill) 'marker': marker,
    'lineToken':
        '${_markdownTypeIndicator(type)} ${_markdownSafeFooterText(title)}$marker',
  };
}

/// Accepts the final, merged capsule passed to the dedicated render tool.
Map<String, Object?> buildDingDongConversationFooterFromArguments(
  Map<String, Object?> arguments,
) {
  final Map<String, Object?> capsule = _stringKeyedMap(arguments['capsule']);
  if (capsule.isEmpty) {
    throw const FormatException('capsule is required');
  }
  final Object? rawItems = capsule['items'];
  if (rawItems is! List<Object?>) {
    throw const FormatException('capsule.items must be an array');
  }
  final List<Map<String, Object?>> items = rawItems
      .map(_stringKeyedMap)
      .where((Map<String, Object?> item) => item.isNotEmpty)
      .toList(growable: false);
  final Map<String, Object?> conversation = buildDingDongConversationFooter(
    label: capsule['label'] as String? ?? 'DingDong',
    items: items,
  );
  final Map<String, Object?> normalizedCapsule =
      conversation['capsule']! as Map<String, Object?>;
  if (normalizedCapsule['visible'] != true) {
    throw const FormatException('capsule.items has no displayable items');
  }
  return conversation;
}

String _ansiFooterToken(Map<String, Object?> item) {
  final String type = item['type']! as String;
  final String color = switch (type) {
    'prompt' => '178',
    'skill' => '69',
    'mcp' => '71',
    _ => '250',
  };
  final String marker = item['marker'] as String? ?? '';
  return '\u001B[38;5;${color}m${item['title']}$marker\u001B[0m';
}

String _markdownTypeIndicator(String type) => switch (type) {
  'prompt' => '🟠',
  'skill' => '🔵',
  'mcp' => '🟢',
  _ => '⚪',
};

String _boundedFooterText(
  String value, {
  required int maximumCharacters,
  String fallback = '',
}) {
  final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final String withoutControls = normalized
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '')
      .trim();
  if (withoutControls.isEmpty) {
    return fallback;
  }
  final List<int> characters = withoutControls.runes.toList(growable: false);
  if (characters.length <= maximumCharacters) {
    return withoutControls;
  }
  return '${String.fromCharCodes(characters.take(maximumCharacters))}...';
}

String _markdownSafeFooterText(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('*', r'\*')
    .replaceAll('_', r'\_')
    .replaceAll('[', r'\[')
    .replaceAll(']', r'\]')
    .replaceAll('|', r'\|');

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return <String, Object?>{};
  }
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in value.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}

/// Self-contained MCP Apps view. It has no network or external asset access.
/// All tool-provided values are inserted with textContent, never as HTML.
const String dingDongConversationFooterHtml = r'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root {
      color-scheme: light dark;
      --text: #414247;
      --muted: #777981;
      --prompt: #A97822;
      --prompt-bg: rgba(169, 120, 34, 0.10);
      --skill: #4C63A1;
      --skill-bg: rgba(76, 99, 161, 0.10);
      --mcp: #2F7651;
      --mcp-bg: rgba(47, 118, 81, 0.10);
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --text: #E4E5E8;
        --muted: #A4A6AD;
        --prompt: #D8A64A;
        --prompt-bg: rgba(216, 166, 74, 0.12);
        --skill: #91A8E8;
        --skill-bg: rgba(145, 168, 232, 0.12);
        --mcp: #8BB29E;
        --mcp-bg: rgba(139, 178, 158, 0.12);
      }
    }

    * { box-sizing: border-box; }

    html, body {
      margin: 0;
      min-height: 0;
      background: transparent;
    }

    body {
      color: var(--text);
      font: 500 12px/1.35 ui-sans-serif, -apple-system, BlinkMacSystemFont,
        "Segoe UI", sans-serif;
    }

    #footer {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 5px;
      padding: 2px 0;
    }

    #footer[hidden] { display: none; }

    .brand {
      color: var(--muted);
      font-weight: 650;
      letter-spacing: 0.01em;
    }

    .separator {
      color: var(--muted);
      opacity: 0.68;
      user-select: none;
    }

    .item {
      display: inline-flex;
      align-items: center;
      min-height: 22px;
      padding: 2px 7px;
      border: 1px solid currentColor;
      border-radius: 6px;
      white-space: nowrap;
    }

    .item[data-type="prompt"] { color: var(--prompt); background: var(--prompt-bg); }
    .item[data-type="skill"] { color: var(--skill); background: var(--skill-bg); }
    .item[data-type="mcp"] { color: var(--mcp); background: var(--mcp-bg); }
  </style>
</head>
<body>
  <div id="footer" role="status" aria-label="DingDong resources" hidden></div>
  <script>
    (() => {
      const footer = document.getElementById("footer");
      const allowedTypes = new Set(["prompt", "skill", "mcp"]);

      function render(value) {
        const conversation = value && typeof value === "object"
          ? (value.conversation || value)
          : {};
        const capsule = conversation && typeof conversation === "object"
          ? (conversation.capsule || conversation)
          : {};
        const label = typeof capsule.label === "string" && capsule.label.trim()
          ? capsule.label.trim()
          : "DingDong";
        const items = Array.isArray(capsule.items) ? capsule.items : [];
        footer.replaceChildren();

        const brand = document.createElement("span");
        brand.className = "brand";
        brand.textContent = label;
        footer.appendChild(brand);

        let rendered = 0;
        for (const item of items) {
          if (!item || typeof item !== "object") continue;
          const type = typeof item.type === "string" ? item.type : "";
          const title = typeof item.title === "string" ? item.title.trim() : "";
          if (!allowedTypes.has(type) || !title) continue;
          const confirmed = type === "skill" && item.confirmedUse === true
            && item.usage === "loaded" && item.marker === "*";

          const separator = document.createElement("span");
          separator.className = "separator";
          separator.setAttribute("aria-hidden", "true");
          separator.textContent = rendered === 0 ? "·" : "|";
          footer.appendChild(separator);

          const token = document.createElement("span");
          token.className = "item";
          token.dataset.type = type;
          token.textContent = title + (confirmed ? "*" : "");
          token.setAttribute(
            "aria-label",
            type + ": " + title + (confirmed ? ", loaded" : "")
          );
          footer.appendChild(token);
          rendered += 1;
        }

        footer.hidden = rendered === 0;
      }

      window.addEventListener("message", (event) => {
        if (event.source !== window.parent) return;
        const message = event.data;
        if (!message || message.jsonrpc !== "2.0") return;
        if (message.method === "ui/notifications/tool-result") {
          render(message.params && message.params.structuredContent);
        }
      }, { passive: true });

      if (window.openai && window.openai.toolOutput) {
        render(window.openai.toolOutput);
      }
    })();
  </script>
</body>
</html>''';
