import 'package:dingdong/features/device_link/domain/device_link_models.dart';

const String clipboardDeviceOriginPrefix = 'device-origin:';
const String clipboardComputerOriginTag = 'device-origin-computer';

typedef ClipboardDeviceOrigin = ({String id, String label, bool isComputer});
typedef ClipboardDeviceProfile = ({String label, bool isComputer});

ClipboardDeviceOrigin? clipboardDeviceOrigin(
  List<String> tags,
  List<String> sources,
) {
  for (final tag in tags) {
    if (tag.startsWith(clipboardDeviceOriginPrefix) &&
        tag.length > clipboardDeviceOriginPrefix.length) {
      return (
        id: tag.substring(clipboardDeviceOriginPrefix.length),
        label: sources.firstOrNull ?? '',
        isComputer: tags.contains(clipboardComputerOriginTag),
      );
    }
  }
  return null;
}

Map<String, ClipboardDeviceProfile> clipboardDeviceProfiles(
  Iterable<LinkedDevice> devices,
) => {
  for (final device in devices)
    device.id: (
      label: device.remark.trim().isNotEmpty ? device.remark : device.name,
      isComputer: device.kind == LinkedDeviceKind.computer,
    ),
};

List<String> clipboardDeviceOriginTags(LinkedDevice device) => [
  '$clipboardDeviceOriginPrefix${device.id}',
  if (device.kind == LinkedDeviceKind.computer) clipboardComputerOriginTag,
];
