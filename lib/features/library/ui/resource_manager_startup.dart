import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:flutter/material.dart';

/// Keeps the separate native window usable while its data is opening.
class ResourceManagerStartup extends StatefulWidget {
  const ResourceManagerStartup({required this.load, super.key});

  final Future<Widget> Function() load;

  @override
  State<ResourceManagerStartup> createState() => _ResourceManagerStartupState();
}

class _ResourceManagerStartupState extends State<ResourceManagerStartup> {
  late Future<Widget> _pending = Future<Widget>.sync(widget.load);

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _pending,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.requireData;
      final failed = snapshot.connectionState == ConnectionState.done;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.desktopPanelLight(),
        darkTheme: AppTheme.desktopPanelDark(),
        supportedLocales: DingDongLocalizations.supportedLocales,
        localizationsDelegates: DingDongLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!failed)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.error_outline_rounded, size: 24),
                  const SizedBox(height: 12),
                  Text(
                    failed
                        ? context.l10n.resourceManagerStartupFailed
                        : context.l10n.resourceManagerStarting,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (failed) ...[
                    const SizedBox(height: 12),
                    DesktopActionButton(
                      onPressed: () {
                        final pending = Future<Widget>.sync(widget.load);
                        setState(() {
                          _pending = pending;
                        });
                      },
                      label: context.l10n.resourceManagerRetry,
                      tone: DesktopActionTone.primary,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
