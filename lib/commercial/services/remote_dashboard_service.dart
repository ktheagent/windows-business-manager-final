import 'dart:convert';
import 'dart:io';

import '../../services/database_service.dart';

class RemoteDashboardService {
  RemoteDashboardService(this._database);

  final DatabaseService _database;
  HttpServer? _server;
  String? _token;
  int? _branchId;
  bool _consolidated = false;
  final Map<String, List<DateTime>> _requests = {};

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<Uri> start({
    required String token,
    int preferredPort = 8768,
    bool exposeToLocalNetwork = false,
    int? branchId,
    bool consolidated = false,
  }) async {
    if (token.length < 32) throw ArgumentError('Remote token is too short.');
    if (!consolidated && branchId == null) {
      throw ArgumentError('A branch is required for a scoped dashboard.');
    }
    await stop();
    _token = token;
    _branchId = branchId;
    _consolidated = consolidated;
    final server = await HttpServer.bind(
      exposeToLocalNetwork
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4,
      preferredPort,
      shared: false,
    );
    _server = server;
    server.listen(_handle, onError: (_) => stop());
    return Uri.parse('http://127.0.0.1:${server.port}/?token=${Uri.encodeQueryComponent(token)}');
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _token = null;
    _branchId = null;
    _consolidated = false;
    _requests.clear();
    if (server != null) await server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('X-Frame-Options', 'DENY')
      ..set('Referrer-Policy', 'no-referrer')
      ..set(
        'Content-Security-Policy',
        "default-src 'self'; style-src 'unsafe-inline'; script-src 'none'; frame-ancestors 'none'",
      );
    final remote = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    if (!_allowRequest(remote)) {
      response.statusCode = HttpStatus.tooManyRequests;
      response.write('Too many requests.');
      await response.close();
      return;
    }

    final queryToken = request.uri.queryParameters['token'];
    final cookieToken = request.cookies
        .where((cookie) => cookie.name == 'abm_owner_session')
        .map((cookie) => cookie.value)
        .firstOrNull;
    final authorization = request.headers.value(HttpHeaders.authorizationHeader);
    final bearer = authorization?.startsWith('Bearer ') == true
        ? authorization!.substring(7)
        : null;
    final supplied = queryToken ?? cookieToken ?? bearer;
    if (supplied != _token) {
      response.statusCode = HttpStatus.unauthorized;
      response.write('Owner dashboard authorization is required.');
      await response.close();
      return;
    }
    if (queryToken != null) {
      response.cookies.add(
        Cookie('abm_owner_session', queryToken)
          ..httpOnly = true
          ..sameSite = SameSite.strict
          ..maxAge = 1800,
      );
      response.statusCode = HttpStatus.found;
      response.headers.set(HttpHeaders.locationHeader, '/');
      await response.close();
      return;
    }

    try {
      if (request.uri.path == '/api/summary') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(await _summary()));
      } else if (request.uri.path == '/') {
        response.headers.contentType = ContentType.html;
        response.write(await _html());
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write('Not found.');
      }
    } catch (error) {
      response.statusCode = HttpStatus.internalServerError;
      response.write('Dashboard data could not be loaded.');
    }
    await _logAccess(
      remoteAddress: remote,
      route: request.uri.path,
      success: response.statusCode < 400,
      statusCode: response.statusCode,
    );
    await response.close();
  }

  bool _allowRequest(String remote) {
    final now = DateTime.now();
    final recent = _requests.putIfAbsent(remote, () => <DateTime>[])
      ..removeWhere((time) => now.difference(time) > const Duration(minutes: 1));
    if (recent.length >= 60) return false;
    recent.add(now);
    return true;
  }

  Future<Map<String, Object?>> _summary() async {
    final db = await _database.database;
    final today = DateTime.now();
    final start =
        DateTime(today.year, today.month, today.day).toIso8601String();
    final branchClause = _consolidated ? '' : 'AND branch_id = ?';
    final args = _consolidated ? <Object?>[] : <Object?>[_branchId];
    final sales = await db.rawQuery(
      "SELECT COALESCE(SUM(total - returned_total),0) AS value "
      "FROM sales WHERE status='completed' AND created_at >= ? "
      "$branchClause",
      [start, ...args],
    );
    final expenses = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS value FROM expenses '
      'WHERE created_at >= ? $branchClause',
      [start, ...args],
    );
    final customerDebt = await db.rawQuery(
      'SELECT COALESCE(SUM(balance),0) AS value FROM customers '
      'WHERE is_active = 1 $branchClause',
      args,
    );
    final supplierDebt = await db.rawQuery(
      'SELECT COALESCE(SUM(balance),0) AS value FROM suppliers '
      'WHERE is_active = 1 $branchClause',
      args,
    );
    final lowStock = await db.rawQuery(
      'SELECT COUNT(*) AS value FROM branch_inventory '
      'WHERE stock_qty <= low_stock_level $branchClause',
      args,
    );
    final expiring = await db.rawQuery(
      'SELECT COUNT(*) AS value FROM product_batches '
      'WHERE quantity > 0 AND expires_at IS NOT NULL '
      'AND expires_at <= ? $branchClause',
      [
        DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        ...args,
      ],
    );
    final openCash = await db.rawQuery(
      "SELECT COUNT(*) AS value FROM cash_sessions "
      "WHERE status = 'open' $branchClause",
      args,
    );
    final cash = await db.rawQuery(
      "SELECT COALESCE(SUM(cm.amount), 0) AS value "
      "FROM cash_movements cm "
      "INNER JOIN cash_sessions cs ON cs.id = cm.cash_session_id "
      "WHERE cm.created_at >= ? "
      "${_consolidated ? '' : 'AND cs.branch_id = ?'}",
      [start, ...args],
    );
    final branches = await db.rawQuery('''
      SELECT b.name,
        COALESCE(SUM(s.total - s.returned_total), 0) AS sales
      FROM branches b
      LEFT JOIN sales s ON s.branch_id = b.id
        AND s.status = 'completed' AND s.created_at >= ?
      WHERE b.is_active = 1
        ${_consolidated ? '' : 'AND b.id = ?'}
      GROUP BY b.id ORDER BY sales DESC
    ''', [start, ...args]);
    final topProducts = await db.rawQuery('''
      SELECT si.product_name, SUM(si.quantity) AS quantity,
        SUM(si.total) AS revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed'
        ${_consolidated ? '' : 'AND s.branch_id = ?'}
      GROUP BY si.product_id, si.product_name
      ORDER BY revenue DESC LIMIT 10
    ''', args);
    final highRisk = await db.rawQuery('''
      SELECT action, entity_type, entity_id, reason, success, created_at
      FROM audit_logs
      WHERE (
        success = 0 OR action LIKE '%refund%' OR action LIKE '%void%'
        OR action LIKE '%permission%' OR action LIKE '%restore%'
        OR action LIKE '%reversed%'
      )
      ${_consolidated ? '' : 'AND branch_id = ?'}
      ORDER BY created_at DESC, id DESC LIMIT 20
    ''', args);
    return {
      'generated_at': DateTime.now().toIso8601String(),
      'scope': _consolidated ? 'consolidated' : 'branch',
      'branch_id': _branchId,
      'today_sales': _value(sales),
      'today_expenses': _value(expenses),
      'cash': _value(cash),
      'customer_debt': _value(customerDebt),
      'supplier_debt': _value(supplierDebt),
      'low_stock_count': _value(lowStock),
      'expiring_stock_count': _value(expiring),
      'open_cash_sessions': _value(openCash),
      'top_products': topProducts,
      'high_risk_audit': highRisk,
      'branches': branches,
    };
  }

  Future<String> _html() async {
    final data = await _summary();
    final branches = (data['branches'] as List<Map<String, Object?>>)
        .map((row) => '<tr><td>${_escape('${row['name']}')}</td><td>${_money(row['sales'])}</td></tr>')
        .join();
    return '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Airmonlink Owner Dashboard</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f2f5fb;color:#17233c}.wrap{max-width:1100px;margin:auto;padding:28px}.head{background:#0f2a5a;color:white;padding:24px;border-radius:18px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:14px;margin:20px 0}.card{background:white;padding:18px;border-radius:16px;box-shadow:0 6px 24px #20385a16}.label{font-size:12px;color:#667085}.value{font-size:25px;font-weight:800;margin-top:8px}.panel{background:white;padding:20px;border-radius:16px}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:11px;border-bottom:1px solid #e7ecf4}.note{font-size:12px;color:#667085;margin-top:16px}</style>
</head><body><div class="wrap"><div class="head"><h1>Airmonlink Business Manager</h1><p>Read-only owner dashboard</p></div>
<div class="grid">
${_card('Today sales', _money(data['today_sales']))}
${_card('Today expenses', _money(data['today_expenses']))}
${_card('Cash', _money(data['cash']))}
${_card('Customer debt', _money(data['customer_debt']))}
${_card('Supplier debt', _money(data['supplier_debt']))}
${_card('Low-stock items', '${(data['low_stock_count'] as num).toInt()}')}
${_card('Expiring items', '${(data['expiring_stock_count'] as num).toInt()}')}
${_card('Open cash sessions', '${(data['open_cash_sessions'] as num).toInt()}')}
</div><div class="panel"><h2>Branch performance today</h2><table><thead><tr><th>Branch</th><th>Sales</th></tr></thead><tbody>$branches</tbody></table></div>
<p class="note">Generated ${_escape('${data['generated_at']}')}. This dashboard cannot modify business records.</p></div></body></html>''';
  }

  Future<void> _logAccess({
    required String remoteAddress,
    required String route,
    required bool success,
    required int statusCode,
  }) async {
    try {
      final db = await _database.database;
      await db.insert('remote_dashboard_access_logs', {
        'branch_id': _consolidated ? null : _branchId,
        'remote_address': remoteAddress,
        'route': route,
        'success': success ? 1 : 0,
        'status_code': statusCode,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Access logging must not expose local database errors to remote clients.
    }
  }

  static String _card(String label, String value) =>
      '<div class="card"><div class="label">${_escape(label)}</div><div class="value">${_escape(value)}</div></div>';

  static num _value(List<Map<String, Object?>> rows) =>
      rows.isEmpty ? 0 : (rows.first['value'] as num? ?? 0);

  static String _money(Object? value) =>
      'GHS ${(value as num? ?? 0).toStringAsFixed(2)}';

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
