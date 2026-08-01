import 'package:dingdong/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app themes suppress native Material hover halos', () {
    final List<ThemeData> themes = <ThemeData>[
      AppTheme.light(),
      AppTheme.dark(),
      AppTheme.desktopPanelLight(),
      AppTheme.desktopPanelDark(),
    ];

    for (final ThemeData theme in themes) {
      expect(theme.hoverColor, Colors.transparent);
      expect(theme.splashColor, Colors.transparent);
      expect(theme.highlightColor, Colors.transparent);
      expect(theme.splashFactory, same(NoSplash.splashFactory));
      expect(
        theme.checkboxTheme.overlayColor?.resolve(<WidgetState>{
          WidgetState.hovered,
        }),
        Colors.transparent,
      );
      expect(
        theme.radioTheme.overlayColor?.resolve(<WidgetState>{
          WidgetState.hovered,
        }),
        Colors.transparent,
      );
      expect(
        theme.switchTheme.overlayColor?.resolve(<WidgetState>{
          WidgetState.hovered,
        }),
        Colors.transparent,
      );
      expect(
        theme.iconButtonTheme.style?.overlayColor?.resolve(<WidgetState>{
          WidgetState.hovered,
        }),
        Colors.transparent,
      );
    }
  });
}
