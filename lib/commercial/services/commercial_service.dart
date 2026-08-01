import 'dart:convert';
import 'dart:math';

import 'package:sqflite_common/utils/utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/money.dart';
import '../../models/sale.dart';
import '../../services/database_service.dart';
import '../models/commercial_models.dart';
import 'security_service.dart';

class CommercialService {
  CommercialService(
    this._database, {
    SecurityService security = const SecurityService(),
  }) : _security = security;

  final DatabaseService _database;
  final SecurityService _security;

  Future<bool> hasStaffUsers() async {
    final db = await _database.database;
    final count =
        firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
    return count > 0;
  }

  Future<StaffUser> createInitialOwner({
    required String name,
    required String username,
    required String pin,
  }) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final count =
          firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
      if (count > 0) throw StateError('The owner account already exists.');
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('users', {
        'branch_id': DatabaseService.defaultBranchId,
        'name': name.trim(),
        'username': username.trim(),
        'pin_hash': _security.hashPin(pin),
        'role': StaffRole.owner.databaseValue,
        'is_active': 1,
        'created_at': now,
        'last_login_at': now,
        'updated_at': now,
      });
      await txn.insert('user_branch_access', {
        'user_id': id,
        'branch_id': DatabaseService.defaultBranchId,
        'is_primary': 1,
        'granted_by': id,
        'granted_at': now,
      });
      await _writeAudit(
        txn,
        userId: id,
        branchId: DatabaseService.defaultBranchId,
        action: 'staff.owner_created',
        entityType: 'user',
        entityId: '$id',
        newValues: {'name': name.trim(), 'username': username.trim()},
      );
      return _staffById(txn, id);
    });
  }

  Future<StaffUser> login({
    required String username,
    required String pin,
  }) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'users',
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [username.trim()],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Invalid username or PIN.');
      final row = rows.first;
      final userId = row['id'] as int;
      final isActive = (row['is_active'] as num? ?? 1).toInt() == 1;
      if (!isActive) throw StateError('This staff account is disabled.');
      final lockedUntil = row['locked_until'] == null
          ? null
          : DateTime.tryParse(row['locked_until'] as String);
      if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
        throw StateError('Account temporarily locked. Try again later.');
      }
      final encoded = row['pin_hash'] as String;
      if (!_security.verifyPin(pin, encoded)) {
        final failed = (row['failed_attempts'] as num? ?? 0).toInt() + 1;
        final updates = <String, Object?>{'failed_attempts': failed};
        if (failed >= 5) {
          updates['locked_until'] = DateTime.now()
              .add(const Duration(minutes: 15))
              .toIso8601String();
          updates['failed_attempts'] = 0;
        }
        await txn.update(
          'users',
          updates,
          where: 'id = ?',
          whereArgs: [userId],
        );
        await _writeAudit(
          txn,
          userId: userId,
          branchId: (row['branch_id'] as num? ?? 1).toInt(),
          action: 'staff.login_failed',
          entityType: 'user',
          entityId: '$userId',
          success: false,
        );
        throw StateError('Invalid username or PIN.');
      }

      final now = DateTime.now().toIso8601String();
      final updates = <String, Object?>{
        'failed_attempts': 0,
        'locked_until': null,
        'last_login_at': now,
      };
      if (_security.needsUpgrade(encoded)) {
        updates['pin_hash'] = _security.hashPin(pin);
      }
      await txn.update('users', updates, where: 'id = ?', whereArgs: [userId]);
      await txn.insert('staff_sessions', {
        'user_id': userId,
        'branch_id': (row['branch_id'] as num? ?? 1).toInt(),
        'started_at': now,
      });
      await _writeAudit(
        txn,
        userId: userId,
        branchId: (row['branch_id'] as num? ?? 1).toInt(),
        action: 'staff.login',
        entityType: 'user',
        entityId: '$userId',
      );
      return _staffById(txn, userId);
    });
  }

  Future<void> endStaffSession(StaffUser user) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'staff_sessions',
        columns: ['id'],
        where: 'user_id = ? AND ended_at IS NULL',
        whereArgs: [user.id],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await txn.update(
          'staff_sessions',
          {'ended_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [rows.first['id']],
        );
      }
      await _writeAudit(
        txn,
        userId: user.id,
        branchId: user.branchId,
        action: 'staff.logout',
        entityType: 'user',
        entityId: '${user.id}',
      );
    });
  }

  Future<List<StaffUser>> listStaff(StaffUser actor) async {
    _require(actor, CommercialPermission.staffManage);
    final db = await _database.database;
    final rows = await db.query('users', orderBy: 'name COLLATE NOCASE');
    final result = <StaffUser>[];
    for (final row in rows) {
      result.add(await _staffById(db, row['id'] as int));
    }
    return result;
  }

  Future<int> createStaff({
    required StaffUser actor,
    required int branchId,
    required String name,
    required String username,
    required String pin,
    required StaffRole role,
  }) async {
    _require(actor, CommercialPermission.staffManage);
    final db = await _database.database;
    return db.transaction((txn) async {
      if (role == StaffRole.owner && actor.role != StaffRole.owner) {
        throw StateError('Only an owner can create another owner account.');
      }
      final branch = await txn.query(
        'branches',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [branchId],
        limit: 1,
      );
      if (branch.isEmpty)
        throw StateError('The selected branch is not active.');
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('users', {
        'branch_id': branchId,
        'name': name.trim(),
        'username': username.trim(),
        'pin_hash': _security.hashPin(pin),
        'role': role.databaseValue,
        'force_pin_change': forcePinChange ? 1 : 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('user_branch_access', {
        'user_id': id,
        'branch_id': branchId,
        'is_primary': 1,
        'granted_by': actor.id,
        'granted_at': now,
      });
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'staff.created',
        entityType: 'user',
        entityId: '$id',
        newValues: {
          'name': name.trim(),
          'username': username.trim(),
          'role': role.databaseValue,
          'branch_id': branchId,
        },
      );
      return id;
    });
  }

  Future<void> setStaffActive({
    required StaffUser actor,
    required int userId,
    required bool active,
  }) async {
    _require(actor, CommercialPermission.staffManage);
    if (actor.id == userId && !active) {
      throw StateError('You cannot disable your current account.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final target = await txn.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (target.isEmpty) throw StateError('Staff user was not found.');
      if ((target.first['role'] as String? ?? '') == 'owner' &&
          actor.role != StaffRole.owner) {
        throw StateError('Only an owner can change an owner account.');
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'users',
        {'is_active': active ? 1 : 0, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (!active) {
        await txn.update(
          'staff_sessions',
          {'ended_at': now},
          where: 'user_id = ? AND ended_at IS NULL',
          whereArgs: [userId],
        );
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: active ? 'staff.enabled' : 'staff.disabled',
        entityType: 'user',
        entityId: '$userId',
      );
    });
  }

  Future<void> updateStaff({
    required StaffUser actor,
    required int userId,
    required String name,
    required String username,
    required StaffRole role,
    required int primaryBranchId,
    bool forcePinChange = false,
  }) async {
    _require(actor, CommercialPermission.staffManage);
    if (name.trim().isEmpty || username.trim().isEmpty) {
      throw ArgumentError('Staff name and username are required.');
    }
    if (role == StaffRole.owner && actor.role != StaffRole.owner) {
      throw StateError('Only an owner can assign the owner role.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final current = await txn.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (current.isEmpty) throw StateError('Staff user was not found.');
      final currentRole = current.first['role'] as String? ?? '';
      if (currentRole == 'owner' && actor.role != StaffRole.owner) {
        throw StateError('Only an owner can edit an owner account.');
      }
      final branch = await txn.query(
        'branches',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [primaryBranchId],
        limit: 1,
      );
      if (branch.isEmpty)
        throw StateError('The selected branch is not active.');
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'users',
        {
          'name': name.trim(),
          'username': username.trim(),
          'role': role.databaseValue,
          'branch_id': primaryBranchId,
          'force_pin_change': forcePinChange ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      await txn.update(
        'user_branch_access',
        {'is_primary': 0},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.insert('user_branch_access', {
        'user_id': userId,
        'branch_id': primaryBranchId,
        'is_primary': 1,
        'granted_by': actor.id,
        'granted_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'staff.updated',
        entityType: 'user',
        entityId: '$userId',
        oldValues: {
          'name': current.first['name'],
          'username': current.first['username'],
          'role': currentRole,
          'branch_id': current.first['branch_id'],
        },
        newValues: {
          'name': name.trim(),
          'username': username.trim(),
          'role': role.databaseValue,
          'branch_id': primaryBranchId,
          'force_pin_change': forcePinChange,
        },
      );
    });
  }

  Future<void> resetStaffPin({
    required StaffUser actor,
    required int userId,
    required String newPin,
    bool forceChange = true,
  }) async {
    _require(actor, CommercialPermission.staffManage);
    if (actor.id == userId && forceChange) {
      throw StateError('Use the change-PIN action for your own account.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final target = await txn.query(
        'users',
        columns: ['id', 'role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (target.isEmpty) throw StateError('Staff user was not found.');
      if ((target.first['role'] as String? ?? '') == 'owner' &&
          actor.role != StaffRole.owner) {
        throw StateError('Only an owner can reset an owner PIN.');
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'users',
        {
          'pin_hash': _security.hashPin(newPin),
          'force_pin_change': forceChange ? 1 : 0,
          'failed_attempts': 0,
          'locked_until': null,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      await txn.update(
        'staff_sessions',
        {'ended_at': now},
        where: 'user_id = ? AND ended_at IS NULL',
        whereArgs: [userId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'staff.pin_reset',
        entityType: 'user',
        entityId: '$userId',
        newValues: {'force_pin_change': forceChange},
      );
    });
  }

  Future<void> changeOwnPin({
    required StaffUser actor,
    required String currentPin,
    required String newPin,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'users',
        columns: ['pin_hash'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [actor.id],
        limit: 1,
      );
      if (rows.isEmpty ||
          !_security.verifyPin(currentPin, rows.first['pin_hash'] as String)) {
        throw StateError('The current PIN is incorrect.');
      }
      await txn.update(
        'users',
        {
          'pin_hash': _security.hashPin(newPin),
          'force_pin_change': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [actor.id],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'staff.pin_changed',
        entityType: 'user',
        entityId: '${actor.id}',
      );
    });
  }

  Future<void> setStaffLocked({
    required StaffUser actor,
    required int userId,
    required bool locked,
    Duration lockDuration = const Duration(days: 3650),
  }) async {
    _require(actor, CommercialPermission.staffManage);
    if (actor.id == userId && locked) {
      throw StateError('You cannot lock your current account.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final target = await txn.query(
        'users',
        columns: ['id', 'role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (target.isEmpty) throw StateError('Staff user was not found.');
      if ((target.first['role'] as String? ?? '') == 'owner' &&
          actor.role != StaffRole.owner) {
        throw StateError('Only an owner can lock or unlock an owner account.');
      }
      final now = DateTime.now();
      await txn.update(
        'users',
        {
          'locked_until': locked
              ? now.add(lockDuration).toIso8601String()
              : null,
          'failed_attempts': 0,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (locked) {
        await txn.update(
          'staff_sessions',
          {'ended_at': now.toIso8601String()},
          where: 'user_id = ? AND ended_at IS NULL',
          whereArgs: [userId],
        );
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: locked ? 'staff.locked' : 'staff.unlocked',
        entityType: 'user',
        entityId: '$userId',
      );
    });
  }

  Future<void> assignStaffBranches({
    required StaffUser actor,
    required int userId,
    required Set<int> branchIds,
    required int primaryBranchId,
  }) async {
    _require(actor, CommercialPermission.staffManage);
    if (branchIds.isEmpty || !branchIds.contains(primaryBranchId)) {
      throw ArgumentError(
        'The primary branch must be in the branch assignment.',
      );
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final target = await txn.query(
        'users',
        columns: ['id', 'role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      if (target.isEmpty) throw StateError('Staff user was not found.');
      if ((target.first['role'] as String? ?? '') == 'owner' &&
          actor.role != StaffRole.owner) {
        throw StateError(
          'Only an owner can change an owner branch assignment.',
        );
      }
      final ids = branchIds.toList()..sort();
      final placeholders = List.filled(ids.length, '?').join(',');
      final active =
          firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM branches '
              'WHERE is_active = 1 AND id IN ($placeholders)',
              ids,
            ),
          ) ??
          0;
      if (active != ids.length) {
        throw StateError('Every assigned branch must be active.');
      }
      await txn.delete(
        'user_branch_access',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final now = DateTime.now().toIso8601String();
      for (final branchId in ids) {
        await txn.insert('user_branch_access', {
          'user_id': userId,
          'branch_id': branchId,
          'is_primary': branchId == primaryBranchId ? 1 : 0,
          'granted_by': actor.id,
          'granted_at': now,
        });
      }
      await txn.update(
        'users',
        {'branch_id': primaryBranchId, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [userId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'staff.branches_assigned',
        entityType: 'user',
        entityId: '$userId',
        newValues: {'branch_ids': ids, 'primary_branch_id': primaryBranchId},
      );
    });
  }

  Future<List<BranchRecord>> accessibleBranches(StaffUser actor) async {
    final db = await _database.database;
    final rows = actor.role == StaffRole.owner
        ? await db.query(
            'branches',
            where: 'is_active = 1',
            orderBy: 'name COLLATE NOCASE',
          )
        : await db.rawQuery(
            '''
            SELECT b.*
            FROM branches b
            INNER JOIN user_branch_access uba ON uba.branch_id = b.id
            WHERE uba.user_id = ? AND b.is_active = 1
            ORDER BY b.name COLLATE NOCASE
          ''',
            [actor.id],
          );
    return rows.map(BranchRecord.fromMap).toList(growable: false);
  }

  Future<bool> canAccessBranch(StaffUser actor, int branchId) async {
    if (actor.role == StaffRole.owner) return true;
    final db = await _database.database;
    final count =
        firstIntValue(
          await db.rawQuery(
            '''
            SELECT COUNT(*)
            FROM user_branch_access uba
            INNER JOIN branches b ON b.id = uba.branch_id
            WHERE uba.user_id = ? AND uba.branch_id = ?
              AND b.is_active = 1
          ''',
            [actor.id, branchId],
          ),
        ) ??
        0;
    return count > 0;
  }

  Future<List<Map<String, Object?>>> listStaffSessions({
    required StaffUser actor,
    int? userId,
  }) async {
    _require(actor, CommercialPermission.staffManage);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT ss.*, u.name AS user_name, u.username, u.role,
        b.name AS branch_name
      FROM staff_sessions ss
      INNER JOIN users u ON u.id = ss.user_id
      INNER JOIN branches b ON b.id = ss.branch_id
      WHERE (? IS NULL OR ss.user_id = ?)
      ORDER BY ss.started_at DESC, ss.id DESC
    ''',
      [userId, userId],
    );
  }

  Future<void> terminateStaffSession({
    required StaffUser actor,
    required int sessionId,
    String reason = '',
  }) async {
    _require(actor, CommercialPermission.staffManage);
    final db = await _database.database;
    await db.transaction((txn) async {
      final sessions = await txn.query(
        'staff_sessions',
        where: 'id = ? AND ended_at IS NULL',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty) {
        throw StateError('The staff session is not active.');
      }
      final targetUserId = sessions.first['user_id'] as int;
      if (targetUserId == actor.id) {
        throw StateError('Use Sign out to end your current session.');
      }
      await txn.update(
        'staff_sessions',
        {'ended_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'staff.session_terminated',
        entityType: 'staff_session',
        entityId: '$sessionId',
        reason: reason.trim(),
        newValues: {'user_id': targetUserId},
      );
    });
  }

  Future<List<AuditEntry>> staffAuditHistory({
    required StaffUser actor,
    required int userId,
    int limit = 200,
  }) async {
    _require(actor, CommercialPermission.auditView);
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT a.*, u.name AS user_name, u.role AS user_role,
        b.name AS branch_name
      FROM audit_logs a
      LEFT JOIN users u ON u.id = a.user_id
      LEFT JOIN branches b ON b.id = a.branch_id
      WHERE a.user_id = ?
      ORDER BY a.created_at DESC, a.id DESC
      LIMIT ?
    ''',
      [userId, limit.clamp(1, 1000).toInt()],
    );
    return rows.map(AuditEntry.fromMap).toList(growable: false);
  }

  Future<List<BranchRecord>> listBranches({bool activeOnly = true}) async {
    final db = await _database.database;
    final rows = await db.query(
      'branches',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(BranchRecord.fromMap).toList(growable: false);
  }

  Future<int> createBranch({
    required StaffUser actor,
    required String name,
    required String code,
    String address = '',
    String phone = '',
    String email = '',
  }) async {
    _require(actor, CommercialPermission.branchesManage);
    final db = await _database.database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('branches', {
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'address': address.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'is_active': 1,
        'created_at': now,
      });
      await txn.execute(
        '''
        INSERT INTO branch_inventory
          (branch_id, product_id, stock_qty, low_stock_level, updated_at)
        SELECT ?, id, 0, low_stock_level, ? FROM products WHERE is_active = 1
      ''',
        [id, now],
      );
      await txn.insert('cash_registers', {
        'branch_id': id,
        'name': 'Main Register',
        'is_active': 1,
      });
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'branch.created',
        entityType: 'branch',
        entityId: '$id',
        newValues: {'name': name.trim(), 'code': code.trim().toUpperCase()},
      );
      return id;
    });
  }

  Future<void> updateBranch({
    required StaffUser actor,
    required int branchId,
    required String name,
    required String code,
    String address = '',
    String phone = '',
    String email = '',
  }) async {
    _require(actor, CommercialPermission.branchesManage);
    if (name.trim().isEmpty || code.trim().isEmpty) {
      throw ArgumentError('Branch name and code are required.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'branches',
        where: 'id = ?',
        whereArgs: [branchId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Branch was not found.');
      await txn.update(
        'branches',
        {
          'name': name.trim(),
          'code': code.trim().toUpperCase(),
          'address': address.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
        },
        where: 'id = ?',
        whereArgs: [branchId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'branch.updated',
        entityType: 'branch',
        entityId: '$branchId',
        oldValues: {
          'name': rows.first['name'],
          'code': rows.first['code'],
          'address': rows.first['address'],
          'phone': rows.first['phone'],
          'email': rows.first['email'],
        },
        newValues: {
          'name': name.trim(),
          'code': code.trim().toUpperCase(),
          'address': address.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
        },
      );
    });
  }

  Future<void> setBranchActive({
    required StaffUser actor,
    required int branchId,
    required bool active,
    String reason = '',
  }) async {
    _require(actor, CommercialPermission.branchesManage);
    if (!active && branchId == DatabaseService.defaultBranchId) {
      throw StateError('The main branch cannot be disabled.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'branches',
        where: 'id = ?',
        whereArgs: [branchId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Branch was not found.');
      if (!active) {
        final openCash =
            firstIntValue(
              await txn.rawQuery(
                '''
          SELECT COUNT(*) FROM cash_sessions
          WHERE branch_id = ? AND status = 'open'
        ''',
                [branchId],
              ),
            ) ??
            0;
        final openTransfers =
            firstIntValue(
              await txn.rawQuery(
                '''
          SELECT COUNT(*) FROM stock_transfers
          WHERE (source_branch_id = ? OR destination_branch_id = ?)
            AND status IN ('draft', 'approved', 'dispatched', 'partially_received')
        ''',
                [branchId, branchId],
              ),
            ) ??
            0;
        if (openCash > 0 || openTransfers > 0) {
          throw StateError(
            'Close cash sessions and active stock transfers before disabling '
            'this branch.',
          );
        }
      }
      await txn.update(
        'branches',
        {'is_active': active ? 1 : 0},
        where: 'id = ?',
        whereArgs: [branchId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: active ? 'branch.enabled' : 'branch.disabled',
        entityType: 'branch',
        entityId: '$branchId',
        reason: reason.trim(),
      );
    });
  }

  Future<List<Map<String, Object?>>> listCashRegisters(StaffUser actor) async {
    _require(actor, CommercialPermission.cashManage);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT cr.*,
        (SELECT COUNT(*) FROM cash_sessions cs
          WHERE cs.register_id = cr.id AND cs.status = 'open') AS open_sessions
      FROM cash_registers cr
      WHERE cr.branch_id = ? AND cr.is_active = 1
      ORDER BY cr.name COLLATE NOCASE
    ''',
      [actor.branchId],
    );
  }

  Future<int> createCashRegister({
    required StaffUser actor,
    required String name,
  }) async {
    _require(actor, CommercialPermission.cashManage);
    if (name.trim().isEmpty) {
      throw ArgumentError('Cash-register name is required.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      final id = await txn.insert('cash_registers', {
        'branch_id': actor.branchId,
        'name': name.trim(),
        'is_active': 1,
      });
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'cash_register.created',
        entityType: 'cash_register',
        entityId: '$id',
        newValues: {'name': name.trim()},
      );
      return id;
    });
  }

  Future<void> setCashRegisterActive({
    required StaffUser actor,
    required int registerId,
    required bool active,
  }) async {
    _require(actor, CommercialPermission.cashManage);
    final db = await _database.database;
    await db.transaction((txn) async {
      if (!active) {
        final open =
            firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM cash_sessions '
                'WHERE register_id = ? AND status = ?',
                [registerId, 'open'],
              ),
            ) ??
            0;
        if (open > 0) {
          throw StateError(
            'Close the open shift before disabling this register.',
          );
        }
      }
      final updated = await txn.update(
        'cash_registers',
        {'is_active': active ? 1 : 0},
        where: 'id = ? AND branch_id = ?',
        whereArgs: [registerId, actor.branchId],
      );
      if (updated != 1) throw StateError('Cash register was not found.');
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: active ? 'cash_register.enabled' : 'cash_register.disabled',
        entityType: 'cash_register',
        entityId: '$registerId',
      );
    });
  }

  Future<List<Map<String, Object?>>> cashSessionHistory({
    required StaffUser actor,
    int limit = 200,
  }) async {
    _require(actor, CommercialPermission.cashManage);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT cs.*, cr.name AS register_name, u.name AS user_name,
        approver.name AS approved_by_name
      FROM cash_sessions cs
      INNER JOIN cash_registers cr ON cr.id = cs.register_id
      INNER JOIN users u ON u.id = cs.user_id
      LEFT JOIN users approver ON approver.id = cs.approved_by
      WHERE cs.branch_id = ?
      ORDER BY cs.opened_at DESC, cs.id DESC
      LIMIT ?
    ''',
      [actor.branchId, limit.clamp(1, 1000).toInt()],
    );
  }

  Future<List<Map<String, Object?>>> cashSessionMovements({
    required StaffUser actor,
    required int cashSessionId,
  }) async {
    _require(actor, CommercialPermission.cashManage);
    final db = await _database.database;
    final visible =
        firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM cash_sessions '
            'WHERE id = ? AND branch_id = ?',
            [cashSessionId, actor.branchId],
          ),
        ) ??
        0;
    if (visible == 0) throw StateError('Cash session was not found.');
    return db.rawQuery(
      '''
      SELECT cm.*, u.name AS user_name
      FROM cash_movements cm
      LEFT JOIN users u ON u.id = cm.user_id
      WHERE cm.cash_session_id = ?
      ORDER BY cm.created_at, cm.id
    ''',
      [cashSessionId],
    );
  }

  Future<void> approveCashVariance({
    required StaffUser actor,
    required int cashSessionId,
    required String reason,
  }) async {
    _require(actor, CommercialPermission.cashVarianceApprove);
    if (reason.trim().isEmpty) {
      throw ArgumentError('A variance approval reason is required.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'cash_sessions',
        where:
            'id = ? AND branch_id = ? AND status = ? '
            'AND variance IS NOT NULL',
        whereArgs: [cashSessionId, actor.branchId, 'pending_approval'],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('No pending cash variance was found.');
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'cash_sessions',
        {
          'status': 'closed',
          'approved_by': actor.id,
          'approved_at': now,
          'closing_note':
              '${rows.first['closing_note'] ?? ''}\nApproval: ${reason.trim()}'
                  .trim(),
        },
        where: 'id = ?',
        whereArgs: [cashSessionId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'cash_session.variance_approved',
        entityType: 'cash_session',
        entityId: '$cashSessionId',
        reason: reason.trim(),
        newValues: {'variance': rows.first['variance']},
      );
    });
  }

  Future<List<Map<String, Object?>>> returnableSaleItems({
    required StaffUser actor,
    required int saleId,
  }) async {
    _require(actor, CommercialPermission.salesRefund);
    final db = await _database.database;
    final sale = await db.query(
      'sales',
      columns: ['id'],
      where: 'id = ? AND branch_id = ? AND status = ?',
      whereArgs: [saleId, actor.branchId, 'completed'],
      limit: 1,
    );
    if (sale.isEmpty) throw StateError('Sale was not found.');
    return db.rawQuery(
      '''
      SELECT si.id, si.product_id, si.product_name, si.quantity,
        si.unit_price, si.cost_price,
        MAX(si.quantity - COALESCE((SELECT SUM(ri2.quantity)
          FROM return_items ri2
          INNER JOIN returns r2 ON r2.id = ri2.return_id
          WHERE ri2.sale_item_id = si.id), 0), 0)
          AS returnable_quantity
      FROM sale_items si
      WHERE si.sale_id = ?
      ORDER BY si.id
    ''',
      [saleId],
    );
  }

  Future<List<Map<String, Object?>>> listStockCounts(StaffUser actor) async {
    _require(actor, CommercialPermission.stockCount);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT sc.*, u.name AS created_by_name
      FROM stock_counts sc
      LEFT JOIN users u ON u.id = sc.created_by
      WHERE sc.branch_id = ?
      ORDER BY sc.created_at DESC
    ''',
      [actor.branchId],
    );
  }

  Future<List<Map<String, Object?>>> stockCountItems({
    required StaffUser actor,
    required int stockCountId,
  }) async {
    _require(actor, CommercialPermission.stockCount);
    final db = await _database.database;
    final count = await db.query(
      'stock_counts',
      columns: ['id'],
      where: 'id = ? AND branch_id = ?',
      whereArgs: [stockCountId, actor.branchId],
      limit: 1,
    );
    if (count.isEmpty) throw StateError('Stock count was not found.');
    return db.rawQuery(
      '''
      SELECT sci.*, p.name AS product_name, p.sku, p.barcode
      FROM stock_count_items sci
      INNER JOIN products p ON p.id = sci.product_id
      WHERE sci.stock_count_id = ?
      ORDER BY p.name COLLATE NOCASE
    ''',
      [stockCountId],
    );
  }

  Future<List<Map<String, Object?>>> listRecurringExpenses(
    StaffUser actor,
  ) async {
    _require(actor, CommercialPermission.expensesView);
    final db = await _database.database;
    return db.query(
      'recurring_expenses',
      where: 'branch_id = ?',
      whereArgs: [actor.branchId],
      orderBy: 'next_due_at, title COLLATE NOCASE',
    );
  }

  Future<List<AuditEntry>> listAudit({
    required StaffUser actor,
    int limit = 250,
  }) async {
    _require(actor, CommercialPermission.auditView);
    final db = await _database.database;
    final consolidated =
        actor.role == StaffRole.owner || actor.role == StaffRole.manager;
    final rows = await db.rawQuery('''
      SELECT a.*, u.name AS user_name, b.name AS branch_name
      FROM audit_logs a
      LEFT JOIN users u ON u.id = a.user_id
      LEFT JOIN branches b ON b.id = a.branch_id
      ${consolidated ? '' : 'WHERE a.branch_id = ?'}
      ORDER BY a.created_at DESC
      LIMIT ?
    ''', consolidated ? [limit] : [actor.branchId, limit]);
    return rows.map(AuditEntry.fromMap).toList(growable: false);
  }

  Future<int> openCashSession({
    required StaffUser actor,
    required int registerId,
    required double openingFloat,
    String note = '',
  }) async {
    _require(actor, CommercialPermission.cashManage);
    if (openingFloat < 0)
      throw ArgumentError('Opening float cannot be negative.');
    final db = await _database.database;
    return db.transaction((txn) async {
      final register = await txn.query(
        'cash_registers',
        where: 'id = ? AND branch_id = ? AND is_active = 1',
        whereArgs: [registerId, actor.branchId],
        limit: 1,
      );
      if (register.isEmpty) throw StateError('Cash register was not found.');
      final normalizedFloat = MoneyMath.round(openingFloat);
      final id = await txn.insert('cash_sessions', {
        'register_id': registerId,
        'branch_id': actor.branchId,
        'user_id': actor.id,
        'opening_float': normalizedFloat,
        'status': 'open',
        'opening_note': note.trim(),
        'opened_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('cash_movements', {
        'cash_session_id': id,
        'user_id': actor.id,
        'movement_type': 'opening_float',
        'amount': normalizedFloat,
        'transaction_ref': 'cash-opening-$id',
        'note': note.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'cash_session.opened',
        entityType: 'cash_session',
        entityId: '$id',
        newValues: {'opening_float': normalizedFloat},
      );
      return id;
    });
  }

  Future<Map<String, Object?>?> currentCashSession(StaffUser actor) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT cs.*, cr.name AS register_name,
        COALESCE(SUM(cm.amount), 0) AS expected_total
      FROM cash_sessions cs
      INNER JOIN cash_registers cr ON cr.id = cs.register_id
      LEFT JOIN cash_movements cm ON cm.cash_session_id = cs.id
      WHERE cs.branch_id = ? AND cs.user_id = ? AND cs.status = 'open'
      GROUP BY cs.id
      ORDER BY cs.id DESC LIMIT 1
    ''',
      [actor.branchId, actor.id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> addCashMovement({
    required StaffUser actor,
    required int cashSessionId,
    required String type,
    required double amount,
    required String note,
    String? transactionReference,
  }) async {
    _require(actor, CommercialPermission.cashManage);
    final normalizedAmount = MoneyMath.round(amount);
    if (normalizedAmount <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    if (note.trim().isEmpty) {
      throw ArgumentError('A reason is required for cash movements.');
    }
    if (type != 'cash_in' && type != 'cash_out') {
      throw ArgumentError('Cash movement must be cash_in or cash_out.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      await _requireOpenCashSession(txn, cashSessionId, actor);
      final transactionRef = transactionReference?.trim().isNotEmpty == true
          ? transactionReference!.trim()
          : _number('CASH', DateTime.now());
      await txn.insert('cash_movements', {
        'cash_session_id': cashSessionId,
        'user_id': actor.id,
        'movement_type': type,
        'amount': type == 'cash_in' ? normalizedAmount : -normalizedAmount,
        'transaction_ref': transactionRef,
        'note': note.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'cash.$type',
        entityType: 'cash_session',
        entityId: '$cashSessionId',
        newValues: {
          'amount': normalizedAmount,
          'note': note.trim(),
          'transaction_ref': transactionRef,
        },
      );
    });
  }

  Future<Map<String, double>> closeCashSession({
    required StaffUser actor,
    required int cashSessionId,
    required double actualCash,
    String note = '',
  }) async {
    _require(actor, CommercialPermission.cashManage);
    if (actualCash < 0) throw ArgumentError('Actual cash cannot be negative.');
    final db = await _database.database;
    return db.transaction((txn) async {
      await _requireOpenCashSession(txn, cashSessionId, actor);
      final totalRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS value FROM cash_movements WHERE cash_session_id = ?',
        [cashSessionId],
      );
      final expected = MoneyMath.round(
        (totalRows.first['value'] as num? ?? 0).toDouble(),
      );
      final normalizedActual = MoneyMath.round(actualCash);
      final variance = MoneyMath.subtract(normalizedActual, expected);
      final requiresApproval =
          variance != 0 && !actor.can(CommercialPermission.cashVarianceApprove);
      await txn.update(
        'cash_sessions',
        {
          'expected_cash': expected,
          'actual_cash': normalizedActual,
          'variance': variance,
          'status': requiresApproval ? 'pending_approval' : 'closed',
          'closing_note': note.trim(),
          'closed_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [cashSessionId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'cash_session.closed',
        entityType: 'cash_session',
        entityId: '$cashSessionId',
        newValues: {
          'expected_cash': expected,
          'actual_cash': normalizedActual,
          'variance': variance,
          'requires_approval': requiresApproval,
        },
      );
      return {
        'expected': expected,
        'actual': normalizedActual,
        'variance': variance,
      };
    });
  }

  Future<int> createDocument({
    required StaffUser actor,
    required CommercialDocumentDraft draft,
  }) async {
    _require(actor, CommercialPermission.documentsManage);
    if (draft.discount > 0) {
      _require(actor, CommercialPermission.salesDiscount);
    }
    if (draft.items.isEmpty) throw ArgumentError('Add at least one item.');
    final db = await _database.database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final id = await txn.insert('documents', {
        'branch_id': actor.branchId,
        'customer_id': draft.customerId,
        'document_no': _number(_documentPrefix(draft.type), now),
        'document_type': draft.type,
        'status': 'draft',
        'subtotal': draft.subtotal,
        'discount': draft.discount,
        'tax': draft.totalTax,
        'total': draft.total,
        'amount_paid': 0,
        'balance_due': draft.type == 'invoice' ? draft.total : 0,
        'debt_posted': 0,
        'valid_until': draft.validUntil?.toIso8601String(),
        'due_at': draft.dueAt?.toIso8601String(),
        'payment_instructions': draft.paymentInstructions.trim(),
        'document_date': (draft.documentDate ?? now).toIso8601String(),
        'notes': draft.notes.trim(),
        'terms': draft.terms.trim(),
        'created_by': actor.id,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      for (final item in draft.items) {
        await txn.insert('document_items', {
          'document_id': id,
          ...item.toMap(),
        });
      }
      await _writeDocumentHistory(
        txn,
        documentId: id,
        oldStatus: '',
        newStatus: 'draft',
        actor: actor,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'document.created',
        entityType: draft.type,
        entityId: '$id',
        newValues: {'total': draft.total, 'customer_id': draft.customerId},
      );
      return id;
    });
  }

  Future<void> updateDocumentDraft({
    required StaffUser actor,
    required int documentId,
    required CommercialDocumentDraft draft,
  }) async {
    _require(actor, CommercialPermission.documentsManage);
    if (draft.discount > 0) {
      _require(actor, CommercialPermission.salesDiscount);
    }
    if (draft.items.isEmpty) throw ArgumentError('Add at least one item.');
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ? AND branch_id = ? AND status = ?',
        whereArgs: [documentId, actor.branchId, 'draft'],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Only a draft document can be edited.');
      }
      final current = rows.first;
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'documents',
        {
          'customer_id': draft.customerId,
          'document_type': draft.type,
          'subtotal': draft.subtotal,
          'discount': MoneyMath.round(draft.discount),
          'tax': draft.totalTax,
          'total': draft.total,
          'balance_due': draft.type == 'invoice' ? draft.total : 0,
          'valid_until': draft.validUntil?.toIso8601String(),
          'due_at': draft.dueAt?.toIso8601String(),
          'payment_instructions': draft.paymentInstructions.trim(),
          'document_date': (draft.documentDate ?? DateTime.now())
              .toIso8601String(),
          'notes': draft.notes.trim(),
          'terms': draft.terms.trim(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [documentId],
      );
      await txn.delete(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      for (final item in draft.items) {
        await txn.insert('document_items', {
          'document_id': documentId,
          ...item.toMap(),
        });
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'document.updated',
        entityType: draft.type,
        entityId: '$documentId',
        oldValues: {
          'customer_id': current['customer_id'],
          'subtotal': current['subtotal'],
          'discount': current['discount'],
          'tax': current['tax'],
          'total': current['total'],
        },
        newValues: {
          'customer_id': draft.customerId,
          'subtotal': draft.subtotal,
          'discount': draft.discount,
          'tax': draft.totalTax,
          'total': draft.total,
          'item_count': draft.items.length,
        },
      );
    });
  }

  Future<int> duplicateDocument({
    required StaffUser actor,
    required int documentId,
  }) async {
    _require(actor, CommercialPermission.documentsManage);
    final db = await _database.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ? AND branch_id = ?',
        whereArgs: [documentId, actor.branchId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Document was not found.');
      final source = rows.first;
      if (source['status'] == 'cancelled') {
        throw StateError('A cancelled document cannot be duplicated.');
      }
      final now = DateTime.now();
      final copyId = await txn.insert('documents', {
        'branch_id': actor.branchId,
        'customer_id': source['customer_id'],
        'document_no': _number(
          _documentPrefix(source['document_type'] as String),
          now,
        ),
        'document_type': source['document_type'],
        'status': 'draft',
        'subtotal': source['subtotal'],
        'discount': source['discount'],
        'tax': source['tax'],
        'total': source['total'],
        'amount_paid': 0,
        'balance_due': source['document_type'] == 'invoice'
            ? source['total']
            : 0,
        'debt_posted': 0,
        'valid_until': source['valid_until'],
        'due_at': source['due_at'],
        'payment_instructions': source['payment_instructions'],
        'document_date': now.toIso8601String(),
        'notes': source['notes'],
        'terms': source['terms'],
        'duplicated_from_id': documentId,
        'created_by': actor.id,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await txn.execute(
        '''
        INSERT INTO document_items
          (document_id, product_id, description, quantity, unit, unit_price,
           cost_price, line_discount, tax_rate, tax_inclusive, line_total)
        SELECT ?, product_id, description, quantity, unit, unit_price,
          cost_price, line_discount, tax_rate, tax_inclusive, line_total
        FROM document_items WHERE document_id = ?
      ''',
        [copyId, documentId],
      );
      await _writeDocumentHistory(
        txn,
        documentId: copyId,
        oldStatus: '',
        newStatus: 'draft',
        actor: actor,
        reason: 'Duplicated from document $documentId',
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'document.duplicated',
        entityType: source['document_type'] as String,
        entityId: '$copyId',
        newValues: {'source_document_id': documentId},
      );
      return copyId;
    });
  }

  Future<void> cancelDocument({
    required StaffUser actor,
    required int documentId,
    required String reason,
  }) async {
    _require(actor, CommercialPermission.documentsManage);
    if (reason.trim().isEmpty) {
      throw ArgumentError('A cancellation reason is required.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ? AND branch_id = ?',
        whereArgs: [documentId, actor.branchId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Document was not found.');
      final document = rows.first;
      final status = document['status'] as String;
      if (!{'draft', 'issued'}.contains(status)) {
        throw StateError(
          'Only a draft or unpaid issued document can be cancelled.',
        );
      }
      final amountPaid = (document['amount_paid'] as num? ?? 0).toDouble();
      if (amountPaid > 0) {
        throw StateError(
          'A document with payments must be reversed through a credit note '
          'or refund.',
        );
      }
      final now = DateTime.now().toIso8601String();
      final customerId = document['customer_id'] as int?;
      final debtPosted = (document['debt_posted'] as num? ?? 0).toInt() == 1;
      final balance = (document['balance_due'] as num? ?? 0).toDouble();
      if (customerId != null && debtPosted && balance > 0) {
        await txn.rawUpdate(
          'UPDATE customers '
          'SET balance = MAX(balance - ?, 0) '
          'WHERE id = ? AND branch_id = ?',
          [balance, customerId, actor.branchId],
        );
        final transactionRef = 'document-cancel-$documentId';
        await txn.insert('customer_transactions', {
          'customer_id': customerId,
          'branch_id': actor.branchId,
          'user_id': actor.id,
          'transaction_type': 'invoice_cancelled',
          'amount': -balance,
          'reference_type': 'document',
          'reference_id': documentId,
          'transaction_ref': transactionRef,
          'note': reason.trim(),
          'created_at': now,
        });
      }
      await txn.update(
        'documents',
        {
          'status': 'cancelled',
          'balance_due': 0,
          'debt_posted': 0,
          'cancelled_at': now,
          'cancelled_by': actor.id,
          'cancellation_reason': reason.trim(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [documentId],
      );
      await _writeDocumentHistory(
        txn,
        documentId: documentId,
        oldStatus: status,
        newStatus: 'cancelled',
        actor: actor,
        reason: reason,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'document.cancelled',
        entityType: document['document_type'] as String,
        entityId: '$documentId',
        reason: reason.trim(),
        oldValues: {'status': status, 'balance_due': balance},
        newValues: {'status': 'cancelled', 'balance_due': 0},
      );
    });
  }

  Future<List<Map<String, Object?>>> documentStatusHistory({
    required StaffUser actor,
    required int documentId,
  }) async {
    _require(actor, CommercialPermission.documentsManage);
    final db = await _database.database;
    final exists =
        firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM documents '
            'WHERE id = ? AND branch_id = ?',
            [documentId, actor.branchId],
          ),
        ) ??
        0;
    if (exists == 0) throw StateError('Document was not found.');
    return db.rawQuery(
      '''
      SELECT h.*, u.name AS changed_by_name
      FROM document_status_history h
      LEFT JOIN users u ON u.id = h.changed_by
      WHERE h.document_id = ?
      ORDER BY h.changed_at, h.id
    ''',
      [documentId],
    );
  }

  Future<List<Map<String, Object?>>> listDocuments(StaffUser actor) async {
    _require(actor, CommercialPermission.documentsManage);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT d.*, c.name AS customer_name, c.phone AS customer_phone,
        c.email AS customer_email
      FROM documents d
      LEFT JOIN customers c ON c.id = d.customer_id
      WHERE d.branch_id = ?
      ORDER BY d.created_at DESC
    ''',
      [actor.branchId],
    );
  }

  Future<List<Map<String, Object?>>> documentItems(int documentId) async {
    final db = await _database.database;
    return db.query(
      'document_items',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'id',
    );
  }

  Future<void> issueDocument({
    required StaffUser actor,
    required int documentId,
  }) async {
    _require(actor, CommercialPermission.documentsManage);
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ? AND branch_id = ? AND status = ?',
        whereArgs: [documentId, actor.branchId, 'draft'],
        limit: 1,
      );
      if (rows.isEmpty)
        throw StateError('Only a draft document can be issued.');
      final document = rows.first;
      final now = DateTime.now().toIso8601String();
      var debtPosted = (document['debt_posted'] as num? ?? 0).toInt();
      if (document['document_type'] == 'invoice' && debtPosted == 0) {
        final customerId = document['customer_id'] as int?;
        final balance = (document['balance_due'] as num? ?? 0).toDouble();
        if (balance > 0 && customerId == null) {
          throw StateError(
            'A customer is required before issuing a credit invoice.',
          );
        }
        if (customerId != null && balance > 0) {
          await _enforceCreditLimit(
            txn,
            branchId: actor.branchId,
            customerId: customerId,
            additionalDebt: balance,
          );
          await txn.rawUpdate(
            'UPDATE customers SET balance = balance + ? WHERE id = ? AND branch_id = ?',
            [balance, customerId, actor.branchId],
          );
          await txn.insert('customer_transactions', {
            'customer_id': customerId,
            'branch_id': actor.branchId,
            'user_id': actor.id,
            'transaction_type': 'invoice_issued',
            'amount': balance,
            'reference_type': 'document',
            'reference_id': documentId,
            'transaction_ref': 'invoice-issued-$documentId',
            'note': document['document_no'],
            'created_at': now,
          });
          debtPosted = 1;
        }
      }
      await txn.update(
        'documents',
        {'status': 'issued', 'debt_posted': debtPosted, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [documentId],
      );
      await _writeDocumentHistory(
        txn,
        documentId: documentId,
        oldStatus: 'draft',
        newStatus: 'issued',
        actor: actor,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'document.issued',
        entityType: 'document',
        entityId: '$documentId',
      );
    });
  }

  Future<int> convertQuotationToInvoice({
    required StaffUser actor,
    required int quotationId,
    DateTime? dueAt,
  }) async {
    _require(actor, CommercialPermission.documentsManage);
    final db = await _database.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ? AND branch_id = ?',
        whereArgs: [quotationId, actor.branchId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Quotation was not found.');
      final source = rows.first;
      if (source['document_type'] != 'quotation' &&
          source['document_type'] != 'estimate') {
        throw StateError('Only quotations and estimates can become invoices.');
      }
      if (source['status'] == 'converted') {
        throw StateError('This quotation has already been converted.');
      }
      final now = DateTime.now();
      final sourceCustomerId = source['customer_id'] as int?;
      final sourceTotal = (source['total'] as num).toDouble();
      if (sourceCustomerId == null && sourceTotal > 0) {
        throw StateError(
          'A customer is required before creating a credit invoice.',
        );
      }
      if (sourceCustomerId != null && sourceTotal > 0) {
        await _enforceCreditLimit(
          txn,
          branchId: actor.branchId,
          customerId: sourceCustomerId,
          additionalDebt: sourceTotal,
        );
      }
      final invoiceId = await txn.insert('documents', {
        'branch_id': actor.branchId,
        'customer_id': source['customer_id'],
        'document_no': _number('INV', now),
        'document_type': 'invoice',
        'status': 'issued',
        'subtotal': source['subtotal'],
        'discount': source['discount'],
        'tax': source['tax'],
        'total': source['total'],
        'amount_paid': 0,
        'balance_due': source['total'],
        'debt_posted': source['customer_id'] == null ? 0 : 1,
        'due_at': dueAt?.toIso8601String(),
        'payment_instructions': source['payment_instructions'],
        'document_date': now.toIso8601String(),
        'notes': source['notes'],
        'terms': source['terms'],
        'duplicated_from_id': quotationId,
        'created_by': actor.id,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await txn.execute(
        '''
        INSERT INTO document_items
          (document_id, product_id, description, quantity, unit, unit_price,
           cost_price, line_discount, tax_rate, tax_inclusive, line_total)
        SELECT ?, product_id, description, quantity, unit, unit_price,
          cost_price, line_discount, tax_rate, tax_inclusive, line_total
        FROM document_items WHERE document_id = ?
      ''',
        [invoiceId, quotationId],
      );
      final customerId = source['customer_id'] as int?;
      final invoiceBalance = (source['total'] as num).toDouble();
      if (customerId != null && invoiceBalance > 0) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ? AND branch_id = ?',
          [invoiceBalance, customerId, actor.branchId],
        );
        await txn.insert('customer_transactions', {
          'customer_id': customerId,
          'branch_id': actor.branchId,
          'user_id': actor.id,
          'transaction_type': 'invoice_issued',
          'amount': invoiceBalance,
          'reference_type': 'document',
          'reference_id': invoiceId,
          'transaction_ref': 'invoice-issued-$invoiceId',
          'note': _number('INV', now),
          'created_at': now.toIso8601String(),
        });
      }
      await txn.update(
        'documents',
        {'status': 'converted', 'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [quotationId],
      );
      await _writeDocumentHistory(
        txn,
        documentId: invoiceId,
        oldStatus: '',
        newStatus: 'issued',
        actor: actor,
        reason: 'Converted from document $quotationId',
      );
      await _writeDocumentHistory(
        txn,
        documentId: quotationId,
        oldStatus: source['status'] as String,
        newStatus: 'converted',
        actor: actor,
        reason: 'Converted to invoice $invoiceId',
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'quotation.converted_to_invoice',
        entityType: 'document',
        entityId: '$quotationId',
        newValues: {'invoice_id': invoiceId},
      );
      return invoiceId;
    });
  }

  Future<void> recordDocumentPayment({
    required StaffUser actor,
    required int documentId,
    required double amount,
    required String paymentMethod,
    required String reference,
    int? cashSessionId,
    String? transactionReference,
  }) async {
    _require(actor, CommercialPermission.debtPayment);
    final normalizedAmount = MoneyMath.round(amount);
    if (normalizedAmount <= 0) {
      throw ArgumentError('Payment must be greater than zero.');
    }
    if (paymentMethod == 'Cash' && cashSessionId == null) {
      throw StateError('Open a cash-register session before receiving cash.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      if (cashSessionId != null) {
        await _requireOpenCashSession(txn, cashSessionId, actor);
      }
      final rows = await txn.query(
        'documents',
        where: 'id = ? AND branch_id = ? AND document_type = ?',
        whereArgs: [documentId, actor.branchId, 'invoice'],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Invoice was not found.');
      final invoice = rows.first;
      final oldStatus = invoice['status'] as String;
      if ({'draft', 'cancelled', 'converted'}.contains(oldStatus)) {
        throw StateError('This invoice cannot accept payments.');
      }
      final balance = MoneyMath.round(
        (invoice['balance_due'] as num? ?? 0).toDouble(),
      );
      if (normalizedAmount > balance) {
        throw StateError('Payment cannot exceed the outstanding balance.');
      }
      final now = DateTime.now();
      final transactionRef = transactionReference?.trim().isNotEmpty == true
          ? transactionReference!.trim()
          : _number('PAY', now);
      final duplicate =
          firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM document_payments '
              'WHERE transaction_ref = ?',
              [transactionRef],
            ),
          ) ??
          0;
      if (duplicate > 0) {
        throw StateError('This payment reference has already been processed.');
      }
      final paymentId = await txn.insert('document_payments', {
        'document_id': documentId,
        'branch_id': actor.branchId,
        'user_id': actor.id,
        'cash_session_id': cashSessionId,
        'amount': normalizedAmount,
        'payment_method': paymentMethod,
        'reference': reference.trim(),
        'transaction_ref': transactionRef,
        'created_at': now.toIso8601String(),
      });
      final nextBalance = MoneyMath.clampNonNegative(
        balance - normalizedAmount,
      );
      final nextStatus = nextBalance == 0 ? 'paid' : 'part_paid';
      await txn.update(
        'documents',
        {
          'amount_paid': MoneyMath.add([
            (invoice['amount_paid'] as num? ?? 0).toDouble(),
            normalizedAmount,
          ]),
          'balance_due': nextBalance,
          'status': nextStatus,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [documentId],
      );
      final customerId = invoice['customer_id'] as int?;
      final debtPosted = (invoice['debt_posted'] as num? ?? 0).toInt() == 1;
      if (customerId != null && debtPosted) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = MAX(0, balance - ?) '
          'WHERE id = ? AND branch_id = ?',
          [normalizedAmount, customerId, actor.branchId],
        );
        await txn.insert('customer_transactions', {
          'customer_id': customerId,
          'branch_id': actor.branchId,
          'user_id': actor.id,
          'transaction_type': 'invoice_payment',
          'amount': -normalizedAmount,
          'reference_type': 'document_payment',
          'reference_id': paymentId,
          'transaction_ref': 'customer-$transactionRef',
          'note': invoice['document_no'],
          'created_at': now.toIso8601String(),
        });
      }
      if (paymentMethod == 'Cash' && cashSessionId != null) {
        await txn.insert('cash_movements', {
          'cash_session_id': cashSessionId,
          'user_id': actor.id,
          'movement_type': 'invoice_payment',
          'amount': normalizedAmount,
          'reference_type': 'document_payment',
          'reference_id': paymentId,
          'transaction_ref': 'cash-$transactionRef',
          'note': invoice['document_no'],
          'created_at': now.toIso8601String(),
        });
      }
      if (oldStatus != nextStatus) {
        await _writeDocumentHistory(
          txn,
          documentId: documentId,
          oldStatus: oldStatus,
          newStatus: nextStatus,
          actor: actor,
          reason: 'Payment $transactionRef',
        );
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'invoice.payment_recorded',
        entityType: 'document',
        entityId: '$documentId',
        newValues: {
          'amount': normalizedAmount,
          'balance_due': nextBalance,
          'transaction_ref': transactionRef,
        },
      );
    });
  }

  Future<String> convertDocumentToSale({
    required StaffUser actor,
    required int documentId,
    required String paymentMethod,
    int? cashSessionId,
  }) async {
    _require(actor, CommercialPermission.salesProcess);
    final db = await _database.database;
    return db.transaction((txn) async {
      final documents = await txn.query(
        'documents',
        where: 'id = ? AND branch_id = ?',
        whereArgs: [documentId, actor.branchId],
        limit: 1,
      );
      if (documents.isEmpty) throw StateError('Document was not found.');
      final document = documents.first;
      if (document['converted_sale_id'] != null ||
          document['status'] == 'converted') {
        throw StateError('This document has already been converted.');
      }
      if (paymentMethod == 'Cash' && cashSessionId == null) {
        throw StateError('Open a cash-register session before a cash sale.');
      }
      if (cashSessionId != null) {
        await _requireOpenCashSession(txn, cashSessionId, actor);
      }
      final items = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
      if (items.isEmpty) throw StateError('The document has no items.');
      for (final item in items) {
        final productId = item['product_id'] as int?;
        if (productId == null) continue;
        final stock = await txn.query(
          'branch_inventory',
          columns: ['stock_qty'],
          where: 'branch_id = ? AND product_id = ?',
          whereArgs: [actor.branchId, productId],
          limit: 1,
        );
        final available = stock.isEmpty
            ? 0.0
            : (stock.first['stock_qty'] as num).toDouble();
        final needed = (item['quantity'] as num).toDouble();
        if (available < needed) {
          throw StateError('Insufficient stock for ${item['description']}.');
        }
      }

      final total = MoneyMath.round(
        (document['total'] as num? ?? 0).toDouble(),
      );
      final priorPaid = MoneyMath.round(
        (document['amount_paid'] as num? ?? 0).toDouble(),
      );
      final directCredit = paymentMethod == 'Credit';
      final amountPaid = document['document_type'] == 'invoice'
          ? priorPaid
          : (directCredit ? 0.0 : total);
      final balanceDue = MoneyMath.clampNonNegative(total - amountPaid);
      final customerId = document['customer_id'] as int?;
      final debtAlreadyPosted =
          (document['debt_posted'] as num? ?? 0).toInt() == 1;
      if (balanceDue > 0 && customerId == null) {
        throw StateError('A customer is required for a credit balance.');
      }
      if (balanceDue > 0 && customerId != null && !debtAlreadyPosted) {
        await _enforceCreditLimit(
          txn,
          branchId: actor.branchId,
          customerId: customerId,
          additionalDebt: balanceDue,
        );
      }
      final now = DateTime.now();
      final invoiceNo = _number('ABM', now);
      final saleId = await txn.insert('sales', {
        'invoice_no': invoiceNo,
        'subtotal': document['subtotal'],
        'discount': document['discount'],
        'total': total,
        'payment_method': balanceDue > 0 ? 'Credit' : paymentMethod,
        'customer_id': document['customer_id'],
        'branch_id': actor.branchId,
        'user_id': actor.id,
        'cash_session_id': cashSessionId,
        'status': 'completed',
        'amount_paid': amountPaid,
        'balance_due': balanceDue,
        'source_document_id': documentId,
        'created_at': now.toIso8601String(),
      });
      for (final item in items) {
        final productId = item['product_id'] as int?;
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': productId,
          'product_name': item['description'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'cost_price': item['cost_price'],
          'total': MoneyMath.round(
            (item['line_total'] as num? ??
                    ((item['quantity'] as num).toDouble() *
                        (item['unit_price'] as num).toDouble()))
                .toDouble(),
          ),
        });
        if (productId != null) {
          await txn.rawUpdate(
            'UPDATE branch_inventory SET stock_qty = stock_qty - ?, updated_at = ? WHERE branch_id = ? AND product_id = ?',
            [
              item['quantity'],
              now.toIso8601String(),
              actor.branchId,
              productId,
            ],
          );
          if (actor.branchId == DatabaseService.defaultBranchId) {
            await txn.rawUpdate(
              'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
              [item['quantity'], productId],
            );
          }
        }
      }
      if (balanceDue > 0 && customerId != null && !debtAlreadyPosted) {
        await txn.rawUpdate(
          'UPDATE customers SET balance = balance + ? WHERE id = ? AND branch_id = ?',
          [balanceDue, customerId, actor.branchId],
        );
        await txn.insert('customer_transactions', {
          'customer_id': customerId,
          'branch_id': actor.branchId,
          'user_id': actor.id,
          'transaction_type': 'credit_sale',
          'amount': balanceDue,
          'reference_type': 'sale',
          'reference_id': saleId,
          'transaction_ref': 'credit-sale-$saleId',
          'note': invoiceNo,
          'created_at': now.toIso8601String(),
        });
      }
      if (document['document_type'] != 'invoice' &&
          paymentMethod == 'Cash' &&
          cashSessionId != null) {
        await txn.insert('cash_movements', {
          'cash_session_id': cashSessionId,
          'user_id': actor.id,
          'movement_type': 'sale',
          'amount': total,
          'reference_type': 'sale',
          'reference_id': saleId,
          'transaction_ref': 'cash-sale-$saleId',
          'note': invoiceNo,
          'created_at': now.toIso8601String(),
        });
      }
      final updated = await txn.update(
        'documents',
        {
          'status': 'converted',
          'converted_sale_id': saleId,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ? AND converted_sale_id IS NULL',
        whereArgs: [documentId],
      );
      if (updated != 1) {
        throw StateError('This document was converted by another operation.');
      }
      await _writeDocumentHistory(
        txn,
        documentId: documentId,
        oldStatus: document['status'] as String,
        newStatus: 'converted',
        actor: actor,
        reason: 'Converted to sale $invoiceNo',
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'document.converted_to_sale',
        entityType: 'document',
        entityId: '$documentId',
        newValues: {'sale_id': saleId, 'invoice_no': invoiceNo},
      );
      return invoiceNo;
    });
  }

  Future<int> createPurchaseOrder({
    required StaffUser actor,
    required int supplierId,
    required List<Map<String, Object?>> items,
    String notes = '',
    DateTime? expectedAt,
  }) async {
    _require(actor, CommercialPermission.purchasingManage);
    if (items.isEmpty) throw ArgumentError('Add at least one purchase item.');
    final db = await _database.database;
    return db.transaction((txn) async {
      final supplier = await txn.query(
        'suppliers',
        where: 'id = ? AND branch_id = ?',
        whereArgs: [supplierId, actor.branchId],
        limit: 1,
      );
      if (supplier.isEmpty) throw StateError('Supplier was not found.');
      var subtotal = 0.0;
      var tax = 0.0;
      for (final item in items) {
        final qty = (item['quantity'] as num).toDouble();
        final cost = (item['unit_cost'] as num).toDouble();
        final taxRate = (item['tax_rate'] as num? ?? 0).toDouble();
        if (qty <= 0 || cost < 0) throw ArgumentError('Invalid purchase item.');
        subtotal += qty * cost;
        tax += qty * cost * taxRate / 100;
      }
      final now = DateTime.now();
      final id = await txn.insert('purchase_orders', {
        'branch_id': actor.branchId,
        'supplier_id': supplierId,
        'po_no': _number('PO', now),
        'status': 'draft',
        'subtotal': subtotal,
        'tax': tax,
        'total': subtotal + tax,
        'amount_paid': 0,
        'received_value': 0,
        'balance_due': 0,
        'notes': notes.trim(),
        'expected_at': expectedAt?.toIso8601String(),
        'created_by': actor.id,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      for (final item in items) {
        final qty = (item['quantity'] as num).toDouble();
        final cost = (item['unit_cost'] as num).toDouble();
        final taxRate = (item['tax_rate'] as num? ?? 0).toDouble();
        await txn.insert('purchase_order_items', {
          'purchase_order_id': id,
          'product_id': item['product_id'],
          'description': item['description'],
          'ordered_qty': qty,
          'received_qty': 0,
          'unit_cost': cost,
          'tax_rate': taxRate,
          'line_total': qty * cost * (1 + taxRate / 100),
        });
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'purchase_order.created',
        entityType: 'purchase_order',
        entityId: '$id',
        newValues: {'supplier_id': supplierId, 'total': subtotal + tax},
      );
      return id;
    });
  }

  Future<List<Map<String, Object?>>> listPurchaseOrders(StaffUser actor) async {
    _require(actor, CommercialPermission.purchasingManage);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT po.*, s.name AS supplier_name
      FROM purchase_orders po
      INNER JOIN suppliers s ON s.id = po.supplier_id
      WHERE po.branch_id = ?
      ORDER BY po.created_at DESC
    ''',
      [actor.branchId],
    );
  }

  Future<List<Map<String, Object?>>> purchaseOrderItems({
    required StaffUser actor,
    required int purchaseOrderId,
  }) async {
    _require(actor, CommercialPermission.purchasingManage);
    final db = await _database.database;
    final order = await db.query(
      'purchase_orders',
      columns: ['id'],
      where: 'id = ? AND branch_id = ?',
      whereArgs: [purchaseOrderId, actor.branchId],
      limit: 1,
    );
    if (order.isEmpty) throw StateError('Purchase order was not found.');
    return db.rawQuery(
      '''
      SELECT poi.*, p.name AS product_name, p.sku, p.barcode
      FROM purchase_order_items poi
      INNER JOIN products p ON p.id = poi.product_id
      WHERE poi.purchase_order_id = ?
      ORDER BY poi.id
    ''',
      [purchaseOrderId],
    );
  }

  Future<String> receivePurchaseOrder({
    required StaffUser actor,
    required int purchaseOrderId,
    required Map<int, double> quantitiesByItemId,
    String notes = '',
    String? transactionRef,
  }) async {
    _require(actor, CommercialPermission.purchasingManage);
    if (quantitiesByItemId.isEmpty) {
      throw ArgumentError('Enter at least one received quantity.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      final orders = await txn.query(
        'purchase_orders',
        where: 'id = ? AND branch_id = ?',
        whereArgs: [purchaseOrderId, actor.branchId],
        limit: 1,
      );
      if (orders.isEmpty) throw StateError('Purchase order was not found.');
      final order = orders.first;
      if (order['status'] == 'received' || order['status'] == 'cancelled') {
        throw StateError('This purchase order cannot receive more stock.');
      }
      final now = DateTime.now();
      final receiptNo = _number('GRN', now);
      final effectiveRef = transactionRef?.trim().isNotEmpty == true
          ? transactionRef!.trim()
          : 'goods-receipt-$purchaseOrderId-${now.microsecondsSinceEpoch}';
      final receiptId = await txn.insert('goods_receipts', {
        'purchase_order_id': purchaseOrderId,
        'receipt_no': receiptNo,
        'branch_id': actor.branchId,
        'received_by': actor.id,
        'received_at': now.toIso8601String(),
        'notes': notes.trim(),
        'transaction_ref': effectiveRef,
      });
      var receivedValue = 0.0;
      for (final entry in quantitiesByItemId.entries) {
        final rows = await txn.query(
          'purchase_order_items',
          where: 'id = ? AND purchase_order_id = ?',
          whereArgs: [entry.key, purchaseOrderId],
          limit: 1,
        );
        if (rows.isEmpty) throw StateError('Purchase item was not found.');
        final item = rows.first;
        final ordered = (item['ordered_qty'] as num).toDouble();
        final received = (item['received_qty'] as num).toDouble();
        final quantity = entry.value;
        if (quantity <= 0 || received + quantity > ordered + 0.001) {
          throw StateError('Received quantity exceeds the outstanding order.');
        }
        final unitCost = (item['unit_cost'] as num).toDouble();
        final taxRate = (item['tax_rate'] as num? ?? 0).toDouble();
        receivedValue += quantity * unitCost * (1 + taxRate / 100);
        await txn.update(
          'purchase_order_items',
          {'received_qty': received + quantity},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
        await _increaseBranchStock(
          txn,
          branchId: actor.branchId,
          productId: item['product_id'] as int,
          quantity: quantity,
        );
        await txn.insert('goods_receipt_items', {
          'goods_receipt_id': receiptId,
          'purchase_order_item_id': entry.key,
          'product_id': item['product_id'],
          'quantity_received': quantity,
          'unit_cost': unitCost,
          'line_value': MoneyMath.round(
            quantity * unitCost * (1 + taxRate / 100),
          ),
        });
      }
      final totals = await txn.rawQuery(
        '''
        SELECT SUM(CASE WHEN received_qty < ordered_qty THEN 1 ELSE 0 END) AS open_lines
        FROM purchase_order_items WHERE purchase_order_id = ?
      ''',
        [purchaseOrderId],
      );
      final openLines = (totals.first['open_lines'] as num? ?? 0).toInt();
      final previousReceived = (order['received_value'] as num? ?? 0)
          .toDouble();
      final paid = (order['amount_paid'] as num? ?? 0).toDouble();
      final oldOutstanding = max(0, previousReceived - paid).toDouble();
      final nextReceived = previousReceived + receivedValue;
      final newOutstanding = max(0, nextReceived - paid).toDouble();
      final balanceIncrease = newOutstanding - oldOutstanding;
      await txn.update(
        'purchase_orders',
        {
          'received_value': nextReceived,
          'balance_due': newOutstanding,
          'status': openLines == 0 ? 'received' : 'part_received',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [purchaseOrderId],
      );
      if (balanceIncrease > 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET balance = balance + ? WHERE id = ? AND branch_id = ?',
          [balanceIncrease, order['supplier_id'], actor.branchId],
        );
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'purchase_order.received',
        entityType: 'purchase_order',
        entityId: '$purchaseOrderId',
        newValues: {
          'receipt_no': receiptNo,
          'received_value': receivedValue,
          'status': openLines == 0 ? 'received' : 'part_received',
          'transaction_ref': effectiveRef,
        },
      );
      return receiptNo;
    });
  }

  Future<void> recordSupplierPayment({
    required StaffUser actor,
    required int supplierId,
    int? purchaseOrderId,
    required double amount,
    required String paymentMethod,
    required String reference,
    int? cashSessionId,
  }) async {
    _require(actor, CommercialPermission.purchasingManage);
    if (amount <= 0) throw ArgumentError('Payment must be greater than zero.');
    if (paymentMethod == 'Cash' && cashSessionId == null) {
      throw StateError('Open a cash-register session before paying cash.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      if (cashSessionId != null) {
        await _requireOpenCashSession(txn, cashSessionId, actor);
      }
      var isDeposit = true;
      var liabilityReduction = 0.0;
      if (purchaseOrderId != null) {
        final rows = await txn.query(
          'purchase_orders',
          where: 'id = ? AND supplier_id = ? AND branch_id = ?',
          whereArgs: [purchaseOrderId, supplierId, actor.branchId],
          limit: 1,
        );
        if (rows.isEmpty) throw StateError('Purchase order was not found.');
        final order = rows.first;
        final previousPaid = (order['amount_paid'] as num? ?? 0).toDouble();
        final receivedValue = (order['received_value'] as num? ?? 0).toDouble();
        final previousOutstanding = max(
          0,
          receivedValue - previousPaid,
        ).toDouble();
        final nextPaid = previousPaid + amount;
        final nextOutstanding = max(0, receivedValue - nextPaid).toDouble();
        liabilityReduction = previousOutstanding - nextOutstanding;
        isDeposit = nextPaid > receivedValue || receivedValue == 0;
        await txn.update(
          'purchase_orders',
          {
            'amount_paid': nextPaid,
            'balance_due': nextOutstanding,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [purchaseOrderId],
        );
      } else {
        final supplier = await txn.query(
          'suppliers',
          columns: ['balance'],
          where: 'id = ? AND branch_id = ?',
          whereArgs: [supplierId, actor.branchId],
          limit: 1,
        );
        if (supplier.isEmpty) throw StateError('Supplier was not found.');
        final balance = (supplier.first['balance'] as num).toDouble();
        liabilityReduction = min(balance, amount).toDouble();
        isDeposit = amount > balance;
      }
      final paymentId = await txn.insert('supplier_payments', {
        'supplier_id': supplierId,
        'purchase_order_id': purchaseOrderId,
        'branch_id': actor.branchId,
        'user_id': actor.id,
        'cash_session_id': cashSessionId,
        'amount': amount,
        'payment_method': paymentMethod,
        'reference': reference.trim(),
        'is_deposit': isDeposit ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (liabilityReduction > 0) {
        await txn.rawUpdate(
          'UPDATE suppliers SET balance = MAX(0, balance - ?) WHERE id = ? AND branch_id = ?',
          [liabilityReduction, supplierId, actor.branchId],
        );
      }
      if (paymentMethod == 'Cash' && cashSessionId != null) {
        await txn.insert('cash_movements', {
          'cash_session_id': cashSessionId,
          'user_id': actor.id,
          'movement_type': 'supplier_payment',
          'amount': -amount,
          'reference_type': 'supplier_payment',
          'reference_id': paymentId,
          'note': reference.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'supplier.payment_recorded',
        entityType: 'supplier',
        entityId: '$supplierId',
        newValues: {
          'amount': amount,
          'liability_reduction': liabilityReduction,
          'is_deposit': isDeposit,
        },
      );
    });
  }

  Future<void> adjustStock({
    required StaffUser actor,
    required int productId,
    required double quantityChange,
    required String reason,
    String note = '',
  }) async {
    _require(actor, CommercialPermission.stockAdjust);
    if (quantityChange == 0)
      throw ArgumentError('Quantity change is required.');
    final db = await _database.database;
    await db.transaction((txn) async {
      final stock = await txn.query(
        'branch_inventory',
        columns: ['stock_qty'],
        where: 'branch_id = ? AND product_id = ?',
        whereArgs: [actor.branchId, productId],
        limit: 1,
      );
      if (stock.isEmpty) throw StateError('Product is not stocked here.');
      final oldQty = (stock.first['stock_qty'] as num).toDouble();
      final newQty = oldQty + quantityChange;
      if (newQty < 0)
        throw StateError('Adjustment would create negative stock.');
      await txn.update(
        'branch_inventory',
        {'stock_qty': newQty, 'updated_at': DateTime.now().toIso8601String()},
        where: 'branch_id = ? AND product_id = ?',
        whereArgs: [actor.branchId, productId],
      );
      if (actor.branchId == DatabaseService.defaultBranchId) {
        await txn.update(
          'products',
          {'stock_qty': newQty},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }
      final adjustmentId = await txn.insert('stock_adjustments', {
        'branch_id': actor.branchId,
        'product_id': productId,
        'user_id': actor.id,
        'quantity_change': quantityChange,
        'reason': reason,
        'note': note.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock.adjusted',
        entityType: 'product',
        entityId: '$productId',
        oldValues: {'stock_qty': oldQty},
        newValues: {
          'stock_qty': newQty,
          'reason': reason,
          'adjustment_id': adjustmentId,
        },
        reason: note,
      );
    });
  }

  Future<int> startStockCount({
    required StaffUser actor,
    String notes = '',
  }) async {
    _require(actor, CommercialPermission.stockCount);
    final db = await _database.database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final id = await txn.insert('stock_counts', {
        'branch_id': actor.branchId,
        'count_no': _number('COUNT', now),
        'status': 'draft',
        'started_by': actor.id,
        'started_at': now.toIso8601String(),
        'notes': notes.trim(),
      });
      await txn.execute(
        '''
        INSERT INTO stock_count_items
          (stock_count_id, product_id, expected_qty, counted_qty, posted)
        SELECT ?, product_id, stock_qty, NULL, 0
        FROM branch_inventory WHERE branch_id = ?
      ''',
        [id, actor.branchId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_count.started',
        entityType: 'stock_count',
        entityId: '$id',
      );
      return id;
    });
  }

  Future<void> saveStockCountQuantity({
    required StaffUser actor,
    required int stockCountId,
    required int productId,
    required double countedQuantity,
  }) async {
    _require(actor, CommercialPermission.stockCount);
    if (countedQuantity < 0) throw ArgumentError('Count cannot be negative.');
    final db = await _database.database;
    final changed = await db.rawUpdate(
      '''
      UPDATE stock_count_items SET counted_qty = ?
      WHERE stock_count_id = ? AND product_id = ? AND posted = 0
        AND EXISTS (
          SELECT 1 FROM stock_counts sc
          WHERE sc.id = stock_count_id AND sc.branch_id = ? AND sc.status = 'draft'
        )
    ''',
      [countedQuantity, stockCountId, productId, actor.branchId],
    );
    if (changed != 1) throw StateError('Stock-count item cannot be updated.');
  }

  Future<void> approveStockCount({
    required StaffUser actor,
    required int stockCountId,
  }) async {
    _require(actor, CommercialPermission.stockCount);
    final db = await _database.database;
    await db.transaction((txn) async {
      final counts = await txn.query(
        'stock_counts',
        where: 'id = ? AND branch_id = ? AND status = ?',
        whereArgs: [stockCountId, actor.branchId, 'draft'],
        limit: 1,
      );
      if (counts.isEmpty)
        throw StateError('Stock count is not awaiting approval.');
      final missing =
          firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM stock_count_items WHERE stock_count_id = ? AND counted_qty IS NULL',
              [stockCountId],
            ),
          ) ??
          0;
      if (missing > 0)
        throw StateError('$missing products have not been counted.');
      final items = await txn.query(
        'stock_count_items',
        where: 'stock_count_id = ? AND posted = 0',
        whereArgs: [stockCountId],
      );
      for (final item in items) {
        final counted = (item['counted_qty'] as num).toDouble();
        final expected = (item['expected_qty'] as num).toDouble();
        final productId = item['product_id'] as int;
        await txn.update(
          'branch_inventory',
          {
            'stock_qty': counted,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'branch_id = ? AND product_id = ?',
          whereArgs: [actor.branchId, productId],
        );
        if (actor.branchId == DatabaseService.defaultBranchId) {
          await txn.update(
            'products',
            {'stock_qty': counted},
            where: 'id = ?',
            whereArgs: [productId],
          );
        }
        if ((counted - expected).abs() > 0.0001) {
          await txn.insert('stock_adjustments', {
            'branch_id': actor.branchId,
            'product_id': productId,
            'user_id': actor.id,
            'quantity_change': counted - expected,
            'reason': 'Stock count',
            'note': 'Approved count $stockCountId',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
      await txn.update(
        'stock_count_items',
        {'posted': 1},
        where: 'stock_count_id = ?',
        whereArgs: [stockCountId],
      );
      await txn.update(
        'stock_counts',
        {
          'status': 'approved',
          'approved_by': actor.id,
          'approved_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [stockCountId],
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_count.approved',
        entityType: 'stock_count',
        entityId: '$stockCountId',
      );
    });
  }

  Future<String> createReturn({
    required StaffUser actor,
    required int saleId,
    required Map<int, double> quantitiesBySaleItemId,
    required String reason,
    required String refundMethod,
    required bool restock,
    int? cashSessionId,
  }) async {
    _require(actor, CommercialPermission.salesRefund);
    if (quantitiesBySaleItemId.isEmpty) {
      throw ArgumentError('Select at least one item to return.');
    }
    if (refundMethod == 'Cash' && cashSessionId == null) {
      throw StateError('Open a cash-register session before a cash refund.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      if (cashSessionId != null) {
        await _requireOpenCashSession(txn, cashSessionId, actor);
      }
      final sales = await txn.query(
        'sales',
        where: 'id = ? AND branch_id = ?',
        whereArgs: [saleId, actor.branchId],
        limit: 1,
      );
      if (sales.isEmpty) throw StateError('Sale was not found.');
      final sale = sales.first;
      var total = 0.0;
      final validated = <Map<String, Object?>>[];
      for (final entry in quantitiesBySaleItemId.entries) {
        final items = await txn.query(
          'sale_items',
          where: 'id = ? AND sale_id = ?',
          whereArgs: [entry.key, saleId],
          limit: 1,
        );
        if (items.isEmpty) throw StateError('Sale item was not found.');
        final item = items.first;
        final returnedRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(ri.quantity), 0) AS value
          FROM return_items ri
          INNER JOIN returns r ON r.id = ri.return_id
          WHERE ri.sale_item_id = ?
        ''',
          [entry.key],
        );
        final alreadyReturned = (returnedRows.first['value'] as num? ?? 0)
            .toDouble();
        final sold = (item['quantity'] as num).toDouble();
        if (entry.value <= 0 || alreadyReturned + entry.value > sold + 0.001) {
          throw StateError('Return quantity exceeds the quantity sold.');
        }
        final lineTotal = entry.value * (item['unit_price'] as num).toDouble();
        total += lineTotal;
        validated.add({
          ...item,
          'return_quantity': entry.value,
          'return_total': lineTotal,
        });
      }
      final now = DateTime.now();
      final returnNo = _number('RET', now);
      final returnId = await txn.insert('returns', {
        'sale_id': saleId,
        'branch_id': actor.branchId,
        'return_no': returnNo,
        'user_id': actor.id,
        'reason': reason.trim(),
        'refund_method': refundMethod,
        'total': total,
        'restock': restock ? 1 : 0,
        'created_at': now.toIso8601String(),
      });
      for (final item in validated) {
        await txn.insert('return_items', {
          'return_id': returnId,
          'sale_item_id': item['id'],
          'product_id': item['product_id'],
          'quantity': item['return_quantity'],
          'unit_price': item['unit_price'],
          'total': item['return_total'],
        });
        if (restock && item['product_id'] != null) {
          await _increaseBranchStock(
            txn,
            branchId: actor.branchId,
            productId: item['product_id'] as int,
            quantity: item['return_quantity'] as double,
          );
        }
      }
      final refundId = await txn.insert('refunds', {
        'return_id': returnId,
        'branch_id': actor.branchId,
        'user_id': actor.id,
        'cash_session_id': cashSessionId,
        'amount': total,
        'method': refundMethod,
        'created_at': now.toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE sales SET returned_total = returned_total + ? WHERE id = ?',
        [total, saleId],
      );
      final balanceDue = (sale['balance_due'] as num? ?? 0).toDouble();
      final customerId = sale['customer_id'] as int?;
      if (customerId != null && balanceDue > 0) {
        final debtReduction = min(balanceDue, total).toDouble();
        await txn.rawUpdate(
          'UPDATE sales SET balance_due = MAX(0, balance_due - ?) WHERE id = ?',
          [debtReduction, saleId],
        );
        await txn.rawUpdate(
          'UPDATE customers SET balance = MAX(0, balance - ?) WHERE id = ? AND branch_id = ?',
          [debtReduction, customerId, actor.branchId],
        );
        await txn.insert('customer_transactions', {
          'customer_id': customerId,
          'branch_id': actor.branchId,
          'user_id': actor.id,
          'transaction_type': 'return_credit',
          'amount': -debtReduction,
          'reference_type': 'return',
          'reference_id': returnId,
          'note': returnNo,
          'created_at': now.toIso8601String(),
        });
      }
      if (refundMethod == 'Cash' && cashSessionId != null) {
        await txn.insert('cash_movements', {
          'cash_session_id': cashSessionId,
          'user_id': actor.id,
          'movement_type': 'refund',
          'amount': -total,
          'reference_type': 'refund',
          'reference_id': refundId,
          'note': returnNo,
          'created_at': now.toIso8601String(),
        });
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'sale.returned',
        entityType: 'sale',
        entityId: '$saleId',
        newValues: {'return_no': returnNo, 'total': total, 'restock': restock},
        reason: reason,
      );
      return returnNo;
    });
  }

  Future<int> createRecurringExpense({
    required StaffUser actor,
    required String title,
    required String category,
    required double amount,
    required String paymentMethod,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    bool automaticPosting = false,
    int reminderDays = 3,
    String payee = '',
    String note = '',
  }) async {
    _require(actor, CommercialPermission.expensesManage);
    if (amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    final db = await _database.database;
    final id = await db.insert('recurring_expenses', {
      'branch_id': actor.branchId,
      'title': title.trim(),
      'category': category.trim(),
      'amount': amount,
      'payment_method': paymentMethod,
      'frequency': frequency,
      'interval_count': 1,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'next_due_at': startDate.toIso8601String(),
      'reminder_days': reminderDays,
      'automatic_posting': automaticPosting ? 1 : 0,
      'payee': payee.trim(),
      'note': note.trim(),
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    await logAudit(
      actor: actor,
      action: 'recurring_expense.created',
      entityType: 'recurring_expense',
      entityId: '$id',
      newValues: {
        'title': title.trim(),
        'amount': amount,
        'frequency': frequency,
      },
    );
    return id;
  }

  Future<int> processDueRecurringExpenses({
    required StaffUser actor,
    DateTime? now,
  }) async {
    _require(actor, CommercialPermission.expensesManage);
    final current = now ?? DateTime.now();
    final db = await _database.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'recurring_expenses',
        where: 'branch_id = ? AND is_active = 1 AND next_due_at <= ?',
        whereArgs: [actor.branchId, current.toIso8601String()],
      );
      var posted = 0;
      for (final row in rows) {
        final due = DateTime.parse(row['next_due_at'] as String);
        final end = row['end_date'] == null
            ? null
            : DateTime.tryParse(row['end_date'] as String);
        if (end != null && due.isAfter(end)) {
          await txn.update(
            'recurring_expenses',
            {'is_active': 0},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          continue;
        }
        final automatic = (row['automatic_posting'] as num? ?? 0).toInt() == 1;
        if (automatic && row['payment_method'] != 'Cash') {
          await txn.insert('expenses', {
            'title': row['title'],
            'category': row['category'],
            'amount': row['amount'],
            'note': row['note'],
            'branch_id': actor.branchId,
            'user_id': actor.id,
            'recurring_expense_id': row['id'],
            'payment_method': row['payment_method'],
            'created_at': due.toIso8601String(),
          });
          posted++;
        } else {
          await txn.insert('reminders', {
            'branch_id': actor.branchId,
            'reminder_type': 'recurring_expense',
            'title': row['title'],
            'message': 'Recurring expense due: ${row['title']}',
            'due_at': due.toIso8601String(),
            'reference_type': 'recurring_expense',
            'reference_id': row['id'],
            'created_at': current.toIso8601String(),
          });
        }
        final next = nextRecurringDate(
          due,
          row['frequency'] as String,
          interval: (row['interval_count'] as num? ?? 1).toInt(),
        );
        await txn.update(
          'recurring_expenses',
          {
            'next_due_at': next.toIso8601String(),
            'last_posted_at': automatic ? current.toIso8601String() : null,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      return posted;
    });
  }

  Future<int> createStockTransfer({
    required StaffUser actor,
    required int destinationBranchId,
    required Map<int, double> quantitiesByProductId,
    String notes = '',
  }) async {
    _require(actor, CommercialPermission.stockAdjust);
    if (destinationBranchId == actor.branchId) {
      throw ArgumentError('Source and destination branches must differ.');
    }
    if (quantitiesByProductId.isEmpty) {
      throw ArgumentError('Add at least one product to the transfer.');
    }
    final db = await _database.database;
    return db.transaction((txn) async {
      final destination = await txn.query(
        'branches',
        columns: ['id'],
        where: 'id = ? AND is_active = 1',
        whereArgs: [destinationBranchId],
        limit: 1,
      );
      if (destination.isEmpty) {
        throw StateError('Destination branch was not found or is inactive.');
      }
      final now = DateTime.now();
      final id = await txn.insert('stock_transfers', {
        'transfer_no': _number('TRF', now),
        'source_branch_id': actor.branchId,
        'destination_branch_id': destinationBranchId,
        'status': 'draft',
        'created_by': actor.id,
        'notes': notes.trim(),
        'created_at': now.toIso8601String(),
      });
      for (final entry in quantitiesByProductId.entries) {
        if (entry.value <= 0) {
          throw ArgumentError('Transfer quantity must be positive.');
        }
        final products = await txn.query(
          'products',
          columns: ['id'],
          where: 'id = ? AND is_active = 1',
          whereArgs: [entry.key],
          limit: 1,
        );
        if (products.isEmpty) {
          throw StateError(
            'A selected transfer product is inactive or missing.',
          );
        }
        await txn.insert('stock_transfer_items', {
          'transfer_id': id,
          'product_id': entry.key,
          'quantity': entry.value,
          'dispatched_quantity': 0,
          'received_quantity': 0,
          'damaged_quantity': 0,
          'missing_quantity': 0,
          'excess_quantity': 0,
        });
      }
      await _writeTransferHistory(
        txn,
        transferId: id,
        oldStatus: '',
        newStatus: 'draft',
        actor: actor,
        reason: notes,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_transfer.created',
        entityType: 'stock_transfer',
        entityId: '$id',
        newValues: {
          'destination_branch_id': destinationBranchId,
          'items': quantitiesByProductId,
        },
      );
      return id;
    });
  }

  Future<void> approveStockTransfer({
    required StaffUser actor,
    required int transferId,
    String reason = '',
  }) async {
    _require(actor, CommercialPermission.stockTransferApprove);
    final db = await _database.database;
    await db.transaction((txn) async {
      final transfers = await txn.query(
        'stock_transfers',
        where: 'id = ? AND source_branch_id = ? AND status = ?',
        whereArgs: [transferId, actor.branchId, 'draft'],
        limit: 1,
      );
      if (transfers.isEmpty) {
        throw StateError(
          'Only a draft transfer in this branch can be approved.',
        );
      }
      final items = await txn.query(
        'stock_transfer_items',
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );
      if (items.isEmpty) throw StateError('The transfer contains no products.');
      for (final item in items) {
        final available = await _branchStock(
          txn,
          branchId: actor.branchId,
          productId: item['product_id'] as int,
        );
        final requested = (item['quantity'] as num).toDouble();
        if (available + 0.000001 < requested) {
          throw StateError(
            'Insufficient stock to approve this transfer. '
            'Product ${item['product_id']} has $available available.',
          );
        }
      }
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'stock_transfers',
        {'status': 'approved', 'approved_by': actor.id, 'approved_at': now},
        where: 'id = ?',
        whereArgs: [transferId],
      );
      await _writeTransferHistory(
        txn,
        transferId: transferId,
        oldStatus: 'draft',
        newStatus: 'approved',
        actor: actor,
        reason: reason,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_transfer.approved',
        entityType: 'stock_transfer',
        entityId: '$transferId',
        reason: reason.trim(),
      );
    });
  }

  Future<void> rejectStockTransfer({
    required StaffUser actor,
    required int transferId,
    required String reason,
  }) async {
    _require(actor, CommercialPermission.stockTransferApprove);
    if (reason.trim().isEmpty) {
      throw ArgumentError('A rejection reason is required.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'stock_transfers',
        columns: ['status', 'source_branch_id', 'destination_branch_id'],
        where:
            'id = ? AND status IN (?, ?) '
            'AND (source_branch_id = ? OR destination_branch_id = ?)',
        whereArgs: [
          transferId,
          'draft',
          'approved',
          actor.branchId,
          actor.branchId,
        ],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('This transfer cannot be rejected.');
      }
      final oldStatus = rows.first['status'] as String;
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'stock_transfers',
        {
          'status': 'rejected',
          'rejected_by': actor.id,
          'rejected_at': now,
          'rejection_reason': reason.trim(),
        },
        where: 'id = ?',
        whereArgs: [transferId],
      );
      await _writeTransferHistory(
        txn,
        transferId: transferId,
        oldStatus: oldStatus,
        newStatus: 'rejected',
        actor: actor,
        reason: reason,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_transfer.rejected',
        entityType: 'stock_transfer',
        entityId: '$transferId',
        reason: reason.trim(),
      );
    });
  }

  Future<void> cancelStockTransfer({
    required StaffUser actor,
    required int transferId,
    required String reason,
  }) async {
    _require(actor, CommercialPermission.stockTransferApprove);
    if (reason.trim().isEmpty) {
      throw ArgumentError('A cancellation reason is required.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'stock_transfers',
        columns: ['status'],
        where: 'id = ? AND source_branch_id = ? AND status IN (?, ?)',
        whereArgs: [transferId, actor.branchId, 'draft', 'approved'],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Only a draft or approved transfer can be cancelled.');
      }
      final oldStatus = rows.first['status'] as String;
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'stock_transfers',
        {
          'status': 'cancelled',
          'cancelled_by': actor.id,
          'cancelled_at': now,
          'cancellation_reason': reason.trim(),
        },
        where: 'id = ?',
        whereArgs: [transferId],
      );
      await _writeTransferHistory(
        txn,
        transferId: transferId,
        oldStatus: oldStatus,
        newStatus: 'cancelled',
        actor: actor,
        reason: reason,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_transfer.cancelled',
        entityType: 'stock_transfer',
        entityId: '$transferId',
        reason: reason.trim(),
      );
    });
  }

  Future<void> dispatchStockTransfer({
    required StaffUser actor,
    required int transferId,
    Map<int, double>? dispatchedByProductId,
  }) async {
    _require(actor, CommercialPermission.stockTransferApprove);
    final db = await _database.database;
    await db.transaction((txn) async {
      final transfers = await txn.query(
        'stock_transfers',
        where: 'id = ? AND source_branch_id = ? AND status = ?',
        whereArgs: [transferId, actor.branchId, 'approved'],
        limit: 1,
      );
      if (transfers.isEmpty) {
        throw StateError('The transfer must be approved before dispatch.');
      }
      final items = await txn.query(
        'stock_transfer_items',
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );
      final dispatch = <int, double>{};
      for (final item in items) {
        final productId = item['product_id'] as int;
        final requested = (item['quantity'] as num).toDouble();
        final quantity = dispatchedByProductId?[productId] ?? requested;
        if (quantity <= 0 || quantity > requested + 0.000001) {
          throw StateError(
            'Dispatched quantity must be positive and cannot exceed requested '
            'quantity.',
          );
        }
        final available = await _branchStock(
          txn,
          branchId: actor.branchId,
          productId: productId,
        );
        if (available + 0.000001 < quantity) {
          throw StateError('Insufficient stock for transfer dispatch.');
        }
        dispatch[productId] = quantity;
      }
      final now = DateTime.now().toIso8601String();
      for (final item in items) {
        final productId = item['product_id'] as int;
        final quantity = dispatch[productId]!;
        await txn.rawUpdate(
          'UPDATE branch_inventory '
          'SET stock_qty = stock_qty - ?, updated_at = ? '
          'WHERE branch_id = ? AND product_id = ?',
          [quantity, now, actor.branchId, productId],
        );
        if (actor.branchId == DatabaseService.defaultBranchId) {
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
            [quantity, productId],
          );
        }
        await txn.update(
          'stock_transfer_items',
          {'dispatched_quantity': quantity},
          where: 'id = ?',
          whereArgs: [item['id']],
        );
      }
      await txn.update(
        'stock_transfers',
        {
          'status': 'dispatched',
          'dispatched_by': actor.id,
          'dispatched_at': now,
        },
        where: 'id = ?',
        whereArgs: [transferId],
      );
      await _writeTransferHistory(
        txn,
        transferId: transferId,
        oldStatus: 'approved',
        newStatus: 'dispatched',
        actor: actor,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_transfer.dispatched',
        entityType: 'stock_transfer',
        entityId: '$transferId',
        newValues: {'dispatched_quantities': dispatch},
      );
    });
  }

  Future<void> receiveStockTransfer({
    required StaffUser actor,
    required int transferId,
    Map<int, double>? receivedByProductId,
    Map<int, double>? damagedByProductId,
    Map<int, double>? missingByProductId,
    Map<int, double>? excessByProductId,
    Map<int, String>? discrepancyReasons,
  }) async {
    _require(actor, CommercialPermission.stockTransferReceive);
    final db = await _database.database;
    await db.transaction((txn) async {
      final transfers = await txn.query(
        'stock_transfers',
        where:
            'id = ? AND destination_branch_id = ? '
            'AND status IN (?, ?)',
        whereArgs: [
          transferId,
          actor.branchId,
          'dispatched',
          'partially_received',
        ],
        limit: 1,
      );
      if (transfers.isEmpty) {
        throw StateError('Transfer is not ready to receive.');
      }
      final oldStatus = transfers.first['status'] as String;
      final items = await txn.query(
        'stock_transfer_items',
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );
      if (items.isEmpty) throw StateError('The transfer contains no products.');
      var allAccounted = true;
      final receivedSummary = <int, Map<String, double>>{};
      for (final item in items) {
        final productId = item['product_id'] as int;
        final dispatched =
            (item['dispatched_quantity'] as num? ?? item['quantity'] as num)
                .toDouble();
        final previousReceived = (item['received_quantity'] as num? ?? 0)
            .toDouble();
        final previousDamaged = (item['damaged_quantity'] as num? ?? 0)
            .toDouble();
        final previousMissing = (item['missing_quantity'] as num? ?? 0)
            .toDouble();
        final previousExcess = (item['excess_quantity'] as num? ?? 0)
            .toDouble();

        final remaining = max(
          0,
          dispatched - previousReceived - previousDamaged - previousMissing,
        ).toDouble();
        final received =
            receivedByProductId?[productId] ??
            (receivedByProductId == null ? remaining : 0);
        final damaged = damagedByProductId?[productId] ?? 0;
        final missing = missingByProductId?[productId] ?? 0;
        final excess = excessByProductId?[productId] ?? 0;
        if (received < 0 || damaged < 0 || missing < 0 || excess < 0) {
          throw StateError('Received quantities cannot be negative.');
        }
        if (received + damaged + missing > remaining + 0.000001) {
          throw StateError(
            'Received, damaged and missing quantities exceed the outstanding '
            'dispatched quantity.',
          );
        }
        if ((damaged > 0 || missing > 0 || excess > 0) &&
            (discrepancyReasons?[productId]?.trim().isEmpty ?? true)) {
          throw ArgumentError(
            'A discrepancy reason is required for damaged, missing or excess '
            'stock.',
          );
        }
        if (received + excess > 0) {
          await _increaseBranchStock(
            txn,
            branchId: actor.branchId,
            productId: productId,
            quantity: received + excess,
          );
        }
        final nextReceived = previousReceived + received;
        final nextDamaged = previousDamaged + damaged;
        final nextMissing = previousMissing + missing;
        final nextExcess = previousExcess + excess;
        await txn.update(
          'stock_transfer_items',
          {
            'received_quantity': nextReceived,
            'damaged_quantity': nextDamaged,
            'missing_quantity': nextMissing,
            'excess_quantity': nextExcess,
            'discrepancy_reason':
                discrepancyReasons?[productId]?.trim() ??
                item['discrepancy_reason'],
          },
          where: 'id = ?',
          whereArgs: [item['id']],
        );
        final accounted = nextReceived + nextDamaged + nextMissing;
        if (accounted + 0.000001 < dispatched) allAccounted = false;
        receivedSummary[productId] = {
          'received': received,
          'damaged': damaged,
          'missing': missing,
          'excess': excess,
        };
      }
      final now = DateTime.now().toIso8601String();
      final nextStatus = allAccounted ? 'completed' : 'partially_received';
      await txn.update(
        'stock_transfers',
        {
          'status': nextStatus,
          'received_by': actor.id,
          'received_at': now,
          if (allAccounted) 'completed_at': now,
        },
        where: 'id = ?',
        whereArgs: [transferId],
      );
      await _writeTransferHistory(
        txn,
        transferId: transferId,
        oldStatus: oldStatus,
        newStatus: nextStatus,
        actor: actor,
        reason:
            discrepancyReasons?.values
                .where((value) => value.trim().isNotEmpty)
                .join('; ') ??
            '',
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: allAccounted
            ? 'stock_transfer.completed'
            : 'stock_transfer.partially_received',
        entityType: 'stock_transfer',
        entityId: '$transferId',
        newValues: {'receipt': receivedSummary},
      );
    });
  }

  Future<void> reverseStockTransfer({
    required StaffUser actor,
    required int transferId,
    required String reason,
  }) async {
    _require(actor, CommercialPermission.stockTransferApprove);
    if (reason.trim().isEmpty) {
      throw ArgumentError('A reversal reason is required.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final transfers = await txn.query(
        'stock_transfers',
        where:
            'id = ? AND source_branch_id = ? AND status = ? '
            'AND reversed_at IS NULL',
        whereArgs: [transferId, actor.branchId, 'completed'],
        limit: 1,
      );
      if (transfers.isEmpty) {
        throw StateError(
          'Only a completed, unreversed transfer can be reversed.',
        );
      }
      final destinationBranchId =
          transfers.first['destination_branch_id'] as int;
      final items = await txn.query(
        'stock_transfer_items',
        where: 'transfer_id = ?',
        whereArgs: [transferId],
      );
      for (final item in items) {
        final productId = item['product_id'] as int;
        final saleable =
            (item['received_quantity'] as num? ?? 0).toDouble() +
            (item['excess_quantity'] as num? ?? 0).toDouble();
        final available = await _branchStock(
          txn,
          branchId: destinationBranchId,
          productId: productId,
        );
        if (available + 0.000001 < saleable) {
          throw StateError(
            'Destination stock is too low to reverse this transfer. '
            'Use a documented stock adjustment after reconciling sales.',
          );
        }
      }
      final now = DateTime.now().toIso8601String();
      for (final item in items) {
        final productId = item['product_id'] as int;
        final saleable =
            (item['received_quantity'] as num? ?? 0).toDouble() +
            (item['excess_quantity'] as num? ?? 0).toDouble();
        if (saleable <= 0) continue;
        await txn.rawUpdate(
          'UPDATE branch_inventory '
          'SET stock_qty = stock_qty - ?, updated_at = ? '
          'WHERE branch_id = ? AND product_id = ?',
          [saleable, now, destinationBranchId, productId],
        );
        if (destinationBranchId == DatabaseService.defaultBranchId) {
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = stock_qty - ? WHERE id = ?',
            [saleable, productId],
          );
        }
        await _increaseBranchStock(
          txn,
          branchId: actor.branchId,
          productId: productId,
          quantity: saleable,
        );
        await txn.insert('stock_adjustments', {
          'branch_id': destinationBranchId,
          'product_id': productId,
          'user_id': actor.id,
          'quantity_change': -saleable,
          'reason': 'transfer_reversal',
          'note': reason.trim(),
          'created_at': now,
        });
        await txn.insert('stock_adjustments', {
          'branch_id': actor.branchId,
          'product_id': productId,
          'user_id': actor.id,
          'quantity_change': saleable,
          'reason': 'transfer_reversal',
          'note': reason.trim(),
          'created_at': now,
        });
      }
      await txn.update(
        'stock_transfers',
        {
          'status': 'reversed',
          'reversed_by': actor.id,
          'reversed_at': now,
          'reversal_reason': reason.trim(),
        },
        where: 'id = ?',
        whereArgs: [transferId],
      );
      await _writeTransferHistory(
        txn,
        transferId: transferId,
        oldStatus: 'completed',
        newStatus: 'reversed',
        actor: actor,
        reason: reason,
      );
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'stock_transfer.reversed',
        entityType: 'stock_transfer',
        entityId: '$transferId',
        reason: reason.trim(),
      );
    });
  }

  Future<List<Map<String, Object?>>> stockTransferItems({
    required StaffUser actor,
    required int transferId,
  }) async {
    final db = await _database.database;
    final visible =
        firstIntValue(
          await db.rawQuery(
            '''
      SELECT COUNT(*) FROM stock_transfers
      WHERE id = ? AND (
        source_branch_id = ? OR destination_branch_id = ?
        OR ? IN ('owner', 'manager')
      )
    ''',
            [
              transferId,
              actor.branchId,
              actor.branchId,
              actor.role.databaseValue,
            ],
          ),
        ) ??
        0;
    if (visible == 0) throw StateError('Stock transfer was not found.');
    return db.rawQuery(
      '''
      SELECT sti.*, p.name AS product_name, p.sku, p.barcode, p.unit
      FROM stock_transfer_items sti
      INNER JOIN products p ON p.id = sti.product_id
      WHERE sti.transfer_id = ?
      ORDER BY p.name COLLATE NOCASE
    ''',
      [transferId],
    );
  }

  Future<List<Map<String, Object?>>> stockTransferHistory({
    required StaffUser actor,
    required int transferId,
  }) async {
    await stockTransferItems(actor: actor, transferId: transferId);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT h.*, u.name AS changed_by_name
      FROM stock_transfer_status_history h
      LEFT JOIN users u ON u.id = h.changed_by
      WHERE h.transfer_id = ?
      ORDER BY h.changed_at, h.id
    ''',
      [transferId],
    );
  }

  Future<List<Map<String, Object?>>> listCustomerAccounts(
    StaffUser actor,
  ) async {
    _require(actor, CommercialPermission.debtView);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT c.id, c.name, c.phone, c.email, c.balance,
        c.credit_limit, c.credit_enabled, c.created_at,
        COALESCE(SUM(CASE
          WHEN d.document_type = 'invoice'
            AND d.balance_due > 0
            AND d.due_at IS NOT NULL
            AND d.due_at < ?
          THEN d.balance_due ELSE 0 END), 0) AS overdue_balance,
        MIN(CASE
          WHEN d.document_type = 'invoice' AND d.balance_due > 0
          THEN d.due_at END) AS oldest_due_at
      FROM customers c
      LEFT JOIN documents d
        ON d.customer_id = c.id AND d.branch_id = c.branch_id
      WHERE c.branch_id = ? AND COALESCE(c.is_active, 1) = 1
      GROUP BY c.id
      ORDER BY c.balance DESC, c.name COLLATE NOCASE
    ''',
      [DateTime.now().toIso8601String(), actor.branchId],
    );
  }

  Future<void> setCustomerCredit({
    required StaffUser actor,
    required int customerId,
    required bool enabled,
    required double creditLimit,
    String reason = '',
  }) async {
    _require(actor, CommercialPermission.debtPayment);
    if (creditLimit < 0) {
      throw ArgumentError('Credit limit cannot be negative.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'customers',
        columns: ['credit_limit', 'credit_enabled'],
        where: 'id = ? AND branch_id = ? AND COALESCE(is_active, 1) = 1',
        whereArgs: [customerId, actor.branchId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Customer was not found.');
      final oldValues = Map<String, Object?>.from(rows.first);
      final changed = await txn.update(
        'customers',
        {'credit_limit': creditLimit, 'credit_enabled': enabled ? 1 : 0},
        where: 'id = ? AND branch_id = ?',
        whereArgs: [customerId, actor.branchId],
      );
      if (changed != 1) {
        throw StateError('Customer credit settings were not saved.');
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'customer.credit_updated',
        entityType: 'customer',
        entityId: '$customerId',
        oldValues: oldValues,
        newValues: {'credit_limit': creditLimit, 'credit_enabled': enabled},
        reason: reason,
      );
    });
  }

  Future<List<Map<String, Object?>>> customerTransactions({
    required StaffUser actor,
    required int customerId,
  }) async {
    _require(actor, CommercialPermission.debtView);
    final db = await _database.database;
    final customer = await db.query(
      'customers',
      columns: ['id'],
      where: 'id = ? AND branch_id = ? AND COALESCE(is_active, 1) = 1',
      whereArgs: [customerId, actor.branchId],
      limit: 1,
    );
    if (customer.isEmpty) throw StateError('Customer was not found.');
    return db.query(
      'customer_transactions',
      where: 'customer_id = ? AND branch_id = ?',
      whereArgs: [customerId, actor.branchId],
      orderBy: 'created_at DESC, id DESC',
    );
  }

  Future<void> recordCustomerPayment({
    required StaffUser actor,
    required int customerId,
    required double amount,
    required String paymentMethod,
    String reference = '',
    int? cashSessionId,
  }) async {
    _require(actor, CommercialPermission.debtPayment);
    if (amount <= 0) throw ArgumentError('Payment must be greater than zero.');
    if (paymentMethod == 'Cash' && cashSessionId == null) {
      throw StateError('Open a cash-register session before receiving cash.');
    }
    final db = await _database.database;
    await db.transaction((txn) async {
      if (cashSessionId != null) {
        await _requireOpenCashSession(txn, cashSessionId, actor);
      }
      final rows = await txn.query(
        'customers',
        columns: ['balance', 'name'],
        where: 'id = ? AND branch_id = ? AND COALESCE(is_active, 1) = 1',
        whereArgs: [customerId, actor.branchId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Customer was not found.');
      final balance = (rows.first['balance'] as num? ?? 0).toDouble();
      if (amount > balance + 0.001) {
        throw StateError('Payment cannot exceed the customer balance.');
      }
      final now = DateTime.now().toIso8601String();
      final nextBalance = max(0, balance - amount).toDouble();
      await txn.update(
        'customers',
        {'balance': nextBalance},
        where: 'id = ? AND branch_id = ?',
        whereArgs: [customerId, actor.branchId],
      );
      final transactionId = await txn.insert('customer_transactions', {
        'customer_id': customerId,
        'branch_id': actor.branchId,
        'user_id': actor.id,
        'transaction_type': 'payment',
        'amount': -amount,
        'reference_type': 'customer_payment',
        'note': reference.trim(),
        'created_at': now,
      });
      if (paymentMethod == 'Cash' && cashSessionId != null) {
        await txn.insert('cash_movements', {
          'cash_session_id': cashSessionId,
          'user_id': actor.id,
          'movement_type': 'customer_payment',
          'amount': amount,
          'reference_type': 'customer_transaction',
          'reference_id': transactionId,
          'note': reference.trim().isEmpty
              ? '${rows.first['name']} account payment'
              : reference.trim(),
          'created_at': now,
        });
      }
      await _writeAudit(
        txn,
        userId: actor.id,
        branchId: actor.branchId,
        action: 'customer.payment_recorded',
        entityType: 'customer',
        entityId: '$customerId',
        newValues: {
          'amount': amount,
          'payment_method': paymentMethod,
          'balance': nextBalance,
        },
      );
    });
  }

  Future<List<Map<String, Object?>>> listStockTransfers(StaffUser actor) async {
    _require(actor, CommercialPermission.stockAdjust);
    final db = await _database.database;
    final canSeeAll =
        actor.role == StaffRole.owner || actor.role == StaffRole.manager;
    return db.rawQuery('''
      SELECT st.*, source.name AS source_branch_name,
        destination.name AS destination_branch_name,
        creator.name AS created_by_name
      FROM stock_transfers st
      INNER JOIN branches source ON source.id = st.source_branch_id
      INNER JOIN branches destination ON destination.id = st.destination_branch_id
      LEFT JOIN users creator ON creator.id = st.created_by
      WHERE ${canSeeAll ? '1 = 1' : '(st.source_branch_id = ? OR st.destination_branch_id = ?)'}
      ORDER BY st.created_at DESC, st.id DESC
    ''', canSeeAll ? const <Object?>[] : [actor.branchId, actor.branchId]);
  }

  Future<BusinessHealthSnapshot> businessHealth({
    required StaffUser actor,
    bool consolidated = false,
  }) async {
    _require(actor, CommercialPermission.dashboardView);
    if (consolidated &&
        actor.role != StaffRole.owner &&
        actor.role != StaffRole.manager) {
      throw StateError('Consolidated reporting is not permitted.');
    }
    final db = await _database.database;
    final branchFilter = consolidated ? '' : 'AND branch_id = ?';
    final args = consolidated ? <Object?>[] : <Object?>[actor.branchId];
    final sales = await db.rawQuery(
      'SELECT COALESCE(SUM(total - returned_total), 0) AS revenue, COUNT(*) AS count FROM sales WHERE status = ? $branchFilter',
      ['completed', ...args],
    );
    final gross = await db.rawQuery('''
      SELECT COALESCE(SUM(item_profit), 0) - COALESCE(SUM(discount), 0) AS value
      FROM (
        SELECT s.id,
          SUM((si.unit_price - si.cost_price) * si.quantity) AS item_profit,
          MAX(s.discount) AS discount
        FROM sales s
        INNER JOIN sale_items si ON si.sale_id = s.id
        WHERE s.status = 'completed' ${consolidated ? '' : 'AND s.branch_id = ?'}
        GROUP BY s.id
      ) sale_profit
    ''', args);
    final expenses = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS value FROM expenses WHERE 1 = 1 $branchFilter',
      args,
    );
    final customerDebt = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS value FROM customers WHERE is_active = 1 $branchFilter',
      args,
    );
    final supplierDebt = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) AS value FROM suppliers WHERE is_active = 1 $branchFilter',
      args,
    );
    final stock = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN stock_qty <= low_stock_level THEN 1 ELSE 0 END), 0) AS low
      FROM branch_inventory WHERE 1 = 1 ${consolidated ? '' : 'AND branch_id = ?'}
    ''', args);
    final expiryDate = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String();
    final expiring = await db.rawQuery(
      '''
      SELECT COUNT(*) AS value FROM product_batches
      WHERE quantity > 0 AND expires_at IS NOT NULL AND expires_at <= ?
      ${consolidated ? '' : 'AND branch_id = ?'}
    ''',
      [expiryDate, ...args],
    );
    final refunds = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS value FROM refunds
      WHERE 1 = 1 ${consolidated ? '' : 'AND branch_id = ?'}
    ''', args);
    final variance = await db.rawQuery('''
      SELECT COALESCE(SUM(ABS(variance)), 0) AS value FROM cash_sessions
      WHERE status = 'closed' ${consolidated ? '' : 'AND branch_id = ?'}
    ''', args);

    final revenue = (sales.first['revenue'] as num? ?? 0).toDouble();
    final grossProfit = (gross.first['value'] as num? ?? 0).toDouble();
    final expenseValue = (expenses.first['value'] as num? ?? 0).toDouble();
    final debt = (customerDebt.first['value'] as num? ?? 0).toDouble();
    final supplier = (supplierDebt.first['value'] as num? ?? 0).toDouble();
    final low = (stock.first['low'] as num? ?? 0).toInt();
    final expiringCount = (expiring.first['value'] as num? ?? 0).toInt();
    final refundValue = (refunds.first['value'] as num? ?? 0).toDouble();
    final cashVariance = (variance.first['value'] as num? ?? 0).toDouble();
    final suggestions = <String>[];
    if (low > 0)
      suggestions.add('Reorder $low low-stock product${low == 1 ? '' : 's'}.');
    if (expiringCount > 0) {
      suggestions.add(
        'Review $expiringCount batch${expiringCount == 1 ? '' : 'es'} expiring within 30 days.',
      );
    }
    if (debt > revenue * 0.35 && debt > 0) {
      suggestions.add(
        'Customer debt is high compared with recorded revenue. Follow up overdue accounts.',
      );
    }
    if (supplier > 0)
      suggestions.add(
        'Review unpaid supplier balances before their due dates.',
      );
    if (cashVariance > 0)
      suggestions.add(
        'Investigate closed cash sessions with recorded variances.',
      );
    if (revenue > 0 && refundValue / revenue > 0.05) {
      suggestions.add(
        'Refunds exceed 5% of revenue. Review return reasons and product quality.',
      );
    }
    if (revenue == 0) {
      suggestions.add(
        'More sales history is needed before detailed performance suggestions can be generated.',
      );
    }
    return BusinessHealthSnapshot(
      revenue: revenue,
      grossProfit: grossProfit,
      expenses: expenseValue,
      netProfit: grossProfit - expenseValue,
      customerDebt: debt,
      supplierDebt: supplier,
      lowStockCount: low,
      expiringCount: expiringCount,
      refundRate: revenue == 0 ? 0 : refundValue / revenue,
      cashVariance: cashVariance,
      suggestions: suggestions,
    );
  }

  Future<List<Map<String, Object?>>> lowStockSuggestions(
    StaffUser actor,
  ) async {
    _require(actor, CommercialPermission.reportsView);
    final db = await _database.database;
    return db.rawQuery(
      '''
      SELECT p.id, p.name, p.sku, p.barcode, p.category,
        bi.stock_qty, bi.low_stock_level,
        p.reorder_quantity, p.lead_time_days,
        MAX(bi.low_stock_level + COALESCE(p.reorder_quantity, 0) - bi.stock_qty, 0)
          AS suggested_quantity
      FROM products p
      INNER JOIN branch_inventory bi ON bi.product_id = p.id
      WHERE bi.branch_id = ? AND bi.stock_qty <= bi.low_stock_level
      ORDER BY (bi.low_stock_level - bi.stock_qty) DESC
    ''',
      [actor.branchId],
    );
  }

  Future<void> logAudit({
    required StaffUser actor,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?>? oldValues,
    Map<String, Object?>? newValues,
    String reason = '',
    bool success = true,
  }) async {
    final db = await _database.database;
    await _writeAudit(
      db,
      userId: actor.id,
      branchId: actor.branchId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      oldValues: oldValues,
      newValues: newValues,
      reason: reason,
      success: success,
    );
  }

  static DateTime nextRecurringDate(
    DateTime current,
    String frequency, {
    int interval = 1,
  }) {
    if (interval < 1) throw ArgumentError('Interval must be at least one.');
    return switch (frequency) {
      'daily' => current.add(Duration(days: interval)),
      'weekly' => current.add(Duration(days: 7 * interval)),
      'quarterly' => _addMonthsClamped(current, 3 * interval),
      'yearly' => _addMonthsClamped(current, 12 * interval),
      _ => _addMonthsClamped(current, interval),
    };
  }

  static DateTime _addMonthsClamped(DateTime source, int months) {
    final targetMonth = source.month - 1 + months;
    final year = source.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = min(source.day, lastDay);
    return DateTime(
      year,
      month,
      day,
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
  }

  static void _require(StaffUser user, String permission) {
    if (!user.can(permission)) {
      throw StateError('Your staff role does not permit this action.');
    }
  }

  static Future<StaffUser> _staffById(DatabaseExecutor db, int id) async {
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Staff user was not found.');
    final role = rows.first['role'] as String;
    final roleRows = await db.query(
      'role_permissions',
      columns: ['permission_key'],
      where: 'role_key = ?',
      whereArgs: [role],
    );
    final permissions = roleRows
        .map((row) => row['permission_key'] as String)
        .toSet();
    final overrides = await db.query(
      'user_permissions',
      where: 'user_id = ?',
      whereArgs: [id],
    );
    for (final override in overrides) {
      final permission = override['permission_key'] as String;
      if ((override['allowed'] as num).toInt() == 1) {
        permissions.add(permission);
      } else {
        permissions.remove(permission);
      }
    }
    return StaffUser.fromMap(rows.first, permissions: permissions);
  }

  static Future<void> _enforceCreditLimit(
    DatabaseExecutor db, {
    required int branchId,
    required int customerId,
    required double additionalDebt,
  }) async {
    final rows = await db.query(
      'customers',
      columns: ['balance', 'credit_limit', 'credit_enabled'],
      where: 'id = ? AND branch_id = ? AND is_active = 1',
      whereArgs: [customerId, branchId],
      limit: 1,
    );
    if (rows.isEmpty)
      throw StateError('Customer was not found in this branch.');
    final row = rows.first;
    if ((row['credit_enabled'] as num? ?? 1).toInt() != 1) {
      throw StateError('Credit is disabled for this customer.');
    }
    final balance = (row['balance'] as num? ?? 0).toDouble();
    final limit = (row['credit_limit'] as num? ?? 0).toDouble();
    if (limit > 0 && balance + additionalDebt > limit + 0.001) {
      throw StateError('This invoice exceeds the customer credit limit.');
    }
  }

  static Future<void> _requireOpenCashSession(
    DatabaseExecutor db,
    int cashSessionId,
    StaffUser actor,
  ) async {
    final sessions = await db.query(
      'cash_sessions',
      columns: ['id'],
      where: 'id = ? AND branch_id = ? AND user_id = ? AND status = ?',
      whereArgs: [cashSessionId, actor.branchId, actor.id, 'open'],
      limit: 1,
    );
    if (sessions.isEmpty)
      throw StateError('The cash-register session is not open.');
  }

  static Future<void> _writeDocumentHistory(
    DatabaseExecutor db, {
    required int documentId,
    required String oldStatus,
    required String newStatus,
    required StaffUser actor,
    String reason = '',
  }) => db.insert('document_status_history', {
    'document_id': documentId,
    'old_status': oldStatus,
    'new_status': newStatus,
    'changed_by': actor.id,
    'reason': reason.trim(),
    'changed_at': DateTime.now().toIso8601String(),
  });

  static Future<double> _branchStock(
    DatabaseExecutor db, {
    required int branchId,
    required int productId,
  }) async {
    final rows = await db.query(
      'branch_inventory',
      columns: ['stock_qty'],
      where: 'branch_id = ? AND product_id = ?',
      whereArgs: [branchId, productId],
      limit: 1,
    );
    return rows.isEmpty ? 0 : (rows.first['stock_qty'] as num? ?? 0).toDouble();
  }

  static Future<void> _writeTransferHistory(
    DatabaseExecutor db, {
    required int transferId,
    required String oldStatus,
    required String newStatus,
    required StaffUser actor,
    String reason = '',
  }) => db.insert('stock_transfer_status_history', {
    'transfer_id': transferId,
    'old_status': oldStatus,
    'new_status': newStatus,
    'changed_by': actor.id,
    'reason': reason.trim(),
    'changed_at': DateTime.now().toIso8601String(),
  });

  static Future<void> _increaseBranchStock(
    DatabaseExecutor db, {
    required int branchId,
    required int productId,
    required double quantity,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('branch_inventory', {
      'branch_id': branchId,
      'product_id': productId,
      'stock_qty': 0,
      'low_stock_level': 5,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.rawUpdate(
      'UPDATE branch_inventory SET stock_qty = stock_qty + ?, updated_at = ? WHERE branch_id = ? AND product_id = ?',
      [quantity, now, branchId, productId],
    );
    if (branchId == DatabaseService.defaultBranchId) {
      await db.rawUpdate(
        'UPDATE products SET stock_qty = stock_qty + ? WHERE id = ?',
        [quantity, productId],
      );
    }
  }

  static Future<void> _writeAudit(
    DatabaseExecutor db, {
    required int? userId,
    required int? branchId,
    required String action,
    required String entityType,
    required String entityId,
    Map<String, Object?>? oldValues,
    Map<String, Object?>? newValues,
    String reason = '',
    bool success = true,
  }) => db.insert('audit_logs', {
    'user_id': userId,
    'branch_id': branchId,
    'action': action,
    'entity_type': entityType,
    'entity_id': entityId,
    'old_values': oldValues == null ? null : jsonEncode(oldValues),
    'new_values': newValues == null ? null : jsonEncode(newValues),
    'reason': reason,
    'success': success ? 1 : 0,
    'created_at': DateTime.now().toIso8601String(),
  });

  static String _documentPrefix(String type) => switch (type) {
    'quotation' => 'QUO',
    'estimate' => 'EST',
    'proforma' => 'PRO',
    'invoice' => 'INV',
    'delivery_note' => 'DN',
    'credit_note' => 'CN',
    _ => 'DOC',
  };

  static String _number(String prefix, DateTime dateTime) {
    final stamp = dateTime
        .toIso8601String()
        .replaceAll(RegExp(r'[-:T.]'), '')
        .substring(0, 14);
    final suffix = dateTime.microsecondsSinceEpoch
        .remainder(1000)
        .toString()
        .padLeft(3, '0');
    return '$prefix-$stamp-$suffix';
  }
}
