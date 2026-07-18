import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows taskbar integration guards failed COM initialization', () {
    final String source = File(
      'packages/window_manager/windows/window_manager.cpp',
    ).readAsStringSync();

    expect(
      source,
      contains(
        '::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)',
      ),
    );
    expect(source, contains('bool WindowManager::EnsureTaskbarInitialized()'));
    expect(
      RegExp(r'if \(!EnsureTaskbarInitialized\(\)\) \{')
          .allMatches(source),
      hasLength(3),
    );
    expect(
      source,
      contains('const HRESULT taskbar_result = taskbar_->HrInit();'),
    );
    expect(source, contains('taskbar_->Release();'));
    expect(source, isNot(contains('CoInitialize(lp)')));
  });
}
