import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureConfigService {
  const SecureConfigService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> write(String key, String value) =>
      _storage.write(key: 'abm.$key', value: value);

  Future<String?> read(String key) => _storage.read(key: 'abm.$key');

  Future<void> delete(String key) => _storage.delete(key: 'abm.$key');

  Future<void> saveSmtpPassword(String password) =>
      write('smtp.password', password);
  Future<String?> smtpPassword() => read('smtp.password');

  Future<void> saveWebDavPassword(String password) =>
      write('webdav.password', password);
  Future<String?> webDavPassword() => read('webdav.password');

  Future<void> saveRemoteDashboardToken(String token) =>
      write('remote_dashboard.token', token);
  Future<String?> remoteDashboardToken() => read('remote_dashboard.token');

  Future<void> saveRemoteSyncEndpoint(String value) =>
      write('remote_sync.endpoint', value);
  Future<String?> remoteSyncEndpoint() => read('remote_sync.endpoint');

  Future<void> saveRemoteSyncBusinessId(String value) =>
      write('remote_sync.business_id', value);
  Future<String?> remoteSyncBusinessId() => read('remote_sync.business_id');

  Future<void> saveRemoteSyncToken(String value) =>
      write('remote_sync.token', value);
  Future<String?> remoteSyncToken() => read('remote_sync.token');

  Future<void> saveRemoteSyncDeviceId(String value) =>
      write('remote_sync.device_id', value);
  Future<String?> remoteSyncDeviceId() => read('remote_sync.device_id');

  Future<void> saveWhatsAppAccessToken(String token) =>
      write('whatsapp.access_token', token);
  Future<String?> whatsAppAccessToken() => read('whatsapp.access_token');

  Future<void> saveUpdateClientSecret(String secret) =>
      write('updates.client_secret', secret);
  Future<String?> updateClientSecret() => read('updates.client_secret');

  Future<void> clearIntegrationSecrets() async {
    for (final key in [
      'smtp.password',
      'webdav.password',
      'whatsapp.access_token',
      'updates.client_secret',
      'remote_sync.endpoint',
      'remote_sync.business_id',
      'remote_sync.token',
      'remote_sync.device_id',
    ]) {
      await delete(key);
    }
  }

  Future<void> saveBackupPassword(String password) =>
      write('backup.password', password);
  Future<String?> backupPassword() => read('backup.password');
}
