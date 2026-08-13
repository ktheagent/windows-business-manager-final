# -*- coding: utf-8 -*-
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


# 1) Extend the existing owner-recovery service with signed-in self-service.
service_path = Path("lib/commercial/services/owner_recovery_service.dart")
service = service_path.read_text(encoding="utf-8")
if "changeOwnerPin" not in service:
    anchor = "  Future<String> recoverOwnerPin({"
    insert = r""  Future<void> changeOwnerPin({
    required StaffUser owner,
    required String currentPin,
    required String newPin,
  }) async {
    if (owner.role != StaffRole.owner) {
      throw StateError('Only an owner can change the owner PIN.');
    }
    if (newPin.length < 4) {
      throw ArgumentError('The new PIN must contain at least four characters.');
    }
    if (newPin == currentPin) {
      throw ArgumentError('Choose a new PIN different from the current PIN.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'users',
        columns: ['pin_hash', 'is_active'],
        where: 'id = ?',
        whereArgs: [owner.id],
        limit: 1,
      );
      if (rows.isEmpty || (rows.first['is_active'] as num? ? 1).toInt() != 1) {
        throw StateError('The owner account is not active.');
      }
      final encoded = rows.first['pin_hash'] as String? ? '';
      if (!_security.verifyPin(currentPin, encoded)) {
        await _audit(
          txn,
          userId: owner.id,
          branchId: owner.branchId,
          action: 'staff.owner_pin_change_failed',
          entityId: '${owner.id}',
          success: false,
        );
        throw StateError('The current PIN is incorrect.');
      }
      await txn.update(
        'users',
        {
          'pin_hash': _security.hashPin(newPin),
          'force_pin_change': 0,
          'failed_attempts': 0,
          'locked_until': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [owner.id],
      );
      await _audit(
        txn,
        userId: owner.id,
        branchId: owner.branchId,
        action: 'staff.owner_pin_changed',
        entityId: '${owner.id}',
        success: true,
      );
    });
  }

  Future<String> rotateRecoveryCodeWithPin({
    required StaffUser owner,
    required String currentPin,
  }) async {
    if (owner.role != StaffRole.owner) {
      throw StateError('Only an owner can rotate the owner recovery code.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'users',
        columns: ['pin_hash', 'is_active'],
        where: 'id = ?',
        whereArgs: [owner.id],
        limit: 1,
      );
      if (rows.isEmpty || (rows.first['is_active'] as num? ? 1).toInt() != 1) {
        throw StateError('The owner account is not active.');
      }
      final encoded = rows.first['pin_hash'] as String? ? '';
      if (!_security.verifyPin(currentPin, encoded)) {
        await _audit(
          txn,
          userId: owner.id,
          branchId: owner.branchId,
          action: 'staff.owner_recovery_rotation_failed',
          entityId: '${owner.id}',
          success: false,
        );
        throw StateError('The current PIN is incorrect.');
      }
      final code = _generateCode();
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
        action: 'staff.owner_recovery_code_rotated',
        entityId: '${owner.id}',
        success: true,
      );
      return code;
    });
  }
