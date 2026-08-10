import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../services/database_service.dart';
import 'secure_config_service.dart';

class RemoteSyncService {
  RemoteSyncService({
    DatabaseService? database,
    SecureConfigService? config,
    http.Client? client,
  })  : _database = database ?? DatabaseService.instance,
        _config = config ?? const SecureConfigService(),
        _client = client ?? http.Client();

  final DatabaseService _database;
  final SecureConfigService _config;
  final http.Client _client;

  Future<void> ensureSchema() async {
    final db = await _database.database;
    await db.execute('''
CREATE TABLE IF NOT EXISTS remote_sync_outbox(
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 event_id TEXT NOT NULL UNIQUE,
 business_id TEXT NOT NULL,
 branch_id INTEGER NOT NULL,
 device_id TEXT NOT NULL,
 entity_type TEXT NOT NULL,
 entity_id TEXT NOT NULL DEFAULT '',
 operation TEXT NOT NULL,
 payload_json TEXT NOT NULL,
 created_at TEXT NOT NULL,
 attempts INTEGER NOT NULL DEFAULT 0,
 last_error TEXT NOT NULL DEFAULT '',
 acknowledged_at TEXT
)''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS remote_sync_commands(
 command_id TEXT PRIMARY KEY,
 branch_id INTEGER NOT NULL,
 command_type TEXT NOT NULL,
 payload_json TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'pending',
 received_at TEXT NOT NULL
)''');
  }

  Future<void> configure({
    required Uri endpoint,
    required String businessId,
    required String token,
  }) async {
    if (!_allowed(endpoint)) {
      throw ArgumentError('Remote sync requires HTTPS.');
    }
    if (businessId.trim().isEmpty || token.trim().length < 32) {
      throw ArgumentError('Business ID and a strong access token are required.');
    }
    await _config.saveRemoteSyncEndpoint(endpoint.toString().replaceAll(RegExp(r'/$'), ''));
    await _config.saveRemoteSyncBusinessId(businessId.trim());
    await _config.saveRemoteSyncToken(token.trim());
    await _deviceId();
    await ensureSchema();
  }

  Future<void> enqueue({
    required int branchId,
    required String entityType,
    required String operation,
    required Map<String, Object?> payload,
    String entityId = '',
  }) async {
    final businessId = await _config.remoteSyncBusinessId();
    if (businessId == null || businessId.isEmpty) return;
    await ensureSchema();
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.insert('remote_sync_outbox', {
      'event_id': '${now.microsecondsSinceEpoch}-${_hex(10)}',
      'business_id': businessId,
      'branch_id': branchId,
      'device_id': await _deviceId(),
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'created_at': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, Object?>> status() async {
    await ensureSchema();
    final db = await _database.database;
    final pending = firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM remote_sync_outbox WHERE acknowledged_at IS NULL',
        )) ??
        0;
    final commands = firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM remote_sync_commands WHERE status='pending'",
        )) ??
        0;
    return {
      'configured': await _endpoint() != null,
      'pending_events': pending,
      'pending_commands': commands,
    };
  }

  Future<void> syncNow({required int branchId}) async {
    await ensureSchema();
    final endpoint = await _endpoint();
    final businessId = await _config.remoteSyncBusinessId();
    final token = await _config.remoteSyncToken();
    if (endpoint == null || businessId == null || token == null) {
      throw StateError('Remote sync is not configured.');
    }
    final headers = {
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'x-airmonlink-business-id': businessId,
    };
    final db = await _database.database;
    final rows = await db.query(
      'remote_sync_outbox',
      where: 'acknowledged_at IS NULL AND branch_id=?',
      whereArgs: [branchId],
      orderBy: 'id ASC',
      limit: 100,
    );

    if (rows.isNotEmpty) {
      final events = rows.map((r) => {
            'event_id': r['event_id'],
            'branch_id': r['branch_id'],
            'device_id': r['device_id'],
            'entity_type': r['entity_type'],
            'entity_id': r['entity_id'],
            'operation': r['operation'],
            'payload': jsonDecode(r['payload_json']! as String),
            'created_at': r['created_at'],
          }).toList();
      final response = await _client
          .post(
            endpoint.resolve('/v1/sync/events'),
            headers: headers,
            body: jsonEncode({
              'business_id': businessId,
              'branch_id': branchId,
              'events': events,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await db.rawUpdate(
          'UPDATE remote_sync_outbox SET attempts=attempts+1,last_error=? '
          'WHERE acknowledged_at IS NULL AND branch_id=?',
          ['HTTP ${response.statusCode}', branchId],
        );
        throw StateError('Remote sync push failed: HTTP ${response.statusCode}.');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await db.rawUpdate(
        'UPDATE remote_sync_outbox SET acknowledged_at=?,last_error=? '
        'WHERE acknowledged_at IS NULL AND branch_id=?',
        [now, '', branchId],
      );
    }

    final response = await _client
        .get(
          endpoint.resolve('/v1/sync/commands?business_id=$businessId&branch_id=$branchId'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Remote sync pull failed: HTTP ${response.statusCode}.');
    }
    if (response.body.trim().isEmpty) return;
    final body = jsonDecode(response.body);
    if (body is! Map || body['commands'] is! List) return;
    final batch = db.batch();
    for (final raw in body['commands'] as List) {
      if (raw is! Map) continue;
      final id = '${raw['command_id'] ?? ''}';
      final type = '${raw['type'] ?? ''}';
      if (id.isEmpty || type.isEmpty) continue;
      batch.insert('remote_sync_commands', {
        'command_id': id,
        'branch_id': branchId,
        'command_type': type,
        'payload_json': jsonEncode(raw['payload'] ?? {}),
        'status': 'pending',
        'received_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, Object?>>> pendingCommands(int branchId) async {
    await ensureSchema();
    final db = await _database.database;
    return db.query(
      'remote_sync_commands',
      where: "branch_id=? AND status='pending'",
      whereArgs: [branchId],
      orderBy: 'received_at ASC',
    );
  }

  Future<Uri?> _endpoint() async {
    final raw = await _config.remoteSyncEndpoint();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !_allowed(uri)) {
      throw StateError('Remote sync endpoint is invalid or insecure.');
    }
    return uri;
  }

  Future<String> _deviceId() async {
    final existing = await _config.remoteSyncDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;
    final value = 'abm-${_hex(32)}';
    await _config.saveRemoteSyncDeviceId(value);
    return value;
  }

  bool _allowed(Uri uri) {
    if (uri.scheme == 'https' && uri.host.isNotEmpty) return true;
    return uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1');
  }

  String _hex(int length) {
    final random = Random.secure();
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
