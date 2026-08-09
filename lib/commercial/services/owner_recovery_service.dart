import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../services/database_service.dart';
import '../models/commercial_models.dart';
import 'security_service.dart';

class OwnerRecoveryService {
  OwnerRecoveryService({
    DatabaseService? database,
    SecurityService security = const SecurityService(),
  })  : _database = database ?? DatabaseService.instance,
        _security = security;

  final DatabaseService _database;
  final SecurityService _security;

  String _settingKey(int userId) => 'owner_recovery_hash_$userId';

  String _normalizeCode(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  String _generateCode() {
    var compact = '';
    while (compact.length < 20) {
      compact += _security
          .randomToken(bytes: 18)
          .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
          .toUpperCase();
    }
    compact = compact.substring(0, 20);
    return List<String>.generate(
      5,
      (index) => compact.substring(index * 4, index * 4 + 4),
      growable: false,
    ).join('-');
  }

  Future<String?> ensureRecoveryCode(StaffUser owner) async {
    if (owner.role != StaffRole.owner) return null;
    final db = await _database.database;
    final existing = await db.query(
      'settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [_settingKey(owner.id)],
      limit: 1,
    );
    if (existing.isNotEmpty &&
        (existing.first['setting_value'] as String? ?? '').isNotEmpty) {
      return null;
    }
    final code = _generateCode();
    await db.transaction((txn) async {
      await txn.insert(
        'settings',
        {
          'setting_key': _settingKey(owner.id),
          'setting_value': _security.hashPin(_normalizeCode(code)),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _audit(
        txn,
        userId: owner.id,
        branchId: owner.branchId,
        action: 'staff.owner_recovery_code_created',
        entityId: '${owner.id}',
        success: true,
      );
    });
    return code;
  }

  Future<String> replaceRecoveryCode(StaffUser owner) async {
    if (owner.role != StaffRole.owner) {
      throw StateError('Only an owner can manage an owner recovery code.');
    }
    final code = _generateCode();
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert(
        'settings',
        {
          'setting_key': _settingKey(owner.id),
          'setting_value': _security.hashPin(_normalizeCode(code)),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _audit(
        txn,
        userId: owner.id,
        branchId: owner.branchId,
        action: 'staff.owner_recovery_code_replaced',
        entityId: '${owner.id}',
        success: true,
      );
    });
    return code;
  }

  Future<String> recoverOwnerPin({
    required String username,
    required String recoveryCode,
    required String newPin,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedCode = _normalizeCode(recoveryCode);
    if (normalizedUsername.isEmpty || normalizedCode.length < 16) {
      throw StateError('Enter the owner username and recovery code.');
    }
    if (newPin.length < 4) {
      throw ArgumentError('The new PIN must contain at least four characters.');
    }

    final db = await _database.database;
    return db.transaction((txn) async {
      final users = await txn.query(
        'users',
        columns: ['id', 'branch_id', 'role', 'is_active'],
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [normalizedUsername],
        limit: 1,
      );
      if (users.isEmpty) {
        throw StateError('The recovery details are invalid.');
      }

      final row = users.first;
      final userId = row['id'] as int;
      final branchId = (row['branch_id'] as num? ?? 1).toInt();
      final role = row['role'] as String? ?? '';
      final active = (row['is_active'] as num? ?? 1).toInt() == 1;
      if (!active) {
        throw StateError('This owner account is disabled.');
      }
      if (role != StaffRole.owner.databaseValue) {
        throw StateError(
          'Owner recovery codes are only for owner accounts. '
          'Ask an owner or manager to reset a staff PIN.',
        );
      }

      final recoveryRows = await txn.query(
        'settings',
        columns: ['setting_value'],
        where: 'setting_key = ?',
        whereArgs: [_settingKey(userId)],
        limit: 1,
      );
      if (recoveryRows.isEmpty) {
        throw StateError(
          'No recovery code is registered for this owner. '
          'Sign in with another owner account and reset this account.',
        );
      }

      final encoded = recoveryRows.first['setting_value'] as String;
      if (!_security.verifyPin(normalizedCode, encoded)) {
        await _audit(
          txn,
          userId: userId,
          branchId: branchId,
          action: 'staff.owner_pin_recovery_failed',
          entityId: '$userId',
          success: false,
        );
        throw StateError('The recovery details are invalid.');
      }

      final rotatedCode = _generateCode();
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'users',
        {
          'pin_hash': _security.hashPin(newPin),
          'force_pin_change': 0,
          'failed_attempts': 0,
          'locked_until': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      await txn.insert(
        'settings',
        {
          'setting_key': _settingKey(userId),
          'setting_value': _security.hashPin(_normalizeCode(rotatedCode)),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'staff_sessions',
        {'ended_at': now},
        where: 'user_id = ? AND ended_at IS NULL',
        whereArgs: [userId],
      );
      await _audit(
        txn,
        userId: userId,
        branchId: branchId,
        action: 'staff.owner_pin_recovered',
        entityId: '$userId',
        success: true,
      );
      return rotatedCode;
    });
  }

  Future<void> _audit(
    DatabaseExecutor db, {
    required int userId,
    required int branchId,
    required String action,
    required String entityId,
    required bool success,
  }) async {
    await db.insert('audit_logs', {
      'user_id': userId,
      'branch_id': branchId,
      'action': action,
      'entity_type': 'user',
      'entity_id': entityId,
      'success': success ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
