import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/money.dart';
import '../../services/database_service.dart';
import '../models/commercial_models.dart';

enum CommercialReportKind {
  revenue,
  grossProfit,
  netProfit,
  costOfGoodsSold,
  expenses,
  cashFlow,
  customerDebt,
  supplierDebt,
  salesByProduct,
  salesByCategory,
  salesByUser,
  salesByBranch,
  profitByProduct,
  profitByCategory,
  profitByUser,
  profitByBranch,
  returns,
  refunds,
  discounts,
  cashVariance,
  stockMovement,
  expiry,
  lowStock,
  slowMovingStock,
  deadStock,
  purchases,
  tax,
}

extension CommercialReportKindLabel on CommercialReportKind {
  String get label => switch (this) {
        CommercialReportKind.revenue => 'Revenue',
        CommercialReportKind.grossProfit => 'Gross profit',
        CommercialReportKind.netProfit => 'Net profit',
        CommercialReportKind.costOfGoodsSold => 'Cost of goods sold',
        CommercialReportKind.expenses => 'Expenses',
        CommercialReportKind.cashFlow => 'Cash flow',
        CommercialReportKind.customerDebt => 'Customer debt',
        CommercialReportKind.supplierDebt => 'Supplier debt',
        CommercialReportKind.salesByProduct => 'Sales by product',
        CommercialReportKind.salesByCategory => 'Sales by category',
        CommercialReportKind.salesByUser => 'Sales by user',
        CommercialReportKind.salesByBranch => 'Sales by branch',
        CommercialReportKind.profitByProduct => 'Profit by product',
        CommercialReportKind.profitByCategory => 'Profit by category',
        CommercialReportKind.profitByUser => 'Profit by user',
        CommercialReportKind.profitByBranch => 'Profit by branch',
        CommercialReportKind.returns => 'Returns',
        CommercialReportKind.refunds => 'Refunds',
        CommercialReportKind.discounts => 'Discounts',
        CommercialReportKind.cashVariance => 'Cash variance',
        CommercialReportKind.stockMovement => 'Stock movement',
        CommercialReportKind.expiry => 'Expiry',
        CommercialReportKind.lowStock => 'Low stock',
        CommercialReportKind.slowMovingStock => 'Slow-moving stock',
        CommercialReportKind.deadStock => 'Dead stock',
        CommercialReportKind.purchases => 'Purchases',
        CommercialReportKind.tax => 'Tax',
      };
}

class CommercialReportFilter {
  const CommercialReportFilter({
    this.from,
    this.to,
    this.branchId,
    this.userId,
    this.productId,
    this.category,
    this.customerId,
    this.supplierId,
    this.paymentMethod,
    this.documentStatus,
    this.consolidated = false,
  });

  final DateTime? from;
  final DateTime? to;
  final int? branchId;
  final int? userId;
  final int? productId;
  final String? category;
  final int? customerId;
  final int? supplierId;
  final String? paymentMethod;
  final String? documentStatus;
  final bool consolidated;

  CommercialReportFilter copyWith({
    DateTime? from,
    DateTime? to,
    int? branchId,
    int? userId,
    int? productId,
    String? category,
    int? customerId,
    int? supplierId,
    String? paymentMethod,
    String? documentStatus,
    bool? consolidated,
  }) =>
      CommercialReportFilter(
        from: from ?? this.from,
        to: to ?? this.to,
        branchId: branchId ?? this.branchId,
        userId: userId ?? this.userId,
        productId: productId ?? this.productId,
        category: category ?? this.category,
        customerId: customerId ?? this.customerId,
        supplierId: supplierId ?? this.supplierId,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        documentStatus: documentStatus ?? this.documentStatus,
        consolidated: consolidated ?? this.consolidated,
      );

  factory CommercialReportFilter.period(String period, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    switch (period) {
      case 'today':
        return CommercialReportFilter(
          from: today,
          to: today.add(const Duration(days: 1)),
        );
      case 'yesterday':
        final start = today.subtract(const Duration(days: 1));
        return CommercialReportFilter(from: start, to: today);
      case 'this_week':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return CommercialReportFilter(
          from: start,
          to: start.add(const Duration(days: 7)),
        );
      case 'last_week':
        final end = today.subtract(Duration(days: today.weekday - 1));
        return CommercialReportFilter(
          from: end.subtract(const Duration(days: 7)),
          to: end,
        );
      case 'this_month':
        return CommercialReportFilter(
          from: DateTime(today.year, today.month),
          to: DateTime(today.year, today.month + 1),
        );
      case 'last_month':
        return CommercialReportFilter(
          from: DateTime(today.year, today.month - 1),
          to: DateTime(today.year, today.month),
        );
      case 'this_quarter':
        final startMonth = ((today.month - 1) ~/ 3) * 3 + 1;
        return CommercialReportFilter(
          from: DateTime(today.year, startMonth),
          to: DateTime(today.year, startMonth + 3),
        );
      case 'this_year':
        return CommercialReportFilter(
          from: DateTime(today.year),
          to: DateTime(today.year + 1),
        );
      default:
        return const CommercialReportFilter();
    }
  }
}

