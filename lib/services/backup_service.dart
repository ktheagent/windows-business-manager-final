import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_service.dart';

class BackupInspection {
  const BackupInspection({
    required this.path,
    required this.schemaVersion,
    required this.createdAt,
    required this.databaseSha256,
    required this.databaseSize,
    required this.envelopeSha256,
  });

  final String path;
  final int schemaVersion;
  final DateTime createdAt;
  final String databaseSha256;
  final int databaseSize;
  final String envelopeSha256;
}

class BackupService {
  const BackupService(this._databaseService);

  static const _format = 'airmonlink-business-manager-backup';
  static const _envelopeMagic = 'ABMENC1';
  static const _kdfIterations = 210000;

  final DatabaseService _databaseService;

  Future<String> createBackup({String? directoryPath}) async {
    await _databaseService.checkpoint();
    final databasePath = await _databaseService.databasePath;
    final backupDirectory = await _resolveBackupDirectory(directoryPath);
    final destination = p.join(
      backupDirectory.path,
      'airmonlink-business-manager-${_timestamp()}.db',
    );
    await File(databasePath).copy(destination);
    return destination;
  }

  Future<String> createEncryptedBackup({
    required String password,
    String destination = 'local',
    int? createdBy,
    String? directoryPath,
  }) async {
    if (password.length < 8) {
      throw ArgumentError(
        'Backup password must contain at least eight characters.',
      );
    }
    await _databaseService.checkpoint();
    final databasePath = await _databaseService.databasePath;
    final bytes = await File(databasePath).readAsBytes();
    final checksum = legacy_crypto.sha256.convert(bytes).toString();
    final createdAt = DateTime.now().toUtc();
    final manifest = <String, Object?>{
      'format': _format,
      'format_version': 1,
      'schema_version': DatabaseService.schemaVersion,
      'created_at': createdAt.toIso8601String(),
      'database_sha256': checksum,
      'database_size': bytes.length,
    };
    final payload = utf8.encode(
      jsonEncode({...manifest, 'database_bytes': base64Encode(bytes)}),
    );

    final salt = _randomBytes(16);
    final algorithm = AesGcm.with256bits();
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    final secretBox = await algorithm.encrypt(payload, secretKey: key);
    final envelope = utf8.encode(
      jsonEncode({
        'magic': _envelopeMagic,
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': _kdfIterations,
        'salt': base64Encode(salt),
        'nonce': base64Encode(secretBox.nonce),
        'cipher_text': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      }),
    );
    final backupDirectory = await _resolveBackupDirectory(directoryPath);
    final path = p.join(
      backupDirectory.path,
      'airmonlink-business-manager-${_timestamp()}.abmbackup',
    );
    await File(path).writeAsBytes(envelope, flush: true);

    final inspection = await inspectEncryptedBackup(
      backupPath: path,
      password: password,
    );
    if (inspection.databaseSha256 != checksum ||
        inspection.databaseSize != bytes.length) {
      await File(path).delete();
      throw StateError('New backup failed post-write verification.');
    }
    await _recordBackup(
      path: path,
      checksum: inspection.envelopeSha256,
      encrypted: true,
      destination: destination,
      status: 'completed',
      createdBy: createdBy,
      sizeBytes: envelope.length,
      verifiedAt: DateTime.now(),
      manifestJson: jsonEncode(manifest),
    );
    return path;
  }

  Future<BackupInspection> inspectEncryptedBackup({
    required String backupPath,
    required String password,
  }) async {
    final decoded = await _decodeEncryptedBackup(
      backupPath: backupPath,
      password: password,
    );
    return BackupInspection(
      path: backupPath,
      schemaVersion: decoded.schemaVersion,
      createdAt: decoded.createdAt,
      databaseSha256: decoded.databaseSha256,
      databaseSize: decoded.databaseBytes.length,
      envelopeSha256: decoded.envelopeSha256,
    );
  }

