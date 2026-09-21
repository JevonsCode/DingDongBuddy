import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/features/jev/data/jev_service.dart';
import 'package:dingdong/features/jev/data/jev_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

JevService openJevService(AppDataPaths paths) {
  paths.applicationSupportDirectory.createSync(recursive: true);
  return JevService(
    JevStore(
      sqlite3.open(
        path.join(paths.applicationSupportDirectory.path, 'jev.sqlite'),
      ),
    ),
    SecureJevVault(
      paths.development ? 'dingdong.dev.jev.apiKey' : 'dingdong.jev.apiKey',
    ),
  );
}

final class SecureJevVault implements JevVault {
  const SecureJevVault(this.key);
  final String key;
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: key);
}
