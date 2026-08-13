# -*- coding: utf-8 -*-
from pathlib import Path

path = Path("lib/commercial/screens/commercial_suite_screen.dart")
text = path.read_text(encoding="utf-8")

def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    text = text.replace(old, new, 1)

replace_once(
'''  CommercialReportKind kind = CommercialReportKind.revenue;
  String period = 'this_month';
  bool consolidated = false;
  late Future<CommercialReportResult> future;
''',
'''  CommercialReportKind kind = CommercialReportKind.revenue;
  String period = 'this_month';
  bool consolidated = false;
  late int selectedBranchId;
  late Future<CommercialReportResult> future;

  static const profitKinds = <CommercialReportKind>{
    CommercialReportKind.grossProfit,
    CommercialReportKind.netProfit,
    CommercialReportKind.costOfGoodsSold,
    CommercialReportKind.profitByProduct,
    CommercialReportKind.profitByCategory,
    CommercialReportKind.profitByUser,
    CommercialReportKind.profitByBranch,
  };
''',
'report state fields')

replace_once(
'''    super.initState();
    future = _load();
''',
'''    super.initState();
    selectedBranchId = widget.user.branchId;
    future = _load();
''',
'report initState')

replace_once(
'''      consolidated: consolidated,
      branchId: consolidated ? null : widget.user.branchId,
''',
'''      consolidated: consolidated,
      branchId: consolidated ? null : selectedBranchId,
''',
'report branch filter')

replace_once(
'''    final mayConsolidate =
        widget.user.role == StaffRole.owner ||
        widget.user.role == StaffRole.manager;
    return Column(
''',
'''    final mayConsolidate =
        widget.user.role == StaffRole.owner ||
        widget.user.role == StaffRole.manager;
    final mayChooseBranch = mayConsolidate;
    final mayExport = widget.user.can(CommercialPermission.reportsExport);
    final canSeeProfit = widget.user.can(CommercialPermission.reportsProfit);
    final activeBranches = widget.state.branches
        .where((branch) => branch.isActive)
        .toList(growable: false);
    return Column(
''',
'report build permissions')

replace_once(
'''                  for (final item in CommercialReportKind.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
''',
'''                  for (final item in CommercialReportKind.values)
                    if (canSeeProfit || !profitKinds.contains(item))
                      DropdownMenuItem(value: item, child: Text(item.label)),
''',
'profit report dropdown filter')

branch_ui = '''            if (mayChooseBranch)
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('report-branch-$selectedBranchId'),
                  initialValue: selectedBranchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: [
                    for (final branch in activeBranches)
                      DropdownMenuItem(
                        value: branch.id,
                        child: Text(
                          branch.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: consolidated
                      ? null
                      : (value) {
                          if (value == null) return;
                          selectedBranchId = value;
                          reload();
                        },
                ),
              ),
            if (!mayChooseBranch)
              Chip(
                avatar: const Icon(Icons.store_outlined, size: 18),
                label: Text(_branchName(selectedBranchId)),
              ),
'''
replace_once(
'''            if (mayConsolidate)
              FilterChip(
''',
branch_ui + '''            if (mayConsolidate)
              FilterChip(
''',
'branch selector insertion')

replace_once(
'''            FilledButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
''',
'''            OutlinedButton.icon(
              onPressed: _showStaffPerformance,
              icon: const Icon(Icons.groups_2_outlined),
              label: const Text('Staff performance'),
            ),
            FilledButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
''',
'staff performance button')

replace_once('onPressed: _exportCsv,', 'onPressed: mayExport ? _exportCsv : null,', 'CSV export permission')
replace_once('onPressed: _exportXlsx,', 'onPressed: mayExport ? _exportXlsx : null,', 'XLSX export permission')
replace_once('onPressed: _previewPdf,', 'onPressed: mayExport ? _previewPdf : null,', 'PDF export permission')

