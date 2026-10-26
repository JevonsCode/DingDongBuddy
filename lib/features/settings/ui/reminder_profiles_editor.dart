import 'dart:io';

import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/core/widgets/reminder_marker.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/settings/data/reminder_audio_importer.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/voice_catalog_dialog.dart';
import 'package:flutter/material.dart';

/// The same saved profiles are edited here and through the Agent API.
class ReminderProfilesEditor extends StatelessWidget {
  const ReminderProfilesEditor({
    required this.viewModel,
    required this.settings,
    this.soundFileGateway,
    this.soundPreviewGateway,
    super.key,
  });
  final SettingsViewModel viewModel;
  final AppSettings settings;
  final SoundFileGateway? soundFileGateway;
  final SoundPreviewGateway? soundPreviewGateway;

  @override
  Widget build(BuildContext context) {
    final profiles = settings.reminderProfiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.reminderProfiles,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            DesktopActionButton(
              key: const Key('add-reminder'),
              label: context.l10n.addReminder,
              onPressed: settings.notificationRules.profiles.length >= 32
                  ? null
                  : () => _edit(context, null),
              tone: DesktopActionTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: DesktopActionButton(
            key: const Key('open-voice-catalog'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => VoiceCatalogDialog(viewModel: viewModel),
            ),
            icon: const Icon(Icons.library_music_outlined, size: 18),
            label: Text(context.l10n.voiceCatalogTitle),
          ),
        ),
        ReorderableListView(
          key: const Key('reminder-order-list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) =>
              viewModel.reorderReminderProfile(profiles[oldIndex].id, newIndex),
          proxyDecorator: (child, index, animation) => Material(
            color: Theme.of(context).colorScheme.surface,
            child: child,
          ),
          children: [
            for (final (index, profile) in profiles.indexed)
              Padding(
                key: ValueKey('reminder-order-${profile.id}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Tooltip(
                      message: context.l10n.reorderReminder,
                      child: ReorderableDragStartListener(
                        key: Key('drag-reminder-${profile.id}'),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                          child: Icon(
                            Icons.drag_indicator,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    _profileDot(profile),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_profileName(context, profile)),
                          if (profile.temporary)
                            Text(
                              context.l10n.reminderTemporary,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Text(
                            profile.description.isEmpty
                                ? profile.id
                                : profile.description,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: _profileName(context, profile),
                      child: CompactSwitch(
                        key: Key('settings-notify-agent-${profile.id}'),
                        value: profile.enabled,
                        onChanged: (value) => viewModel.saveReminderProfile(
                          profile.copyWith(enabled: value),
                        ),
                      ),
                    ),
                    DesktopIconButton(
                      key: Key('edit-reminder-${profile.id}'),
                      tooltip: context.l10n.edit,
                      onPressed: () => _edit(context, profile),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    SizedBox(
                      width: 34,
                      child: profile.builtIn
                          ? null
                          : DesktopIconButton(
                              key: Key('delete-reminder-${profile.id}'),
                              tooltip: context.l10n.delete,
                              onPressed: () =>
                                  viewModel.deleteReminderProfile(profile.id),
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        CompactSwitchListTile(
          key: const Key('settings-notify-codex-voice-activity'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.codexVoiceTaskNotifications),
          subtitle: Text(
            context
                .l10n
                .whenOffTasksStartedInCodexVoiceModeDoNotNotifyOrPlayA_75237958,
          ),
          value: settings.notifyCodexVoiceActivity,
          onChanged: viewModel.setNotifyCodexVoiceActivity,
        ),
        CompactSwitchListTile(
          key: const Key('settings-notify-subagent-activity'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.subagentNotifications),
          subtitle: Text(
            context
                .l10n
                .whenOffSubagentActivityShowsNoNotificationOrDingDong_ce161d98,
          ),
          value: settings.notifySubagentActivity,
          onChanged: viewModel.setNotifySubagentActivity,
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, ReminderProfile? existing) async {
    final profile = await showDialog<ReminderProfile>(
      context: context,
      builder: (_) => _ReminderDialog(
        profile: existing,
        viewModel: viewModel,
        previewGateway: soundPreviewGateway,
        onImport: soundFileGateway == null ? null : _import,
      ),
    );
    if (profile != null) await viewModel.saveReminderProfile(profile);
  }

  Future<void> _import(BuildContext context) async {
    final path = await soundFileGateway?.chooseSoundFile();
    if (path == null) return;
    try {
      final importer = ReminderAudioImporter(
        Directory(
          '${AppDataPaths.current().applicationSupportDirectory.path}/Reminder Sounds',
        ),
      );
      final name = path.split(Platform.pathSeparator).last;
      final audio = await importer.import(
        path,
        name.length > 64 ? name.substring(0, 64) : name,
      );
      final rules = viewModel.settings.notificationRules;
      await viewModel.setNotificationRules(
        rules.copyWith(
          audioLibrary: [
            ...rules.audioLibrary.where((x) => x.path != audio.path),
            audio,
          ],
        ),
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.reminderAudioImportFailed)),
        );
      }
    }
  }
}

class ReminderUsageDots extends StatelessWidget {
  const ReminderUsageDots({
    required this.profiles,
    required this.names,
    super.key,
  });
  final List<ReminderProfile> profiles;
  final List<String> names;
  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) return const SizedBox.shrink();
    final shown = profiles.take(5).toList();
    final step = profiles.length > 2 ? 10.0 : 19.0;
    return Tooltip(
      message: names.join(' · '),
      child: Semantics(
        label: names.join(', '),
        child: SizedBox(
          width:
              16 + step * (shown.length - 1) + (profiles.length > 5 ? 27 : 0),
          height: 20,
          child: Stack(
            children: [
              if (profiles.length > 5)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Text(
                    '+${profiles.length - 5}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              for (int i = 0; i < shown.length; i++)
                Positioned(
                  left: i * step,
                  top: 2,
                  child: _profileDot(shown[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _profileDot(ReminderProfile profile) => profile.temporary
    ? ReminderMarker(profile: profile, diameter: 16)
    : Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xff000000 | profile.color.rgbValue),
          border: Border.all(color: const Color(0xfffafafa), width: 1.5),
        ),
      );

String _profileName(BuildContext context, ReminderProfile profile) =>
    switch (profile.id) {
      'completion' => context.l10n.agentCompletionNotifications,
      'attention' => context.l10n.needsYourInput2,
      _ => profile.name,
    };

final class _Sound {
  const _Sound(this.key, this.label, [this.path]);
  final String key;
  final String label;
  final String? path;
}

List<_Sound> _sounds(BuildContext context, AppSettings settings) {
  final labels = [
    context.l10n.dingdongClassic,
    context.l10n.dingdongSoft,
    context.l10n.dingdongBright,
    context.l10n.dingdongCrisp,
    context.l10n.dingdongDeep,
    context.l10n.systemSound,
    context.l10n.muted,
  ];
  const keys = [
    'default',
    'dingSoft',
    'dingBright',
    'dingCrisp',
    'dingDeep',
    'system',
    'muted',
  ];
  final audio = {
    for (final item in settings.notificationRules.audioLibrary)
      item.path: item.name,
  };
  for (final profile in settings.reminderProfiles) {
    final path = profile.customSoundPath;
    if (path != null && profile.sound == 'custom') {
      audio.putIfAbsent(path, () => path.split(Platform.pathSeparator).last);
    }
  }
  return [
    for (int i = 0; i < keys.length; i++) _Sound(keys[i], labels[i]),
    for (final entry in audio.entries)
      _Sound(entry.key, entry.value, entry.key),
  ];
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({
    required this.profile,
    required this.viewModel,
    this.previewGateway,
    this.onImport,
  });
  final ReminderProfile? profile;
  final SettingsViewModel viewModel;
  final SoundPreviewGateway? previewGateway;
  final Future<void> Function(BuildContext)? onImport;
  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late ReminderProfile profile =
      widget.profile ??
      ReminderProfile(
        id: 'reminder-${DateTime.now().microsecondsSinceEpoch}',
        name: '',
      );
  late final name = TextEditingController(text: widget.profile?.name ?? '');
  late final description = TextEditingController(text: profile.description);
  bool invalidName = false;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    Widget field(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Semantics(label: label, child: child),
        ],
      ),
    );
    return DesktopAlertDialog(
      maxWidth: 480,
      title: Text(
        widget.profile == null
            ? strings.addReminder
            : _profileName(context, profile),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!profile.builtIn)
                CompactSwitchListTile(
                  key: const Key('reminder-temporary'),
                  title: Text(strings.reminderTemporary),
                  subtitle: Text(strings.reminderTemporaryHelp),
                  value: profile.temporary,
                  onChanged: (value) => setState(
                    () => profile = profile.copyWith(temporary: value),
                  ),
                ),
              if (!profile.builtIn)
                field(
                  strings.name,
                  DesktopTextField(
                    key: const Key('reminder-name'),
                    controller: name,
                    maxLength: 64,
                    decoration: InputDecoration(
                      errorText: invalidName
                          ? strings.reminderNameRequired
                          : null,
                    ),
                  ),
                ),
              SelectableText(
                'ID: ${profile.id}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!profile.builtIn)
                field(
                  strings.reminderCondition,
                  DesktopTextField(
                    key: const Key('reminder-condition'),
                    controller: description,
                    maxLength: 160,
                  ),
                ),
              if (!profile.builtIn)
                field(
                  strings.reminderKind,
                  DesktopSelectField<AgentNotificationKind>(
                    semanticLabel: strings.reminderKind,
                    value: profile.kind,
                    items: [
                      DesktopSelectItem(
                        value: AgentNotificationKind.completion,
                        label: strings.agentCompletionNotifications,
                      ),
                      DesktopSelectItem(
                        value: AgentNotificationKind.attention,
                        label: strings.needsYourInput2,
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => profile = profile.copyWith(kind: v)),
                  ),
                ),
              field(
                strings.reminderStyle,
                DesktopSelectField<TrayReminderStyle>(
                  semanticLabel: strings.reminderStyle,
                  value: profile.style,
                  items: [
                    DesktopSelectItem(
                      value: TrayReminderStyle.staticMarker,
                      label: strings.trayStyleStatic,
                    ),
                    DesktopSelectItem(
                      value: TrayReminderStyle.softPulse,
                      label: strings.trayStylePulse,
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => profile = profile.copyWith(style: v)),
                ),
              ),
              field(
                strings.reminderColor,
                Wrap(
                  spacing: 6,
                  children: [
                    for (final color in TrayNotificationColor.values)
                      DesktopIconButton(
                        key: Key('reminder-color-${color.name}'),
                        selected: profile.color == color,
                        tooltip: switch (color) {
                          TrayNotificationColor.orange => strings.orange,
                          TrayNotificationColor.pink => strings.pink,
                          TrayNotificationColor.blue => strings.blue,
                          TrayNotificationColor.green => strings.green,
                          TrayNotificationColor.purple => strings.purple,
                          TrayNotificationColor.amber => strings.amber,
                        },
                        onPressed: () => setState(
                          () => profile = profile.copyWith(color: color),
                        ),
                        icon: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Color(0xff000000 | color.rgbValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (profile.color == color)
                              const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              field(
                strings.sound,
                _ReminderSoundPicker(
                  key: const Key('reminder-sound'),
                  settings: widget.viewModel.settings,
                  value: profile.soundKey,
                  previewGateway: widget.previewGateway,
                  onImport: widget.onImport == null
                      ? null
                      : () async {
                          await widget.onImport!(context);
                          if (mounted) setState(() {});
                        },
                  onChanged: (sound) => setState(
                    () => profile = profile.copyWith(
                      sound: sound.path == null ? sound.key : 'custom',
                      customSoundPath: sound.path,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CompactSwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.reminderToPhone),
                value: profile.toPhone,
                onChanged: (v) =>
                    setState(() => profile = profile.copyWith(toPhone: v)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        DesktopActionButton(
          label: strings.cancel,
          tone: DesktopActionTone.neutral,
          onPressed: () => Navigator.pop(context),
        ),
        DesktopActionButton(
          key: const Key('save-reminder'),
          label: strings.save,
          onPressed: () {
            if (!profile.builtIn && name.text.trim().isEmpty) {
              setState(() => invalidName = true);
              return;
            }
            Navigator.pop(
              context,
              profile.copyWith(
                name: profile.builtIn ? profile.name : name.text.trim(),
                description: description.text.trim(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Sound choices stay next to the reminder being edited, including preview and reuse markers.
class _ReminderSoundPicker extends StatelessWidget {
  const _ReminderSoundPicker({
    required this.settings,
    required this.value,
    required this.onChanged,
    this.previewGateway,
    this.onImport,
    super.key,
  });
  final AppSettings settings;
  final String value;
  final ValueChanged<_Sound> onChanged;
  final SoundPreviewGateway? previewGateway;
  final Future<void> Function()? onImport;

  @override
  Widget build(BuildContext context) {
    final sounds = _sounds(context, settings);
    final selected = sounds.firstWhere(
      (s) => s.key == value,
      orElse: () => sounds.first,
    );
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return MenuAnchor(
          alignmentOffset: const Offset(0, 6),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(
              colors.surfaceContainerLowest,
            ),
            elevation: const WidgetStatePropertyAll(0),
            side: WidgetStatePropertyAll(
              BorderSide(color: colors.outlineVariant),
            ),
            minimumSize: WidgetStatePropertyAll(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll(Size(width, 380)),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          menuChildren: [
            SizedBox(
              width: width - 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        primary: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final sound in sounds)
                              Row(
                                children: [
                                  Expanded(
                                    child: MenuItemButton(
                                      key: Key('sound-option-${sound.key}'),
                                      onPressed: () => onChanged(sound),
                                      leadingIcon: SizedBox(
                                        width: 18,
                                        child: sound.key == value
                                            ? Icon(
                                                Icons.check,
                                                size: 16,
                                                color: colors.primary,
                                              )
                                            : null,
                                      ),
                                      style: MenuItemButton.styleFrom(
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                      ),
                                      child: Text(
                                        sound.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 34,
                                    child:
                                        sound.key == 'muted' ||
                                            previewGateway == null
                                        ? null
                                        : DesktopIconButton(
                                            key: Key(
                                              'preview-reminder-sound-${sound.key}',
                                            ),
                                            tooltip: context.l10n.previewSound,
                                            onPressed: () =>
                                                previewGateway!.preview(
                                                  sound: sound.path == null
                                                      ? sound.key
                                                      : 'custom',
                                                  customSoundPath: sound.path,
                                                ),
                                            icon: const Icon(
                                              Icons.volume_up_outlined,
                                              size: 17,
                                            ),
                                          ),
                                  ),
                                  SizedBox(
                                    width: 82,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: ReminderUsageDots(
                                        profiles: settings.reminderProfiles
                                            .where(
                                              (p) => p.soundKey == sound.key,
                                            )
                                            .toList(),
                                        names: settings.reminderProfiles
                                            .where(
                                              (p) => p.soundKey == sound.key,
                                            )
                                            .map(
                                              (p) => _profileName(context, p),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                  MenuItemButton(
                    key: const Key('import-reminder-sound'),
                    onPressed:
                        onImport == null ||
                            settings.notificationRules.audioLibrary.length >= 64
                        ? null
                        : onImport,
                    leadingIcon: const Icon(
                      Icons.file_upload_outlined,
                      size: 18,
                    ),
                    child: Text(context.l10n.importReminderSound),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.reminderAudioFormat,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          builder: (context, controller, child) => Semantics(
            label: context.l10n.sound,
            value: selected.label,
            expanded: controller.isOpen,
            button: true,
            child: DesktopActionButton(
              height: 38,
              tone: DesktopActionTone.neutral,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    controller.isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
