import 'dart:convert';

import '../../core/money.dart';

enum StaffRole { owner, manager, cashier, accountant, stockOfficer }

extension StaffRoleLabel on StaffRole {
  String get databaseValue => switch (this) {
    StaffRole.owner => 'owner',
    StaffRole.manager => 'manager',
    StaffRole.cashier => 'cashier',
    StaffRole.accountant => 'accountant',
    StaffRole.stockOfficer => 'stock_officer',
  };

  String get label => switch (this) {
    StaffRole.owner => 'Owner',
    StaffRole.manager => 'Manager',
    StaffRole.cashier => 'Cashier',
    StaffRole.accountant => 'Accountant',
    StaffRole.stockOfficer => 'Stock Officer',
  };

  static StaffRole parse(String value) => switch (value) {
    'manager' => StaffRole.manager,
    'cashier' => StaffRole.cashier,
    'accountant' => StaffRole.accountant,
    'stock_officer' => StaffRole.stockOfficer,
    _ => StaffRole.owner,
  };
}

abstract final class CommercialPermission {
  static const dashboardView = 'dashboard.view';
  static const salesProcess = 'sales.process';
  static const salesDiscount = 'sales.discount';
  static const salesVoid = 'sales.void';
  static const salesRefund = 'sales.refund';
  static const productsManage = 'products.manage';
  static const stockAdjust = 'stock.adjust';
  static const stockCount = 'stock.count';
  static const stockTransferApprove = 'stock.transfer.approve';
  static const stockTransferReceive = 'stock.transfer.receive';
  static const purchasingManage = 'purchasing.manage';
  static const debtView = 'debt.view';
  static const debtPayment = 'debt.payment';
  static const expensesView = 'expenses.view';
  static const expensesManage = 'expenses.manage';
  static const reportsView = 'reports.view';
  static const reportsProfit = 'reports.profit';
  static const reportsExport = 'reports.export';
  static const cashManage = 'cash.manage';
  static const cashVarianceApprove = 'cash.variance.approve';
  static const documentsManage = 'documents.manage';
  static const documentsPrint = 'documents.print';
  static const documentsSend = 'documents.send';
  static const auditView = 'audit.view';
  static const auditExport = 'audit.export';
  static const staffManage = 'staff.manage';
  static const branchesManage = 'branches.manage';
  static const settingsManage = 'settings.manage';
  static const backupsManage = 'backups.manage';
  static const licenseManage = 'license.manage';
  static const remoteDashboard = 'remote_dashboard.manage';
  static const importsManage = 'imports.manage';
  static const updatesManage = 'updates.manage';
  static const integrationsManage = 'integrations.manage';

  static const all = <String>{
    dashboardView,
    salesProcess,
    salesDiscount,
    salesVoid,
    salesRefund,
    productsManage,
    stockAdjust,
    stockCount,
    stockTransferApprove,
    stockTransferReceive,
    purchasingManage,
    debtView,
    debtPayment,
    expensesView,
    expensesManage,
    reportsView,
    reportsProfit,
    reportsExport,
    cashManage,
    cashVarianceApprove,
    documentsManage,
    documentsPrint,
    documentsSend,
    auditView,
    auditExport,
    staffManage,
    branchesManage,
    settingsManage,
    backupsManage,
    licenseManage,
    remoteDashboard,
    importsManage,
    updatesManage,
    integrationsManage,
  };
}

class BranchRecord {
  const BranchRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.phone,
    required this.email,
    required this.isActive,
  });

  final int id;
  final String name;
  final String code;
  final String address;
  final String phone;
  final String email;
  final bool isActive;

  factory BranchRecord.fromMap(Map<String, Object?> map) => BranchRecord(
    id: map['id'] as int,
    name: map['name'] as String,
    code: map['code'] as String? ?? '',
    address: map['address'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    email: map['email'] as String? ?? '',
    isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
  );
}

class StaffUser {
  const StaffUser({
    required this.id,
    required this.branchId,
    required this.name,
    required this.username,
    required this.role,
    required this.permissions,
    required this.isActive,
    this.lastLoginAt,
    this.forcePinChange = false,
    this.lockedUntil,
  });

  final int id;
  final int branchId;
  final String name;
  final String username;
  final StaffRole role;
  final Set<String> permissions;
  final bool isActive;
  final DateTime? lastLoginAt;
  final bool forcePinChange;
  final DateTime? lockedUntil;

  bool can(String permission) =>
      role == StaffRole.owner || permissions.contains(permission);

  StaffUser copyWith({
    int? branchId,
    String? name,
    String? username,
    StaffRole? role,
    Set<String>? permissions,
    bool? isActive,
    bool? forcePinChange,
    DateTime? lockedUntil,
  }) => StaffUser(
    id: id,
    branchId: branchId ?? this.branchId,
    name: name ?? this.name,
    username: username ?? this.username,
    role: role ?? this.role,
    permissions: permissions ?? this.permissions,
    isActive: isActive ?? this.isActive,
    lastLoginAt: lastLoginAt,
    forcePinChange: forcePinChange ?? this.forcePinChange,
    lockedUntil: lockedUntil ?? this.lockedUntil,
  );