  Future<void> restoreEncryptedBackup({
    required String backupPath,
    required String password,
  }) async {
    final decoded = await _decodeEncryptedBackup(
      backupPath: backupPath,
      password: password,
    );
    if (decoded.schemaVersion > DatabaseService.schemaVersion) {
      throw StateError(
        'This backup requires a newer Airmonlink Business Manager version.',
      );
    }

    final databasePath = await _databaseService.databasePath;
    final databaseFile = File(databasePath);
    final restoreId = _timestamp();
    final safetyPath = '$databasePath.before-restore-$restoreId';
    final markerPath = '$databasePath.restore-in-progress';
    await _databaseService.checkpoint();
    await databaseFile.copy(safetyPath);
    await File(markerPath).writeAsString(
      jsonEncode({
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'backup_path': backupPath,
        'safety_path': safetyPath,
      }),
      flush: true,
    );
    await _databaseService.close();
    try {
      await _removeSidecars(databasePath);
      await databaseFile.writeAsBytes(decoded.databaseBytes, flush: true);
      final report = await _databaseService.integrityReport();
      if (report['integrity'] != 'ok' ||
          report['foreign_key_violations'] != 0) {
        throw StateError('Restored database failed integrity verification.');
      }
      final marker = File(markerPath);
      if (await marker.exists()) await marker.delete();
    } catch (_) {
      await _databaseService.close();
      final safetyFile = File(safetyPath);
      if (await safetyFile.exists()) await safetyFile.copy(databasePath);
      await _removeSidecars(databasePath);
      await _databaseService.database;
      final marker = File(markerPath);
      if (await marker.exists()) await marker.delete();
      rethrow;
    }
  }

