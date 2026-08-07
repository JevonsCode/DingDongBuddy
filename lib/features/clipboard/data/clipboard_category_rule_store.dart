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
      final List<ClipboardCategoryRule> rules =
          (decoded['rules']! as List<Object?>)
              .map(
                (Object? value) => ClipboardCategoryRule.fromJson(
                  Map<String, Object?>.from(value! as Map),
                ),
              )
              .toList(growable: false);
      // An empty persisted rule set is an incomplete configuration rather
      // than a useful clipboard filter state. Keep the built-in categories
      // available after an old migration or a damaged local write.
      return rules.isEmpty
          ? ClipboardCategoryRule.defaults()
          : List<ClipboardCategoryRule>.unmodifiable(rules);
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
