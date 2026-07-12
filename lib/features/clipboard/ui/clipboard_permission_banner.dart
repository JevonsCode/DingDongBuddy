part of 'clipboard_screen.dart';

class _ClipboardPermissionBanner extends StatelessWidget {
  const _ClipboardPermissionBanner({required this.viewModel});

  final ClipboardSettingsController viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (BuildContext context, Widget? child) {
        if (viewModel.quickPastePermissionGranted != false) {
          return const SizedBox.shrink();
        }
        return Container(
          key: const Key('clipboard-permission-banner'),
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5DF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE7C77E)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: Color(0xFF8A6420),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.localized(
                    'Quick paste needs Accessibility permission.',
                    '快捷粘贴需要辅助功能权限。',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF76571F),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const Key('clipboard-open-permission-settings'),
                onPressed: viewModel.openQuickPastePermissionSettings,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF725214),
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.localized('Open settings', '前往开启'),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