  Future<bool> recoverInterruptedRestore() async {
    final databasePath = await _databaseService.databasePath;
    final marker = File('$databasePath.restore-in-progress');
    if (!await marker.exists()) return false;
    try {
      final data = jsonDecode(await marker.readAsString());
      if (data is! Map<String, dynamic>) return false;
      final safetyPath = data['safety_path']?.toString() ?? '';
      final safety = File(safetyPath);
      if (!await safety.exists()) return false;
      await _databaseService.close();
      await safety.copy(databasePath);
      await _removeSidecars(databasePath);
      final report = await _databaseService.integrityReport();
      if (report['integrity'] != 'ok' ||
          report['foreign_key_violations'] != 0) {
        throw StateError('Automatic restore recovery failed integrity checks.');
      }
      await marker.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> uploadWebDav({
    required String backupPath,
    required Uri endpoint,
    required String username,
    required String password,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (endpoint.scheme != 'https') {
      throw ArgumentError('WebDAV backups require an HTTPS endpoint.');
    }
    final file = File(backupPath);
    if (!await file.exists()) throw StateError('Backup file was not found.');
    final target = endpoint.replace(
      path:
          '${endpoint.path.endsWith('/') ? endpoint.path : '${endpoint.path}/'}'
          '${p.basename(backupPath)}',
    );
    final response = await http
        .put(
          target,
          headers: {
            HttpHeaders.authorizationHeader:
                'Basic ${base64Encode(utf8.encode('$username:$password'))}',
            HttpHeaders.contentTypeHeader: 'application/octet-stream',
          },
          body: await file.readAsBytes(),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Cloud backup failed with status ${response.statusCode}.',
      );
    }
  }

  Future<void> testWebDav({
    required Uri endpoint,
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (endpoint.scheme != 'https') {
      throw ArgumentError('WebDAV requires an HTTPS endpoint.');
    }
    final client = http.Client();
    try {
      final request = http.Request('PROPFIND', endpoint)
        ..headers.addAll({
          HttpHeaders.authorizationHeader:
              'Basic ${base64Encode(utf8.encode('$username:$password'))}',
          'Depth': '0',
        });
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException(
          'WebDAV connection test failed with status '
          '${response.statusCode}.',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<int> createSchedule({
    required int branchId,
    required int createdBy,
    required String scheduleType,
    required DateTime nextRunAt,
    String runTime = '02:00',
    int intervalCount = 1,
    int? weekday,
    int retentionCount = 10,
    int retentionDays = 90,
    String destination = 'local',
    String localFolder = '',
  }) async {
    if (!{'daily', 'weekly', 'custom'}.contains(scheduleType)) {
      throw ArgumentError('Unsupported backup schedule type.');
    }
    if (intervalCount < 1 || retentionCount < 1 || retentionDays < 1) {
      throw ArgumentError('Schedule and retention values must be positive.');
    }
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(runTime)) {
      throw ArgumentError('Backup time must use 24-hour HH:mm format.');
    }
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.insert('backup_schedules', {
      'branch_id': branchId,
      'schedule_type': scheduleType,
      'interval_count': intervalCount,
      'run_time': runTime,
      'weekday': weekday,
      'retention_count': retentionCount,
      'retention_days': retentionDays,
      'destination': destination,
      'local_folder': localFolder.trim(),
      'is_enabled': 1,
      'next_run_at': nextRunAt.toIso8601String(),
      'created_by': createdBy,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, Object?>>> listSchedules({
    required int branchId,
  }) async {
    final db = await _databaseService.database;
    return db.query(
      'backup_schedules',
      where: 'branch_id = ?',
      whereArgs: [branchId],
      orderBy: 'next_run_at, id',
    );
  }

  Future<void> setScheduleEnabled({
    required int scheduleId,
    required int branchId,
    required bool enabled,
  }) async {
    final db = await _databaseService.database;
    final updated = await db.update(
      'backup_schedules',
      {
        'is_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND branch_id = ?',
      whereArgs: [scheduleId, branchId],
    );
    if (updated != 1) throw StateError('Backup schedule was not found.');
  }

  Future<int> runDueSchedules({
    required String password,
    required int branchId,
    int? createdBy,
  }) async {
    final db = await _databaseService.database;
    final now = DateTime.now();
    final schedules = await db.query(
      'backup_schedules',
      where: 'branch_id = ? AND is_enabled = 1 AND next_run_at <= ?',
      whereArgs: [branchId, now.toIso8601String()],
      orderBy: 'next_run_at, id',
    );
    var completed = 0;
    for (final schedule in schedules) {
      final id = schedule['id'] as int;
      try {
        await createEncryptedBackup(
          password: password,
          destination: schedule['destination'] as String? ?? 'local',
          createdBy: createdBy,
          directoryPath:
              (schedule['local_folder'] as String? ?? '').trim().isEmpty
              ? null
              : schedule['local_folder'] as String,
        );
        await applyRetention(
          retentionCount: (schedule['retention_count'] as num? ?? 10).toInt(),
          retentionDays: (schedule['retention_days'] as num? ?? 90).toInt(),
          destination: schedule['destination'] as String? ?? 'local',
        );
        completed++;
        await db.update(
          'backup_schedules',
          {
            'last_run_at': now.toIso8601String(),
            'next_run_at': _nextScheduleRun(schedule, now).toIso8601String(),
            'last_status': 'completed',
            'last_error': '',
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (error) {
        await db.update(
          'backup_schedules',
          {
            'last_run_at': now.toIso8601String(),
            'next_run_at': _nextScheduleRun(schedule, now).toIso8601String(),
            'last_status': 'failed',
            'last_error': error.toString(),
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    return completed;
  }

  Future<void> applyRetention({
    required int retentionCount,
    required int retentionDays,
    String destination = 'local',
  }) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'backup_records',
      where: 'destination = ? AND status = ?',
      whereArgs: [destination, 'completed'],
      orderBy: 'created_at DESC, id DESC',
    );
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final created = DateTime.tryParse(row['created_at'] as String? ?? '');
      final expiredByCount = index >= retentionCount;
      final expiredByAge = created != null && created.isBefore(cutoff);
      if (!expiredByCount && !expiredByAge) continue;
      final path = row['path'] as String? ?? '';
      if (path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      await db.update(
        'backup_records',
        {'status': 'expired', 'error_message': ''},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<_DecodedBackup> _decodeEncryptedBackup({
    required String backupPath,
    required String password,
  }) async {
    final source = File(backupPath);
    if (!await source.exists()) throw StateError('Backup file was not found.');
    final envelopeBytes = await source.readAsBytes();
    final envelopeSha256 = legacy_crypto.sha256
        .convert(envelopeBytes)
        .toString();
    final envelope = jsonDecode(utf8.decode(envelopeBytes));
    if (envelope is! Map<String, dynamic> ||
        envelope['magic'] != _envelopeMagic) {
      throw StateError('This is not a supported Airmonlink backup.');
    }
    final iterations = (envelope['iterations'] as num?)?.toInt() ?? 0;
    if (iterations < 100000) {
      throw StateError('Backup key-derivation settings are unsafe.');
    }
    final salt = base64Decode(envelope['salt'] as String);
    final secretBox = SecretBox(
      base64Decode(envelope['cipher_text'] as String),
      nonce: base64Decode(envelope['nonce'] as String),
      mac: Mac(base64Decode(envelope['mac'] as String)),
    );
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    late final List<int> clearText;
    try {
      clearText = await AesGcm.with256bits().decrypt(secretBox, secretKey: key);
    } catch (_) {
      throw StateError('Backup password is incorrect or the file is damaged.');
    }
    final payload = jsonDecode(utf8.decode(clearText));
    if (payload is! Map<String, dynamic> || payload['format'] != _format) {
      throw StateError('Backup content is invalid.');
    }
    final databaseBytes = base64Decode(payload['database_bytes'] as String);
    final expected = payload['database_sha256'] as String;
    final actual = legacy_crypto.sha256.convert(databaseBytes).toString();
    if (actual != expected) {
      throw StateError('Backup integrity verification failed.');
    }
    final declaredSize =
        (payload['database_size'] as num?)?.toInt() ?? databaseBytes.length;
    if (declaredSize != databaseBytes.length) {
      throw StateError('Backup database size verification failed.');
    }
    return _DecodedBackup(
      databaseBytes: databaseBytes,
      databaseSha256: actual,
      envelopeSha256: envelopeSha256,
      schemaVersion: (payload['schema_version'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(payload['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Future<Directory> _resolveBackupDirectory(String? directoryPath) async {
    if (directoryPath != null && directoryPath.trim().isNotEmpty) {
      final directory = Directory(directoryPath.trim());
      await directory.create(recursive: true);
      return directory;
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Backups'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _recordBackup({
    required String path,
    required String checksum,
    required bool encrypted,
    required String destination,
    required String status,
    required int? createdBy,
    required int sizeBytes,
    DateTime? verifiedAt,
    String manifestJson = '',
    String errorMessage = '',
  }) async {
    final db = await _databaseService.database;
    await db.insert('backup_records', {
      'path': path,
      'checksum': checksum,
      'encrypted': encrypted ? 1 : 0,
      'destination': destination,
      'status': status,
      'size_bytes': sizeBytes,
      'created_by': createdBy,
      'created_at': DateTime.now().toIso8601String(),
      'verified_at': verifiedAt?.toIso8601String(),
      'manifest_json': manifestJson,
      'error_message': errorMessage,
    });
  }

  static DateTime _nextScheduleRun(
    Map<String, Object?> schedule,
    DateTime current,
  ) {
    final type = schedule['schedule_type'] as String? ?? 'daily';
    final interval = max(
      1,
      (schedule['interval_count'] as num? ?? 1).toInt(),
    ).toInt();
    final runTime = schedule['run_time'] as String? ?? '02:00';
    final timeParts = runTime.split(':');
    final hour = int.tryParse(timeParts.first) ?? 2;
    final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
    DateTime candidate;
    if (type == 'weekly') {
      candidate = current.add(Duration(days: 7 * interval));
    } else {
      candidate = current.add(Duration(days: interval));
    }
    return DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      hour,
      minute,
    );
  }

  static Future<void> _removeSidecars(String databasePath) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  static Uint8List _randomBytes(int count) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(count, (_) => random.nextInt(256)),
    );
  }

  static String _timestamp() => DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
}

class _DecodedBackup {
  const _DecodedBackup({
    required this.databaseBytes,
    required this.databaseSha256,
    required this.envelopeSha256,
    required this.schemaVersion,
    required this.createdAt,
  });

  final List<int> databaseBytes;
  final String databaseSha256;
  final String envelopeSha256;
  final int schemaVersion;
  final DateTime createdAt;
}