class CommercialReportResult {
  const CommercialReportResult({
    required this.kind,
    required this.columns,
    required this.rows,
    required this.totals,
    required this.filter,
  });

  final CommercialReportKind kind;
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final Map<String, double> totals;
  final CommercialReportFilter filter;

  bool get isEmpty => rows.isEmpty;
}

class AdvancedReportService {
  const AdvancedReportService(this._database);

  final DatabaseService _database;

  Future<CommercialReportResult> run({
    required StaffUser actor,
    required CommercialReportKind kind,
    CommercialReportFilter filter = const CommercialReportFilter(),
  }) async {
    _authorize(actor, filter);
    final db = await _database.database;
    final effectiveBranch = filter.branchId ?? actor.branchId;
    return switch (kind) {
      CommercialReportKind.revenue ||
      CommercialReportKind.grossProfit ||
      CommercialReportKind.netProfit ||
      CommercialReportKind.costOfGoodsSold =>
        _profitSummary(db, actor, kind, filter, effectiveBranch),
      CommercialReportKind.expenses =>
        _expenses(db, actor, filter, effectiveBranch),
      CommercialReportKind.cashFlow =>
        _cashFlow(db, actor, filter, effectiveBranch),
      CommercialReportKind.customerDebt =>
        _customerDebt(db, actor, filter, effectiveBranch),
      CommercialReportKind.supplierDebt =>
        _supplierDebt(db, actor, filter, effectiveBranch),
      CommercialReportKind.salesByProduct =>
        _salesDimension(db, actor, kind, filter, effectiveBranch, 'product'),
      CommercialReportKind.salesByCategory =>
        _salesDimension(db, actor, kind, filter, effectiveBranch, 'category'),
      CommercialReportKind.salesByUser =>
        _salesDimension(db, actor, kind, filter, effectiveBranch, 'user'),
      CommercialReportKind.salesByBranch =>
        _salesDimension(db, actor, kind, filter, effectiveBranch, 'branch'),
      CommercialReportKind.profitByProduct =>
        _profitDimension(db, actor, kind, filter, effectiveBranch, 'product'),
      CommercialReportKind.profitByCategory =>
        _profitDimension(db, actor, kind, filter, effectiveBranch, 'category'),
      CommercialReportKind.profitByUser =>
        _profitDimension(db, actor, kind, filter, effectiveBranch, 'user'),
      CommercialReportKind.profitByBranch =>
        _profitDimension(db, actor, kind, filter, effectiveBranch, 'branch'),
      CommercialReportKind.returns =>
        _returns(db, actor, kind, filter, effectiveBranch, refundsOnly: false),
      CommercialReportKind.refunds =>
        _returns(db, actor, kind, filter, effectiveBranch, refundsOnly: true),
      CommercialReportKind.discounts =>
        _discounts(db, actor, filter, effectiveBranch),
      CommercialReportKind.cashVariance =>
        _cashVariance(db, actor, filter, effectiveBranch),
      CommercialReportKind.stockMovement =>
        _stockMovement(db, actor, filter, effectiveBranch),
      CommercialReportKind.expiry =>
        _stockStatus(db, actor, kind, filter, effectiveBranch, mode: 'expiry'),
      CommercialReportKind.lowStock =>
        _stockStatus(db, actor, kind, filter, effectiveBranch, mode: 'low'),
      CommercialReportKind.slowMovingStock =>
        _stockStatus(db, actor, kind, filter, effectiveBranch, mode: 'slow'),
      CommercialReportKind.deadStock =>
        _stockStatus(db, actor, kind, filter, effectiveBranch, mode: 'dead'),
      CommercialReportKind.purchases =>
        _purchases(db, actor, filter, effectiveBranch),
      CommercialReportKind.tax =>
        _tax(db, actor, filter, effectiveBranch),
    };
  }

