part of 'settings_screen.dart';

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          if (children.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const Divider(),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: child),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              const SizedBox(width: 24),
              child,
            ],
          );
        },
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.initialValue,
    required this.onSubmitted,
    super.key,
  });

  final int initialValue;
  final ValueChanged<int> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextFormField(
        initialValue: initialValue.toString(),
        textAlign: TextAlign.end,
        keyboardType: TextInputType.number,
        onFieldSubmitted: (String value) {
          final int? parsed = int.tryParse(value.trim());
          if (parsed != null) {
            onSubmitted(parsed);
          }
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
    );
  }
}