  factory StaffUser.fromMap(
    Map<String, Object?> map, {
    Set<String> permissions = const {},
  }) => StaffUser(
    id: map['id'] as int,
    branchId: (map['branch_id'] as num? ?? 1).toInt(),
    name: map['name'] as String,
    username: map['username'] as String,
    role: StaffRoleLabel.parse(map['role'] as String? ?? 'owner'),
    permissions: permissions,
    isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
    lastLoginAt: map['last_login_at'] == null
        ? null
        : DateTime.tryParse(map['last_login_at'] as String),
    forcePinChange: (map['force_pin_change'] as num? ?? 0).toInt() == 1,
    lockedUntil: map['locked_until'] == null
        ? null
        : DateTime.tryParse(map['locked_until'] as String),
  );
}

class CommercialDocumentItem {
  const CommercialDocumentItem({
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    this.unit = 'each',
    this.lineDiscount = 0,
    this.taxRate = 0,
    this.taxInclusive = false,
  });

  final int? productId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final String unit;
  final double lineDiscount;
  final double taxRate;
  final bool taxInclusive;

  double get grossAmount => MoneyMath.multiply(quantity, unitPrice);
  double get costTotal => MoneyMath.multiply(quantity, costPrice);
  double get normalizedDiscount {
    final requested = MoneyMath.round(lineDiscount);
    if (requested <= 0) return 0;
    return requested > grossAmount ? grossAmount : requested;
  }

  double get lineSubtotal =>
      MoneyMath.subtract(grossAmount, normalizedDiscount);

  double get taxAmount {
    if (taxRate <= 0 || lineSubtotal <= 0) return 0;
    if (taxInclusive) {
      final exclusive = MoneyMath.round(lineSubtotal / (1 + taxRate / 100));
      return MoneyMath.subtract(lineSubtotal, exclusive);
    }
    return MoneyMath.percent(lineSubtotal, taxRate);
  }

  double get total =>
      taxInclusive ? lineSubtotal : MoneyMath.add([lineSubtotal, taxAmount]);

  Map<String, Object?> toMap() => {
    'product_id': productId,
    'description': description.trim(),
    'quantity': quantity,
    'unit': unit.trim().isEmpty ? 'each' : unit.trim(),
    'unit_price': MoneyMath.round(unitPrice),
    'cost_price': MoneyMath.round(costPrice),
    'line_discount': normalizedDiscount,
    'tax_rate': taxRate,
    'tax_inclusive': taxInclusive ? 1 : 0,
    'line_total': total,
  };
}

class CommercialDocumentDraft {
  const CommercialDocumentDraft({
    required this.type,
    required this.customerId,
    required this.items,
    required this.discount,
    required this.tax,
    required this.notes,
    required this.terms,
    this.validUntil,
    this.dueAt,
    this.paymentInstructions = '',
    this.documentDate,
  });

  final String type;
  final int? customerId;
  final List<CommercialDocumentItem> items;
  final double discount;
  final double tax;
  final String notes;
  final String terms;
  final DateTime? validUntil;
  final DateTime? dueAt;
  final String paymentInstructions;
  final DateTime? documentDate;

  double get subtotal => MoneyMath.add(items.map((item) => item.lineSubtotal));
  double get itemTax => MoneyMath.add(items.map((item) => item.taxAmount));
  double get exclusiveItemTax => MoneyMath.add(
    items.where((item) => !item.taxInclusive).map((item) => item.taxAmount),
  );
  double get totalTax => MoneyMath.add([itemTax, tax]);
  double get total => MoneyMath.clampNonNegative(
    MoneyMath.add([subtotal, exclusiveItemTax, tax]) -
        MoneyMath.round(discount),
  );
}

class BusinessHealthSnapshot {
  const BusinessHealthSnapshot({
    required this.revenue,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.customerDebt,
    required this.supplierDebt,
    required this.lowStockCount,
    required this.expiringCount,
    required this.refundRate,
    required this.cashVariance,
    required this.suggestions,
    this.cashFlow = 0,
    this.discountRate = 0,
    this.deadStockCount = 0,
    this.slowMovingCount = 0,
    this.upcomingPayments = 0,
    this.recurringObligations = 0,
  });

  final double revenue;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double customerDebt;
  final double supplierDebt;
  final int lowStockCount;
  final int expiringCount;
  final double refundRate;
  final double cashVariance;
  final double cashFlow;
  final double discountRate;
  final int deadStockCount;
  final int slowMovingCount;
  final double upcomingPayments;
  final double recurringObligations;
  final List<String> suggestions;
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.createdAt,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.success,
    this.userName,
    this.userRole,
    this.branchName,
    this.deviceId = '',
    this.oldValues,
    this.newValues,
  });

  final int id;
  final DateTime createdAt;
  final String action;
  final String entityType;
  final String entityId;
  final String reason;
  final bool success;
  final String? userName;
  final String? userRole;
  final String? branchName;
  final String deviceId;
  final Map<String, Object?>? oldValues;
  final Map<String, Object?>? newValues;

  static Map<String, Object?>? decodeMap(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final decoded = jsonDecode(value);
    return decoded is Map<String, Object?> ? decoded : null;
  }

  factory AuditEntry.fromMap(Map<String, Object?> map) => AuditEntry(
    id: map['id'] as int,
    createdAt: DateTime.parse(map['created_at'] as String),
    action: map['action'] as String,
    entityType: map['entity_type'] as String,
    entityId: map['entity_id'] as String? ?? '',
    reason: map['reason'] as String? ?? '',
    success: (map['success'] as num? ?? 1).toInt() == 1,
    userName: map['user_name'] as String?,
    userRole: map['user_role'] as String?,
    branchName: map['branch_name'] as String?,
    deviceId: map['device_id'] as String? ?? '',
    oldValues: decodeMap(map['old_values']),
    newValues: decodeMap(map['new_values']),
  );
}