  Future<CommercialReportResult> _profitSummary(
    Database db,
    StaffUser actor,
    CommercialReportKind kind,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = _saleWhere(actor, filter, branchId);
    final rows = await db.rawQuery('''
      SELECT date(s.created_at) AS period,
        ROUND(COALESCE(SUM(s.total - s.returned_total), 0), 2) AS revenue,
        ROUND(COALESCE(SUM(si.cost_price * si.quantity), 0), 2) AS cost_of_goods,
        ROUND(COALESCE(SUM(
          (si.unit_price - si.cost_price) * si.quantity
        ), 0) - COALESCE(SUM(DISTINCT s.discount), 0), 2) AS gross_profit,
        ROUND(COALESCE((
          SELECT SUM(e.amount)
          FROM expenses e
          WHERE e.branch_id = s.branch_id
            AND date(e.created_at) = date(s.created_at)
        ), 0), 2) AS expenses
      FROM sales s
      LEFT JOIN sale_items si ON si.sale_id = s.id
      WHERE ${where.sql}
      GROUP BY date(s.created_at)
      ORDER BY period
    ''', where.args);
    final normalized = rows
        .map((row) {
          final revenue = _number(row['revenue']);
          final cost = _number(row['cost_of_goods']);
          final gross = _number(row['gross_profit']);
          final expenses = _number(row['expenses']);
          return <String, Object?>{
            'period': row['period'],
            'revenue': revenue,
            'cost_of_goods': cost,
            'gross_profit': gross,
            'expenses': expenses,
            'net_profit': MoneyMath.subtract(gross, expenses),
          };
        })
        .toList(growable: false);
    final totals = _sumColumns(
      normalized,
      const [
        'revenue',
        'cost_of_goods',
        'gross_profit',
        'expenses',
        'net_profit',
      ],
    );
    return CommercialReportResult(
      kind: kind,
      columns: const [
        'period',
        'revenue',
        'cost_of_goods',
        'gross_profit',
        'expenses',
        'net_profit',
      ],
      rows: normalized,
      totals: totals,
      filter: filter,
    );
  }