methods = '''  String _branchName(int branchId) {
    for (final branch in widget.state.branches) {
      if (branch.id == branchId) return branch.name;
    }
    return 'Branch $branchId';
  }

  CommercialReportFilter _forUser(
    CommercialReportFilter base,
    int userId,
  ) => CommercialReportFilter(
    from: base.from,
    to: base.to,
    branchId: base.branchId,
    userId: userId,
    productId: base.productId,
    category: base.category,
    customerId: base.customerId,
    supplierId: base.supplierId,
    paymentMethod: base.paymentMethod,
    documentStatus: base.documentStatus,
    consolidated: base.consolidated,
  );

  CommercialReportFilter? _previousPeriodFilter() {
    final current = filter;
    if (current.from == null || current.to == null) return null;
    final span = current.to!.difference(current.from!);
    if (span <= Duration.zero) return null;
    return CommercialReportFilter(
      from: current.from!.subtract(span),
      to: current.from,
      branchId: current.branchId,
      consolidated: current.consolidated,
    );
  }

  Future<void> _showStaffPerformance() async {
    try {
      final staff = (await widget.state.commercial.listStaff(widget.user))
          .where((item) => item.isActive)
          .toList(growable: false);
      final previousBase = _previousPeriodFilter();
      final canSeeProfit = widget.user.can(CommercialPermission.reportsProfit);
      final rows = <Map<String, Object?>>[];

      for (final person in staff) {
        final currentSales = await widget.state.advancedReports.run(
          actor: widget.user,
          kind: CommercialReportKind.salesByUser,
          filter: _forUser(filter, person.id),
        );
        final currentRevenue = currentSales.totals['revenue'] ?? 0;
        final transactions = currentSales.totals['transaction_count'] ?? 0;

        double previousRevenue = 0;
        if (previousBase != null) {
          final previousSales = await widget.state.advancedReports.run(
            actor: widget.user,
            kind: CommercialReportKind.salesByUser,
            filter: _forUser(previousBase, person.id),
          );
          previousRevenue = previousSales.totals['revenue'] ?? 0;
        }

        double? grossProfit;
        if (canSeeProfit) {
          final profit = await widget.state.advancedReports.run(
            actor: widget.user,
            kind: CommercialReportKind.grossProfit,
            filter: _forUser(filter, person.id),
          );
          grossProfit = profit.totals['gross_profit'] ?? 0;
        }

        final change = currentRevenue - previousRevenue;
        final growth = previousRevenue == 0
            ? null
            : (change / previousRevenue.abs()) * 100;
        rows.add({
          'id': person.id,
          'name': person.name,
          'branch': _branchName(person.branchId),
          'transactions': transactions,
          'revenue': currentRevenue,
          'previous_revenue': previousRevenue,
          'change': change,
          'growth': growth,
          'gross_profit': grossProfit,
        });
      }

      rows.sort((a, b) =>
          (b['change'] as double).compareTo(a['change'] as double));
      if (!mounted) return;
      final best = rows.isEmpty ? null : rows.first;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Staff performance'),
          content: SizedBox(
            width: 980,
            height: 540,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (best != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.trending_up),
                      title: Text('Most improved: ${best['name']}'),
                      subtitle: Text(
                        'Revenue change ${AppFormatters.money(best['change'] as double)} '
                        'for ${periods[period] ?? period}.',
                      ),
                    ),
                  ),
                if (previousBase == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'All-dates view has no matching previous period. '
                      'Choose a dated period to compare improvement.',
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('Staff')),
                            const DataColumn(label: Text('Branch')),
                            const DataColumn(
                              label: Text('Transactions'),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text('Revenue'),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text('Previous revenue'),
                              numeric: true,
                            ),
                            const DataColumn(
                              label: Text('Improvement'),
                              numeric: true,
                            ),
                            if (canSeeProfit)
                              const DataColumn(
                                label: Text('Gross profit'),
                                numeric: true,
                              ),
                          ],
                          rows: [
                            for (final row in rows)
                              DataRow(
                                cells: [
                                  DataCell(Text('${row['name']}')),
                                  DataCell(Text('${row['branch']}')),
                                  DataCell(Text(
                                    (row['transactions'] as double)
                                        .toStringAsFixed(0),
                                  )),
                                  DataCell(Text(AppFormatters.money(
                                    row['revenue'] as double,
                                  ))),
                                  DataCell(Text(AppFormatters.money(
                                    row['previous_revenue'] as double,
                                  ))),
                                  DataCell(Text(_growthLabel(row))),
                                  if (canSeeProfit)
                                    DataCell(Text(AppFormatters.money(
                                      row['gross_profit'] as double? ?? 0,
                                    ))),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  String _growthLabel(Map<String, Object?> row) {
    final growth = row['growth'] as double?;
    final change = row['change'] as double;
    if (growth == null) {
      return change > 0 ? 'New +${AppFormatters.money(change)}' : '-';
    }
    final prefix = growth > 0 ? '+' : '';
    return '$prefix${growth.toStringAsFixed(1)}%';
  }

'''
replace_once(
'''  Future<void> _exportCsv() async {
''',
methods + '''  Future<void> _exportCsv() async {
''',
'staff performance methods')

for token in [
    'selectedBranchId',
    'Staff performance',
    'Most improved',
    'reportsExport',
    'previous_revenue',
    'profitKinds',
]:
    if token not in text:
        raise SystemExit(f"reporting upgrade missing token: {token}")

path.write_text(text, encoding="utf-8")
