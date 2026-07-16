import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';

abstract interface class ClipboardCategoryRuleStore {
  List<ClipboardCategoryRule> load();

  void save(List<ClipboardCategoryRule> rules);
}

final class FileClipboardCategoryRuleStore
    implements ClipboardCategoryRuleStore {
  FileClipboardCategoryRuleStore(this.file);

  final File file;

  @override
  List<ClipboardCategoryRule> load() {
    if (!file.existsSync()) {
      return ClipboardCategoryRule.defaults();
    }
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?> ||
          decoded['version'] != 1 ||
          decoded['rules'] is! List<Object?>) {
        return ClipboardCategoryRule.defaults();
      }
      return List<ClipboardCategoryRule>.unmodifiable(
        (decoded['rules']! as List<Object?>).map(
          (Object? value) => ClipboardCategoryRule.fromJson(
            Map<String, Object?>.from(value! as Map),
          ),
        ),
      );
    } on Object {
      return ClipboardCategoryRule.defaults();
    }
  }

  @override
  void save(List<ClipboardCategoryRule> rules) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'rules': rules
            .map((ClipboardCategoryRule rule) => rule.toJson())
            .toList(growable: false),
      }),
      flush: true,
    );
  }
}

final class InMemoryClipboardCategoryRuleStore
    implements ClipboardCategoryRuleStore {
  InMemoryClipboardCategoryRuleStore([List<ClipboardCategoryRule>? initial])
    : _rules = List<ClipboardCategoryRule>.of(
        initial ?? ClipboardCategoryRule.defaults(),
      );

  List<ClipboardCategoryRule> _rules;

  @override
  List<ClipboardCategoryRule> load() =>
      List<ClipboardCategoryRule>.unmodifiable(_rules);

  @override
  void save(List<ClipboardCategoryRule> rules) {
    _rules = List<ClipboardCategoryRule>.of(rules);
  }
}