  Future<CommercialReportResult> _expenses(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = _expenseWhere(actor, filter, branchId);
    final rows = await db.rawQuery('''
      SELECT date(e.created_at) AS period, e.category, e.title AS payee,
        e.payment_method, ROUND(SUM(e.amount), 2) AS amount,
        COUNT(*) AS transaction_count
      FROM expenses e
      WHERE ${where.sql}
      GROUP BY date(e.created_at), e.category, e.title, e.payment_method
      ORDER BY period, e.category
    ''', where.args);
    return CommercialReportResult(
      kind: CommercialReportKind.expenses,
      columns: const [
        'period',
        'category',
        'payee',
        'payment_method',
        'amount',
        'transaction_count',
      ],
      rows: rows,
      totals: _sumColumns(rows, const ['amount', 'transaction_count']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _cashFlow(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = _movementWhere(actor, filter, branchId);
    final rows = await db.rawQuery('''
      SELECT date(cm.created_at) AS period,
        ROUND(SUM(CASE WHEN cm.amount >= 0 THEN cm.amount ELSE 0 END), 2)
          AS cash_in,
        ROUND(ABS(SUM(CASE WHEN cm.amount < 0 THEN cm.amount ELSE 0 END)), 2)
          AS cash_out,
        ROUND(SUM(cm.amount), 2) AS net_cash_flow
      FROM cash_movements cm
      INNER JOIN cash_sessions cs ON cs.id = cm.cash_session_id
      WHERE ${where.sql}
      GROUP BY date(cm.created_at)
      ORDER BY period
    ''', where.args);
    return CommercialReportResult(
      kind: CommercialReportKind.cashFlow,
      columns: const ['period', 'cash_in', 'cash_out', 'net_cash_flow'],
      rows: rows,
      totals:
          _sumColumns(rows, const ['cash_in', 'cash_out', 'net_cash_flow']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _customerDebt(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = <String>['c.balance > 0'];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'c');
    if (filter.customerId != null) {
      where.add('c.id = ?');
      args.add(filter.customerId);
    }
    final rows = await db.rawQuery('''
      SELECT c.id AS customer_id, c.name AS customer,
        c.phone, c.email, ROUND(c.balance, 2) AS balance,
        ROUND(c.credit_limit, 2) AS credit_limit,
        CASE WHEN c.credit_enabled = 1 THEN 'Enabled' ELSE 'Disabled' END
          AS credit_status
      FROM customers c
      WHERE ${where.join(' AND ')}
      ORDER BY c.balance DESC, c.name
    ''', args);
    return CommercialReportResult(
      kind: CommercialReportKind.customerDebt,
      columns: const [
        'customer_id',
        'customer',
        'phone',
        'email',
        'balance',
        'credit_limit',
        'credit_status',
      ],
      rows: rows,
      totals: _sumColumns(rows, const ['balance']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _supplierDebt(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = <String>['s.balance > 0'];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 's');
    if (filter.supplierId != null) {
      where.add('s.id = ?');
      args.add(filter.supplierId);
    }
    final rows = await db.rawQuery('''
      SELECT s.id AS supplier_id, s.name AS supplier,
        s.phone, s.email, ROUND(s.balance, 2) AS balance
      FROM suppliers s
      WHERE ${where.join(' AND ')}
      ORDER BY s.balance DESC, s.name
    ''', args);
    return CommercialReportResult(
      kind: CommercialReportKind.supplierDebt,
      columns: const ['supplier_id', 'supplier', 'phone', 'email', 'balance'],
      rows: rows,
      totals: _sumColumns(rows, const ['balance']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _salesDimension(
    Database db,
    StaffUser actor,
    CommercialReportKind kind,
    CommercialReportFilter filter,
    int branchId,
    String dimension,
  ) async {
    final where = _saleWhere(actor, filter, branchId);
    final expression = switch (dimension) {
      'category' => "COALESCE(p.category, 'Uncategorized')",
      'user' => "COALESCE(u.name, 'Unknown user')",
      'branch' => "COALESCE(b.name, 'Unknown branch')",
      _ => 'si.product_name',
    };
    final key = switch (dimension) {
      'category' => 'category',
      'user' => 'user',
      'branch' => 'branch',
      _ => 'product',
    };
    final rows = await db.rawQuery('''
      SELECT $expression AS $key,
        ROUND(SUM(si.quantity), 2) AS quantity,
        ROUND(SUM(si.total), 2) AS revenue,
        COUNT(DISTINCT s.id) AS transaction_count
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      LEFT JOIN products p ON p.id = si.product_id
      LEFT JOIN users u ON u.id = s.user_id
      LEFT JOIN branches b ON b.id = s.branch_id
      WHERE ${where.sql}
      GROUP BY $expression
      ORDER BY revenue DESC, $key
    ''', where.args);
    return CommercialReportResult(
      kind: kind,
      columns: [key, 'quantity', 'revenue', 'transaction_count'],
      rows: rows,
      totals:
          _sumColumns(rows, const ['quantity', 'revenue', 'transaction_count']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _profitDimension(
    Database db,
    StaffUser actor,
    CommercialReportKind kind,
    CommercialReportFilter filter,
    int branchId,
    String dimension,
  ) async {
    final where = _saleWhere(actor, filter, branchId);
    final expression = switch (dimension) {
      'category' => "COALESCE(p.category, 'Uncategorized')",
      'user' => "COALESCE(u.name, 'Unknown user')",
      'branch' => "COALESCE(b.name, 'Unknown branch')",
      _ => 'si.product_name',
    };
    final key = switch (dimension) {
      'category' => 'category',
      'user' => 'user',
      'branch' => 'branch',
      _ => 'product',
    };
    final rows = await db.rawQuery('''
      SELECT $expression AS $key,
        ROUND(SUM(si.quantity), 2) AS quantity,
        ROUND(SUM(si.total), 2) AS revenue,
        ROUND(SUM(si.cost_price * si.quantity), 2) AS cost_of_goods,
        ROUND(SUM(si.total - si.cost_price * si.quantity), 2) AS gross_profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      LEFT JOIN products p ON p.id = si.product_id
      LEFT JOIN users u ON u.id = s.user_id
      LEFT JOIN branches b ON b.id = s.branch_id
      WHERE ${where.sql}
      GROUP BY $expression
      ORDER BY gross_profit DESC, $key
    ''', where.args);
    return CommercialReportResult(
      kind: kind,
      columns: [key, 'quantity', 'revenue', 'cost_of_goods', 'gross_profit'],
      rows: rows,
      totals: _sumColumns(
        rows,
        const ['quantity', 'revenue', 'cost_of_goods', 'gross_profit'],
      ),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _returns(
    Database db,
    StaffUser actor,
    CommercialReportKind kind,
    CommercialReportFilter filter,
    int branchId, {
    required bool refundsOnly,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'r');
    _addDateFilters(where, args, filter, 'r.created_at');
    if (refundsOnly) where.add('rf.amount > 0');
    final rows = await db.rawQuery('''
      SELECT r.id, r.return_no, r.sale_id, r.status, r.reason,
        COALESCE(rf.method, r.refund_method) AS refund_method,
        ROUND(r.total, 2) AS return_total,
        ROUND(COALESCE(rf.amount, 0), 2) AS refund_amount,
        r.restock, r.created_at, u.name AS processed_by
      FROM returns r
      LEFT JOIN refunds rf ON rf.return_id = r.id
      LEFT JOIN users u ON u.id = r.user_id
      WHERE ${where.isEmpty ? '1 = 1' : where.join(' AND ')}
      ORDER BY r.created_at DESC
    ''', args);
    return CommercialReportResult(
      kind: kind,
      columns: const [
        'return_no',
        'sale_id',
        'status',
        'reason',
        'refund_method',
        'return_total',
        'refund_amount',
        'restock',
        'created_at',
        'processed_by',
      ],
      rows: rows,
      totals: _sumColumns(rows, const ['return_total', 'refund_amount']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _discounts(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = _saleWhere(actor, filter, branchId);
    final rows = await db.rawQuery('''
      SELECT s.invoice_no, s.created_at, u.name AS user,
        b.name AS branch, ROUND(s.subtotal, 2) AS subtotal,
        ROUND(s.discount, 2) AS discount,
        ROUND(CASE WHEN s.subtotal > 0
          THEN s.discount * 100.0 / s.subtotal ELSE 0 END, 2) AS discount_rate
      FROM sales s
      LEFT JOIN users u ON u.id = s.user_id
      LEFT JOIN branches b ON b.id = s.branch_id
      WHERE ${where.sql} AND s.discount > 0
      ORDER BY s.created_at DESC
    ''', where.args);
    return CommercialReportResult(
      kind: CommercialReportKind.discounts,
      columns: const [
        'invoice_no',
        'created_at',
        'user',
        'branch',
        'subtotal',
        'discount',
        'discount_rate',
      ],
      rows: rows,
      totals: _sumColumns(rows, const ['subtotal', 'discount']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _cashVariance(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = <String>['cs.status = ?'];
    final args = <Object?>['closed'];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'cs');
    _addDateFilters(where, args, filter, 'cs.closed_at');
    if (filter.userId != null) {
      where.add('cs.user_id = ?');
      args.add(filter.userId);
    }
    final rows = await db.rawQuery('''
      SELECT cs.id AS session_id, cr.name AS register_name,
        u.name AS opened_by, cs.opened_at, cs.closed_at,
        ROUND(cs.opening_float, 2) AS opening_float,
        ROUND(cs.expected_cash, 2) AS expected_cash,
        ROUND(cs.actual_cash, 2) AS actual_cash,
        ROUND(cs.variance, 2) AS variance,
        cs.approved_by AS variance_approved_by,
        cs.approved_at AS variance_approved_at,
        cs.closing_note AS closing_notes
      FROM cash_sessions cs
      INNER JOIN cash_registers cr ON cr.id = cs.register_id
      LEFT JOIN users u ON u.id = cs.user_id
      WHERE ${where.join(' AND ')}
      ORDER BY cs.closed_at DESC
    ''', args);
    return CommercialReportResult(
      kind: CommercialReportKind.cashVariance,
      columns: const [
        'session_id',
        'register_name',
        'opened_by',
        'opened_at',
        'closed_at',
        'opening_float',
        'expected_cash',
        'actual_cash',
        'variance',
        'variance_approved_by',
        'closing_notes',
      ],
      rows: rows,
      totals: _sumColumns(
        rows,
        const ['opening_float', 'expected_cash', 'actual_cash', 'variance'],
      ),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _stockMovement(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = <String>[];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'movement');
    _addDateFilters(where, args, filter, 'movement.created_at');
    if (filter.productId != null) {
      where.add('movement.product_id = ?');
      args.add(filter.productId);
    }
    final rows = await db.rawQuery('''
      SELECT movement.created_at, p.name AS product, p.sku, p.barcode,
        movement.movement_type, ROUND(movement.quantity, 2) AS quantity,
        movement.reference_type, movement.reference_id, movement.reason,
        u.name AS user
      FROM (
        SELECT sa.branch_id, sa.product_id, sa.user_id, sa.created_at,
          'adjustment' AS movement_type, sa.quantity_change AS quantity,
          'stock_adjustment' AS reference_type, sa.id AS reference_id,
          sa.reason || CASE WHEN sa.note = '' THEN '' ELSE ': ' || sa.note END
            AS reason
        FROM stock_adjustments sa
        UNION ALL
        SELECT s.branch_id, si.product_id, s.user_id, s.created_at,
          'sale' AS movement_type, -si.quantity AS quantity,
          'sale' AS reference_type, s.id AS reference_id,
          s.invoice_no AS reason
        FROM sale_items si
        INNER JOIN sales s ON s.id = si.sale_id
        WHERE s.status = 'completed'
        UNION ALL
        SELECT gr.branch_id, poi.product_id, gr.received_by AS user_id,
          gr.received_at AS created_at,
          'purchase_receipt' AS movement_type,
          gri.quantity_received AS quantity,
          'goods_receipt' AS reference_type, gr.id AS reference_id,
          gr.receipt_no AS reason
        FROM goods_receipt_items gri
        INNER JOIN goods_receipts gr ON gr.id = gri.goods_receipt_id
        INNER JOIN purchase_order_items poi ON poi.id = gri.purchase_order_item_id
      ) movement
      INNER JOIN products p ON p.id = movement.product_id
      LEFT JOIN users u ON u.id = movement.user_id
      WHERE ${where.isEmpty ? '1 = 1' : where.join(' AND ')}
      ORDER BY movement.created_at DESC
    ''', args);
    return CommercialReportResult(
      kind: CommercialReportKind.stockMovement,
      columns: const [
        'created_at',
        'product',
        'sku',
        'barcode',
        'movement_type',
        'quantity',
        'reference_type',
        'reference_id',
        'reason',
        'user',
      ],
      rows: rows,
      totals: _sumColumns(rows, const ['quantity']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _stockStatus(
    Database db,
    StaffUser actor,
    CommercialReportKind kind,
    CommercialReportFilter filter,
    int branchId, {
    required String mode,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'bi');
    if (filter.productId != null) {
      where.add('p.id = ?');
      args.add(filter.productId);
    }
    if ((filter.category ?? '').trim().isNotEmpty) {
      where.add('p.category = ?');
      args.add(filter.category!.trim());
    }
    switch (mode) {
      case 'expiry':
        where.add("pb.expires_at IS NOT NULL AND pb.expires_at <> ''");
        where.add(
          "date(pb.expires_at) <= date('now', '+' || "
          'COALESCE(p.near_expiry_days, 30) || \' days\')',
        );
        break;
      case 'low':
        where.add('COALESCE(bi.stock_qty, 0) <= '
            'COALESCE(bi.low_stock_level, p.low_stock_level)');
        break;
      case 'slow':
        where.add('COALESCE(bi.stock_qty, 0) > 0');
        where.add('NOT EXISTS (SELECT 1 FROM sale_items si '
            'INNER JOIN sales s ON s.id = si.sale_id '
            'WHERE si.product_id = p.id AND s.branch_id = bi.branch_id '
            "AND s.created_at >= datetime('now', '-60 days'))");
        break;
      case 'dead':
        where.add('COALESCE(bi.stock_qty, 0) > 0');
        where.add('NOT EXISTS (SELECT 1 FROM sale_items si '
            'INNER JOIN sales s ON s.id = si.sale_id '
            'WHERE si.product_id = p.id AND s.branch_id = bi.branch_id '
            "AND s.created_at >= datetime('now', '-180 days'))");
        break;
    }
    final rows = await db.rawQuery('''
      SELECT p.id AS product_id, p.name AS product, p.sku, p.barcode,
        p.category, b.name AS branch,
        ROUND(COALESCE(bi.stock_qty, 0), 2) AS stock_qty,
        ROUND(COALESCE(bi.low_stock_level, p.low_stock_level), 2)
          AS low_stock_level,
        p.reorder_quantity, p.preferred_supplier_id, p.lead_time_days,
        pb.batch_no AS batch_number, pb.manufactured_at AS manufacture_date,
        pb.expires_at AS expiry_date, p.near_expiry_days
      FROM branch_inventory bi
      INNER JOIN products p ON p.id = bi.product_id
      INNER JOIN branches b ON b.id = bi.branch_id
      LEFT JOIN product_batches pb
        ON pb.branch_id = bi.branch_id AND pb.product_id = p.id
        AND pb.quantity > 0
      WHERE p.is_active = 1
        AND ${where.isEmpty ? '1 = 1' : where.join(' AND ')}
      ORDER BY p.name, b.name
    ''', args);
    return CommercialReportResult(
      kind: kind,
      columns: const [
        'product_id',
        'product',
        'sku',
        'barcode',
        'category',
        'branch',
        'stock_qty',
        'low_stock_level',
        'reorder_quantity',
        'preferred_supplier_id',
        'lead_time_days',
        'batch_number',
        'manufacture_date',
        'expiry_date',
        'near_expiry_days',
      ],
      rows: rows,
      totals: _sumColumns(rows, const ['stock_qty']),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _purchases(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = <String>[];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'po');
    _addDateFilters(where, args, filter, 'po.created_at');
    if (filter.supplierId != null) {
      where.add('po.supplier_id = ?');
      args.add(filter.supplierId);
    }
    if ((filter.documentStatus ?? '').trim().isNotEmpty) {
      where.add('po.status = ?');
      args.add(filter.documentStatus!.trim());
    }
    final rows = await db.rawQuery('''
      SELECT po.id, po.po_no AS order_no, po.created_at, po.expected_at,
        po.status, s.name AS supplier, b.name AS branch,
        ROUND(po.subtotal, 2) AS subtotal,
        ROUND(po.tax, 2) AS tax,
        ROUND(po.total, 2) AS total,
        ROUND(po.amount_paid, 2) AS amount_paid,
        ROUND(po.balance_due, 2) AS balance_due
      FROM purchase_orders po
      INNER JOIN suppliers s ON s.id = po.supplier_id
      INNER JOIN branches b ON b.id = po.branch_id
      WHERE ${where.isEmpty ? '1 = 1' : where.join(' AND ')}
      ORDER BY po.created_at DESC
    ''', args);
    return CommercialReportResult(
      kind: CommercialReportKind.purchases,
      columns: const [
        'order_no',
        'created_at',
        'expected_at',
        'status',
        'supplier',
        'branch',
        'subtotal',
        'tax',
        'total',
        'amount_paid',
        'balance_due',
      ],
      rows: rows,
      totals: _sumColumns(
        rows,
        const ['subtotal', 'tax', 'total', 'amount_paid', 'balance_due'],
      ),
      filter: filter,
    );
  }

  Future<CommercialReportResult> _tax(
    Database db,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) async {
    final where = <String>[];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'd');
    _addDateFilters(where, args, filter, 'd.created_at');
    if ((filter.documentStatus ?? '').trim().isNotEmpty) {
      where.add('d.status = ?');
      args.add(filter.documentStatus!.trim());
    }
    final rows = await db.rawQuery('''
      SELECT date(d.created_at) AS period, d.document_type,
        ROUND(SUM(d.subtotal), 2) AS taxable_amount,
        ROUND(SUM(d.tax), 2) AS document_tax,
        ROUND(SUM(
          COALESCE((SELECT SUM(di.line_total -
            CASE WHEN di.tax_inclusive = 1
              THEN di.line_total / (1 + di.tax_rate / 100.0)
              ELSE di.line_total
            END)
          FROM document_items di WHERE di.document_id = d.id), 0)
        ), 2) AS inclusive_tax_component,
        ROUND(SUM(d.total), 2) AS total
      FROM documents d
      WHERE ${where.isEmpty ? '1 = 1' : where.join(' AND ')}
        AND d.status NOT IN ('draft', 'cancelled')
      GROUP BY date(d.created_at), d.document_type
      ORDER BY period, d.document_type
    ''', args);
    return CommercialReportResult(
      kind: CommercialReportKind.tax,
      columns: const [
        'period',
        'document_type',
        'taxable_amount',
        'document_tax',
        'inclusive_tax_component',
        'total',
      ],
      rows: rows,
      totals: _sumColumns(
        rows,
        const [
          'taxable_amount',
          'document_tax',
          'inclusive_tax_component',
          'total',
        ],
      ),
      filter: filter,
    );
  }

  Future<String> exportCsv(CommercialReportResult result) async {
    final buffer = StringBuffer()
      ..writeln(result.columns.map(_csv).join(','));
    for (final row in result.rows) {
      buffer.writeln(
        result.columns.map((column) => _csv('${row[column] ?? ''}')).join(','),
      );
    }
    return _writeReportFile(
      '${_safe(result.kind.label)}-${_stamp()}.csv',
      Uint8List.fromList(buffer.toString().codeUnits),
    );
  }

  Future<String> exportXlsx(CommercialReportResult result) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Report'];
    sheet.appendRow(
      result.columns.map<CellValue>((column) => TextCellValue(column)).toList(),
    );
    for (final row in result.rows) {
      sheet.appendRow(
        result.columns.map<CellValue>((column) {
          final value = row[column];
          if (value is int) return IntCellValue(value);
          if (value is double) return DoubleCellValue(value);
          if (value is num) return DoubleCellValue(value.toDouble());
          return TextCellValue('${value ?? ''}');
        }).toList(),
      );
    }
    final bytes = workbook.save();
    if (bytes == null) throw StateError('XLSX export could not be generated.');
    return _writeReportFile(
      '${_safe(result.kind.label)}-${_stamp()}.xlsx',
      Uint8List.fromList(bytes),
    );
  }

  Future<Uint8List> buildPdf({
    required CommercialReportResult result,
    required String businessName,
  }) async {
    final pdf = pw.Document(
      title: '${result.kind.label} report',
      author: 'Airmonlink Business Manager',
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              businessName.trim().isEmpty ? 'My Business' : businessName.trim(),
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(result.kind.label.toUpperCase()),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by Airmonlink Business Manager',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Text(_periodLabel(result.filter)),
          pw.SizedBox(height: 12),
          if (result.rows.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Text(
                'No matching records were found for the selected filters.',
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: result.columns.map(_display).toList(growable: false),
              data: result.rows
                  .map(
                    (row) => result.columns
                        .map((column) => '${row[column] ?? ''}')
                        .toList(growable: false),
                  )
                  .toList(growable: false),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellPadding: const pw.EdgeInsets.all(4),
              border: pw.TableBorder.all(
                color: PdfColors.blueGrey200,
                width: 0.4,
              ),
            ),
          if (result.totals.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 10,
              runSpacing: 8,
              children: result.totals.entries
                  .map(
                    (entry) => pw.Text(
                      '${_display(entry.key)}: ${entry.value.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  Future<String> _writeReportFile(String name, Uint8List bytes) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'Airmonlink Business Manager', 'Reports'),
    );
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, name));
    await file.writeAsBytes(bytes, flush: true);
    final db = await _database.database;
    await db.insert('report_exports', {
      'report_type': name.split('-').first.toLowerCase(),
      'format': p.extension(name).replaceFirst('.', '').toLowerCase(),
      'filter_json': '',
      'file_path': file.path,
      'checksum': '',
      'created_at': DateTime.now().toIso8601String(),
    });
    return file.path;
  }

  _Sql _saleWhere(
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) {
    final where = <String>["s.status = 'completed'"];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 's');
    _addDateFilters(where, args, filter, 's.created_at');
    if (filter.userId != null) {
      where.add('s.user_id = ?');
      args.add(filter.userId);
    }
    if (filter.customerId != null) {
      where.add('s.customer_id = ?');
      args.add(filter.customerId);
    }
    if ((filter.paymentMethod ?? '').trim().isNotEmpty) {
      where.add('s.payment_method = ?');
      args.add(filter.paymentMethod!.trim());
    }
    if (filter.productId != null) {
      where.add('EXISTS (SELECT 1 FROM sale_items sx '
          'WHERE sx.sale_id = s.id AND sx.product_id = ?)');
      args.add(filter.productId);
    }
    if ((filter.category ?? '').trim().isNotEmpty) {
      where.add('EXISTS (SELECT 1 FROM sale_items sx '
          'INNER JOIN products px ON px.id = sx.product_id '
          'WHERE sx.sale_id = s.id AND px.category = ?)');
      args.add(filter.category!.trim());
    }
    return _Sql(where.join(' AND '), args);
  }

  _Sql _expenseWhere(
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) {
    final where = <String>[];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'e');
    _addDateFilters(where, args, filter, 'e.created_at');
    if ((filter.paymentMethod ?? '').trim().isNotEmpty) {
      where.add('e.payment_method = ?');
      args.add(filter.paymentMethod!.trim());
    }
    return _Sql(where.isEmpty ? '1 = 1' : where.join(' AND '), args);
  }

  _Sql _movementWhere(
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId,
  ) {
    final where = <String>[];
    final args = <Object?>[];
    _addBranchFilter(where, args, actor, filter, branchId, alias: 'cs');
    _addDateFilters(where, args, filter, 'cm.created_at');
    if (filter.userId != null) {
      where.add('cm.user_id = ?');
      args.add(filter.userId);
    }
    return _Sql(where.isEmpty ? '1 = 1' : where.join(' AND '), args);
  }

  static void _addBranchFilter(
    List<String> where,
    List<Object?> args,
    StaffUser actor,
    CommercialReportFilter filter,
    int branchId, {
    required String alias,
  }) {
    if (!filter.consolidated) {
      where.add('$alias.branch_id = ?');
      args.add(branchId);
    }
  }

  static void _addDateFilters(
    List<String> where,
    List<Object?> args,
    CommercialReportFilter filter,
    String column,
  ) {
    if (filter.from != null) {
      where.add('$column >= ?');
      args.add(filter.from!.toIso8601String());
    }
    if (filter.to != null) {
      where.add('$column < ?');
      args.add(filter.to!.toIso8601String());
    }
  }

  static void _authorize(
    StaffUser actor,
    CommercialReportFilter filter,
  ) {
    if (!actor.can(CommercialPermission.reportsView) &&
        !actor.can(CommercialPermission.reportsProfit)) {
      throw StateError('Your staff role cannot view commercial reports.');
    }
    if (filter.consolidated &&
        actor.role != StaffRole.owner &&
        actor.role != StaffRole.manager) {
      throw StateError('Consolidated reporting is not permitted.');
    }
    if (!filter.consolidated &&
        filter.branchId != null &&
        filter.branchId != actor.branchId &&
        actor.role != StaffRole.owner &&
        actor.role != StaffRole.manager) {
      throw StateError('The selected branch is outside your access scope.');
    }
  }

  static Map<String, double> _sumColumns(
    List<Map<String, Object?>> rows,
    List<String> columns,
  ) {
    return {
      for (final column in columns)
        column: MoneyMath.add(
          rows.map((row) => _number(row[column])),
        ),
    };
  }

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _csv(Object value) {
    final text = '$value';
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(
            RegExp(r'^-+|-+$'),
            '',
          );

  static String _stamp() =>
      DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());

  static String _display(String value) => value
      .split('_')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  static String _periodLabel(CommercialReportFilter filter) {
    final format = DateFormat('dd MMM yyyy');
    final from = filter.from == null ? 'All dates' : format.format(filter.from!);
    final to = filter.to == null
        ? 'All dates'
        : format.format(filter.to!.subtract(const Duration(microseconds: 1)));
    return 'Period: $from to $to';
  }
}

class _Sql {
  const _Sql(this.sql, this.args);

  final String sql;
  final List<Object?> args;
}
