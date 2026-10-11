import 'dart:convert';
import 'dart:io';

/// An actual local adapter prefix, never inferred from RFC1918 membership.
final class LanSubnet {
  LanSubnet(this.address, this.prefix);
  final InternetAddress address;
  final int prefix;
  bool contains(InternetAddress other) {
    final a = address.rawAddress;
    final b = other.rawAddress;
    if (a.length != 4 || b.length != 4 || prefix < 1 || prefix > 32) {
      return false;
    }
    final mask = (0xffffffff << (32 - prefix)) & 0xffffffff;
    int integer(List<int> bytes) => bytes.fold(0, (n, byte) => (n << 8) | byte);
    return (integer(a) & mask) == (integer(b) & mask);
  }
}

/// Read-only OS adapter metadata. Dart's NetworkInterface omits netmasks.
/// Only physical Windows adapters and macOS Ethernet/Wi-Fi interfaces qualify;
/// a VPN advertising an RFC1918 address does not become a LAN peer.
Future<List<LanSubnet>> readLanSubnets() async {
  if (Platform.isWindows) {
    final result = await _run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"Get-NetAdapter | Where-Object { $_.HardwareInterface -and $_.Status -eq 'Up' } | ForEach-Object { Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object IPAddress,PrefixLength } | ConvertTo-Json -Compress",
    ]);
    return parseWindowsLanSubnets(result);
  }
  if (Platform.isMacOS) {
    return parseMacLanSubnets(await _run('/sbin/ifconfig', ['-a']));
  }
  // Other desktop platforms fail closed until they have a verified adapter
  // inventory implementation; no fallback to private-address guessing.
  return [];
}

Future<String> _run(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments);
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.drain<void>();
  try {
    final result = await process.exitCode.timeout(const Duration(seconds: 6));
    await errors;
    if (result != 0) throw const SocketException('Cannot read LAN adapters');
    return await output;
  } finally {
    process.kill();
  }
}

List<LanSubnet> parseWindowsLanSubnets(String text) {
  if (text.trim().isEmpty) return [];
  final value = jsonDecode(text);
  final rows = value is List ? value : [value];
  final result = <LanSubnet>[];
  for (final row in rows.whereType<Map>()) {
    final address = InternetAddress.tryParse(row['IPAddress'] as String? ?? '');
    final prefix = row['PrefixLength'];
    if (address != null && prefix is int && prefix >= 1 && prefix <= 32) {
      result.add(LanSubnet(address, prefix));
    }
  }
  return result;
}

List<LanSubnet> parseMacLanSubnets(String text) {
  final result = <LanSubnet>[];
  var physical = false;
  for (final line in const LineSplitter().convert(text)) {
    if (line.isNotEmpty && !line.startsWith(RegExp(r'\s'))) {
      physical = RegExp(r'^en\d+:').hasMatch(line) && line.contains('UP');
    }
    if (!physical) continue;
    final match = RegExp(
      r'\binet (\d+\.\d+\.\d+\.\d+) netmask 0x([0-9a-fA-F]+)',
    ).firstMatch(line);
    if (match == null) continue;
    final mask = int.parse(
      match[2]!,
      radix: 16,
    ).toRadixString(2).padLeft(32, '0');
    if (!RegExp(r'^1+0*$').hasMatch(mask)) continue;
    result.add(
      LanSubnet(
        InternetAddress(match[1]!),
        !mask.contains('0') ? 32 : mask.indexOf('0'),
      ),
    );
  }
  return result;
}
