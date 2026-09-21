final jevMcpTools = <Map<String, Object?>>[
  {
    'name': 'dingdong_jev_status',
    'title': 'Jev Usage',
    'description':
        'Read local Jev setup and independent token usage. No network call or charge. Configure or uninstall Jev in DingDong Settings. Usage covers this device plugin only; estimates are not bills.',
    'inputSchema': {'type': 'object', 'properties': <String, Object?>{}},
    'annotations': {'readOnlyHint': true, 'openWorldHint': false},
  },
  for (final entry in {
    'check': 'yes/no probability',
    'choose': 'choice',
    'score': 'ordered score',
  }.entries)
    {
      'name': 'dingdong_jev_${entry.key}',
      'title': 'Jev ${entry.value}',
      'description':
          'Ask Jev for a narrow ${entry.value}. Sends supplied text to TypeSafe and incurs input-token charges after user opt-in. No retries. Omit secrets and unrelated private data. Judgments are advisory, never authorization. Returned usage is independently attributed to Jev.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'state': {'type': 'string', 'minLength': 1, 'maxLength': 20000},
          'instructions': {'type': 'string', 'minLength': 1, 'maxLength': 2000},
          'source': {'type': 'string', 'maxLength': 200},
          'conversationId': {'type': 'string', 'maxLength': 200},
          if (entry.key == 'choose')
            'criteria': {
              'type': 'object',
              'minProperties': 2,
              'maxProperties': 255,
              'additionalProperties': {
                'type': ['string', 'null'],
                'maxLength': 1000,
              },
            },
          if (entry.key == 'score')
            'criteria': {
              'type': 'array',
              'minItems': 2,
              'maxItems': 10,
              'items': {'type': 'string', 'minLength': 1, 'maxLength': 1000},
            },
        },
        'required': [
          'state',
          'instructions',
          if (entry.key != 'check') 'criteria',
        ],
      },
      'annotations': {
        'readOnlyHint': true,
        'openWorldHint': true,
        'idempotentHint': false,
      },
    },
];
