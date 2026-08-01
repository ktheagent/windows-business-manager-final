import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../core/formatters.dart';
import '../../models/product.dart';
import '../../state/app_state.dart';
import '../../widgets/feedback.dart';
import '../../widgets/page_header.dart';
import '../../widgets/pdf_preview_dialog.dart';
import '../models/commercial_models.dart';
import '../services/advanced_report_service.dart';
import 'document_editor_dialog.dart';
import 'stock_transfer_dialog.dart';

class CommercialSuiteScreen extends StatefulWidget {
  const CommercialSuiteScreen({super.key});

  @override
  State<CommercialSuiteScreen> createState() => _CommercialSuiteScreenState();
}

class _CommercialSuiteScreenState extends State<CommercialSuiteScreen> {
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = state.currentUser;
    if (user == null) return const SizedBox.shrink();
    final tabs = <_SuiteTab>[
      const _SuiteTab('Health', Icons.monitor_heart_outlined),
      if (user.can(CommercialPermission.documentsManage))
        const _SuiteTab('Documents', Icons.description_outlined),
      if (user.can(CommercialPermission.reportsView) ||
          user.can(CommercialPermission.reportsProfit))
        const _SuiteTab('Reports', Icons.analytics_outlined),
      if (user.can(CommercialPermission.debtView))
        const _SuiteTab('Customer debt', Icons.account_balance_wallet_outlined),
      if (user.can(CommercialPermission.purchasingManage))
        const _SuiteTab('Purchasing', Icons.shopping_cart_checkout_outlined),
      if (user.can(CommercialPermission.stockAdjust) ||
          user.can(CommercialPermission.stockCount))
        const _SuiteTab('Inventory', Icons.inventory_outlined),
      if (user.can(CommercialPermission.cashManage) ||
          user.can(CommercialPermission.salesRefund))
        const _SuiteTab('Cash & returns', Icons.point_of_sale_outlined),
      if (user.can(CommercialPermission.staffManage) ||
          user.can(CommercialPermission.branchesManage))
        const _SuiteTab(
          'Staff & branches',
          Icons.admin_panel_settings_outlined,
        ),
      if (user.can(CommercialPermission.backupsManage) ||
          user.can(CommercialPermission.importsManage) ||
          user.can(CommercialPermission.remoteDashboard) ||
          user.can(CommercialPermission.updatesManage))
        const _SuiteTab('Premium tools', Icons.workspace_premium_outlined),
      if (user.can(CommercialPermission.auditView))
        const _SuiteTab('Audit', Icons.manage_search_outlined),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Commercial Suite',
              subtitle:
                  'Documents, purchasing, stock control, staff security and premium operations.',
            ),
            const SizedBox(height: 16),
            Card(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final tab in tabs)
                    Tab(icon: Icon(tab.icon), text: tab.label),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  for (final tab in tabs) _buildTab(tab.label, state, user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, AppState state, StaffUser user) =>
      switch (label) {
        'Health' => _HealthPanel(state: state, user: user),
        'Documents' => _DocumentsPanel(state: state, user: user),
        'Reports' => _ReportsPanel(state: state, user: user),
        'Customer debt' => _CustomerDebtPanel(state: state, user: user),
        'Purchasing' => _PurchasingPanel(state: state, user: user),
        'Inventory' => _InventoryPanel(state: state, user: user),
        'Cash & returns' => _CashReturnsPanel(state: state, user: user),
        'Staff & branches' => _StaffBranchesPanel(state: state, user: user),
        'Premium tools' => _PremiumToolsPanel(state: state, user: user),
        'Audit' => _AuditPanel(state: state, user: user),
        _ => const SizedBox.shrink(),
      };
}

class _SuiteTab {
  const _SuiteTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    final consolidated =
        user.role == StaffRole.owner || user.role == StaffRole.manager;
    return FutureBuilder<BusinessHealthSnapshot>(
      future: state.commercial.businessHealth(
        actor: user,
        consolidated: consolidated,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorCard(snapshot.error!);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final health = snapshot.data!;
        final metrics = <(String, double, IconData)>[
          ('Revenue', health.revenue, Icons.payments_outlined),
          ('Gross profit', health.grossProfit, Icons.trending_up),
          ('Expenses', health.expenses, Icons.receipt_long_outlined),
          (
            'Net profit',
            health.netProfit,
            Icons.account_balance_wallet_outlined,
          ),
          ('Customer debt', health.customerDebt, Icons.people_outline),
          ('Supplier debt', health.supplierDebt, Icons.local_shipping_outlined),
          ('Cash variance', health.cashVariance, Icons.warning_amber_outlined),
        ];
        return RefreshIndicator(
          onRefresh: state.refreshAll,
          child: ListView(
            children: [
              if (user.can(CommercialPermission.reportsProfit)) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _exportProfit(context),
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Export profit CSV'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _previewProfit(context),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Profit report'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 130,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  final item = metrics[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$3),
                          const Spacer(),
                          Text(item.$1),
                          Text(
                            AppFormatters.money(item.$2),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operational alerts',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.inventory_2_outlined),
                            label: Text(
                              '${health.lowStockCount} low-stock items',
                            ),
                          ),
                          Chip(
                            avatar: const Icon(Icons.event_busy_outlined),
                            label: Text(
                              '${health.expiringCount} expiring batches',
                            ),
                          ),
                          Chip(
                            avatar: const Icon(Icons.undo_outlined),
                            label: Text(
                              '${(health.refundRate * 100).toStringAsFixed(1)}% refund rate',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (final suggestion in health.suggestions)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lightbulb_outline),
                          title: Text(suggestion),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _previewProfit(BuildContext context) async {
    final consolidated =
        user.role == StaffRole.owner || user.role == StaffRole.manager;
    await showDialog<void>(
      context: context,
      builder: (_) => AppPdfPreviewDialog(
        title: consolidated
            ? 'Consolidated profit report'
            : 'Branch profit report',
        fileName: 'Airmonlink-Profit-Report.pdf',
        initialPageFormat: PdfPageFormat.a4.landscape,
        pageFormats: {'A4 landscape': PdfPageFormat.a4.landscape},
        canChangeOrientation: false,
        canChangePageFormat: false,
        buildPdf: (_) => state.commercialReports.buildProfitPdf(
          actor: user,
          businessName: state.businessName,
          consolidated: consolidated,
        ),
      ),
    );
  }

  Future<void> _exportProfit(BuildContext context) async {
    try {
      final path = await state.commercialReports.exportProfitCsv(
        actor: user,
        consolidated:
            user.role == StaffRole.owner || user.role == StaffRole.manager,
      );
      if (context.mounted)
        showSuccess(context, 'Profit report exported: $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}

class _DocumentsPanel extends StatefulWidget {
  const _DocumentsPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  State<_DocumentsPanel> createState() => _DocumentsPanelState();
}

class _DocumentsPanelState extends State<_DocumentsPanel> {
  late Future<List<Map<String, Object?>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.state.commercial.listDocuments(widget.user);
  }

  void reload() => setState(() {
    future = widget.state.commercial.listDocuments(widget.user);
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _createDocument(context),
            icon: const Icon(Icons.add),
            label: const Text('New document'),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorCard(snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const _EmptyState(
                  icon: Icons.description_outlined,
                  message: 'No quotations or invoices yet.',
                );
              }
              return ListView.separated(
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final document = snapshot.data![index];
                  final id = document['id'] as int;
                  final type = (document['document_type'] as String).replaceAll(
                    '_',
                    ' ',
                  );
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          type == 'invoice'
                              ? Icons.request_quote_outlined
                              : Icons.description_outlined,
                        ),
                      ),
                      title: Text('${document['document_no']} • $type'),
                      subtitle: Text(
                        '${document['customer_name'] ?? 'Walk-in customer'} • '
                        '${document['status']} • ${AppFormatters.money((document['total'] as num).toDouble())}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            _documentAction(context, document, value),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'preview',
                            child: Text('Preview / print'),
                          ),
                          if (document['status'] == 'draft')
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit draft'),
                            ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicate document'),
                          ),
                          const PopupMenuItem(
                            value: 'history',
                            child: Text('Status history'),
                          ),
                          if ({'draft', 'issued'}.contains(document['status']))
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Text('Cancel document'),
                            ),
                          if (document['status'] == 'draft')
                            const PopupMenuItem(
                              value: 'issue',
                              child: Text('Issue document'),
                            ),
                          if (document['document_type'] == 'quotation' &&
                              document['status'] != 'converted')
                            const PopupMenuItem(
                              value: 'invoice',
                              child: Text('Convert to invoice'),
                            ),
                          if (document['converted_sale_id'] == null)
                            const PopupMenuItem(
                              value: 'sale',
                              child: Text('Convert to sale'),
                            ),
                          if (document['document_type'] == 'invoice' &&
                              (document['balance_due'] as num? ?? 0)
                                      .toDouble() >
                                  0)
                            const PopupMenuItem(
                              value: 'payment',
                              child: Text('Record payment'),
                            ),
                          if ('${document['customer_phone'] ?? ''}'.isNotEmpty)
                            const PopupMenuItem(
                              value: 'whatsapp',
                              child: Text('Send with WhatsApp'),
                            ),
                          if ('${document['customer_email'] ?? ''}'.isNotEmpty)
                            const PopupMenuItem(
                              value: 'email',
                              child: Text('Send by email'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createDocument(BuildContext context) async {
    final draft = await showDialog<CommercialDocumentDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CommercialDocumentEditorDialog(
        products: widget.state.products,
        customers: widget.state.customers,
      ),
    );
    if (draft == null || !mounted) return;
    try {
      await widget.state.createDocument(draft);
      if (!mounted) return;
      showSuccess(context, 'Document draft created.');
      reload();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<CommercialDocumentDraft> _documentDraft(
    Map<String, Object?> document,
  ) async {
    final rows = await widget.state.commercial.documentItems(
      document['id'] as int,
    );
    return CommercialDocumentDraft(
      type: document['document_type'] as String,
      customerId: document['customer_id'] as int?,
      items: rows
          .map(
            (row) => CommercialDocumentItem(
              productId: row['product_id'] as int?,
              description: row['description'] as String? ?? '',
              quantity: (row['quantity'] as num? ?? 0).toDouble(),
              unit: row['unit'] as String? ?? 'each',
              unitPrice: (row['unit_price'] as num? ?? 0).toDouble(),
              costPrice: (row['cost_price'] as num? ?? 0).toDouble(),
              lineDiscount: (row['line_discount'] as num? ?? 0).toDouble(),
              taxRate: (row['tax_rate'] as num? ?? 0).toDouble(),
              taxInclusive: (row['tax_inclusive'] as num? ?? 0).toInt() == 1,
            ),
          )
          .toList(growable: false),
      discount: (document['discount'] as num? ?? 0).toDouble(),
      tax: (document['tax'] as num? ?? 0).toDouble(),
      notes: document['notes'] as String? ?? '',
      terms: document['terms'] as String? ?? '',
      validUntil: _parseDate(document['valid_until']),
      dueAt: _parseDate(document['due_at']),
      paymentInstructions: document['payment_instructions'] as String? ?? '',
      documentDate: _parseDate(document['document_date']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }

  Future<String?> _askText(
    BuildContext context,
    String title, {
    bool required = true,
  }) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _showHistory(BuildContext context, int documentId) async {
    final history = await widget.state.commercial.documentStatusHistory(
      actor: widget.user,
      documentId: documentId,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document status history'),
        content: SizedBox(
          width: 620,
          child: history.isEmpty
              ? const Text('No status events were recorded.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final row = history[index];
                    return ListTile(
                      title: Text(
                        '${row['old_status'] ?? ''} → ${row['new_status'] ?? ''}',
                      ),
                      subtitle: Text(
                        '${row['changed_by_name'] ?? 'System'} • '
                        '${row['changed_at'] ?? ''}\n${row['reason'] ?? ''}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _documentAction(
    BuildContext context,
    Map<String, Object?> document,
    String action,
  ) async {
    final id = document['id'] as int;
    try {
      switch (action) {
        case 'edit':
          final current = await _documentDraft(document);
          if (!mounted) return;
          final revised = await showDialog<CommercialDocumentDraft>(
            context: context,
            barrierDismissible: false,
            builder: (_) => CommercialDocumentEditorDialog(
              products: widget.state.products,
              customers: widget.state.customers,
              initialDraft: current,
            ),
          );
          if (revised == null) return;
          await widget.state.commercial.updateDocumentDraft(
            actor: widget.user,
            documentId: id,
            draft: revised,
          );
          break;
        case 'duplicate':
          await widget.state.commercial.duplicateDocument(
            actor: widget.user,
            documentId: id,
          );
          break;
        case 'history':
          await _showHistory(context, id);
          return;
        case 'cancel':
          final reason = await _askText(context, 'Cancel document');
          if (reason == null) return;
          await widget.state.commercial.cancelDocument(
            actor: widget.user,
            documentId: id,
            reason: reason,
          );
          break;
        case 'preview':
          await showDialog<void>(
            context: context,
            builder: (_) => AppPdfPreviewDialog(
              title: 'Commercial document',
              buildPdf: (_) => widget.state.buildCommercialDocumentPdf(id),
              fileName: 'commercial-document-$id.pdf',
              initialPageFormat: PdfPageFormat.a4,
              pageFormats: const {'A4': PdfPageFormat.a4},
            ),
          );
          break;
        case 'issue':
          await widget.state.commercial.issueDocument(
            actor: widget.user,
            documentId: id,
          );
          break;
        case 'invoice':
          await widget.state.commercial.convertQuotationToInvoice(
            actor: widget.user,
            quotationId: id,
          );
          break;
        case 'sale':
          await widget.state.commercial.convertDocumentToSale(
            actor: widget.user,
            documentId: id,
            paymentMethod: 'Credit',
            cashSessionId: widget.state.currentCashSession?['id'] as int?,
          );
          break;
        case 'payment':
          final amount = await _askNumber(context, 'Payment amount');
          if (amount == null) return;
          await widget.state.commercial.recordDocumentPayment(
            actor: widget.user,
            documentId: id,
            amount: amount,
            paymentMethod: widget.state.currentCashSession == null
                ? 'Bank'
                : 'Cash',
            reference: '',
            cashSessionId: widget.state.currentCashSession?['id'] as int?,
          );
          break;
        case 'whatsapp':
          final path = await widget.state.exportCommercialDocument(id);
          await widget.state.notifications.openWhatsApp(
            phone: '${document['customer_phone']}',
            message:
                'Your ${document['document_type']} ${document['document_no']} is ready. The PDF was saved at $path.',
            documentType: '${document['document_type']}',
            documentId: id,
          );
          break;
        case 'email':
          final password = await widget.state.secureConfig.smtpPassword();
          final host = widget.state.settings['smtp_host'] ?? '';
          final username = widget.state.settings['smtp_username'] ?? '';
          if (host.isEmpty || username.isEmpty || password == null) {
            throw StateError('Configure SMTP settings before sending email.');
          }
          final path = await widget.state.exportCommercialDocument(id);
          await widget.state.notifications.sendEmail(
            host: host,
            port: int.tryParse(widget.state.settings['smtp_port'] ?? '') ?? 587,
            ssl: widget.state.settings['smtp_ssl'] == 'true',
            username: username,
            password: password,
            senderName:
                widget.state.settings['smtp_sender_name'] ??
                widget.state.businessName,
            recipient: '${document['customer_email']}',
            subject: '${document['document_type']} ${document['document_no']}',
            body: 'Please find your document attached.',
            attachmentPath: path,
            documentType: '${document['document_type']}',
            documentId: id,
          );
          break;
      }
      if (!mounted) return;
      await widget.state.refreshAll();
      showSuccess(context, 'Document updated.');
      reload();
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
}

class _ReportsPanel extends StatefulWidget {
  const _ReportsPanel({required this.state, required this.user});

  final AppState state;
  final StaffUser user;

  @override
  State<_ReportsPanel> createState() => _ReportsPanelState();
}

class _ReportsPanelState extends State<_ReportsPanel> {
  CommercialReportKind kind = CommercialReportKind.revenue;
  String period = 'this_month';
  bool consolidated = false;
  late Future<CommercialReportResult> future;

  static const periods = <String, String>{
    'today': 'Today',
    'yesterday': 'Yesterday',
    'this_week': 'This week',
    'last_week': 'Last week',
    'this_month': 'This month',
    'last_month': 'Last month',
    'this_quarter': 'This quarter',
    'this_year': 'This year',
    'all': 'All dates',
  };

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  CommercialReportFilter get filter {
    final base = CommercialReportFilter.period(period);
    return base.copyWith(
      consolidated: consolidated,
      branchId: consolidated ? null : widget.user.branchId,
    );
  }

  Future<CommercialReportResult> _load() => widget.state.advancedReports.run(
    actor: widget.user,
    kind: kind,
    filter: filter,
  );

  void reload() {
    setState(() {
      future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mayConsolidate =
        widget.user.role == StaffRole.owner ||
        widget.user.role == StaffRole.manager;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<CommercialReportKind>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Report'),
                items: [
                  for (final item in CommercialReportKind.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  kind = value;
                  reload();
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Period'),
                items: [
                  for (final entry in periods.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  period = value;
                  reload();
                },
              ),
            ),
            if (mayConsolidate)
              FilterChip(
                label: const Text('All branches'),
                selected: consolidated,
                onSelected: (value) {
                  consolidated = value;
                  reload();
                },
              ),
            FilledButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            OutlinedButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.table_view_outlined),
              label: const Text('CSV'),
            ),
            OutlinedButton.icon(
              onPressed: _exportXlsx,
              icon: const Icon(Icons.grid_on_outlined),
              label: const Text('XLSX'),
            ),
            OutlinedButton.icon(
              onPressed: _previewPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF / print'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<CommercialReportResult>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _ErrorCard(snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final result = snapshot.data!;
              if (result.isEmpty) {
                return _EmptyState(
                  icon: Icons.query_stats_outlined,
                  message:
                      'No actual database records match the selected report filters.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.totals.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final entry in result.totals.entries)
                          Chip(
                            label: Text(
                              '${_label(entry.key)}: '
                              '${entry.value.toStringAsFixed(2)}',
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 150,
                    child: _ActualDataBarChart(result: result),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: [
                                for (final column in result.columns)
                                  DataColumn(label: Text(_label(column))),
                              ],
                              rows: [
                                for (final row in result.rows)
                                  DataRow(
                                    cells: [
                                      for (final column in result.columns)
                                        DataCell(
                                          SelectableText(
                                            '${row[column] ?? ''}',
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _exportCsv() async {
    try {
      final result = await future;
      final path = await widget.state.advancedReports.exportCsv(result);
      if (mounted) showSuccess(context, 'CSV exported: $path');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _exportXlsx() async {
    try {
      final result = await future;
      final path = await widget.state.advancedReports.exportXlsx(result);
      if (mounted) showSuccess(context, 'XLSX exported: $path');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _previewPdf() async {
    try {
      final result = await future;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AppPdfPreviewDialog(
          title: '${kind.label} report',
          fileName: '${kind.name}-report.pdf',
          initialPageFormat: PdfPageFormat.a4.landscape,
          pageFormats: const {'A4 landscape': PdfPageFormat.a4.landscape},
          buildPdf: (_) => widget.state.advancedReports.buildPdf(
            result: result,
            businessName: widget.state.businessName,
          ),
        ),
      );
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  static String _label(String value) => value
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _ActualDataBarChart extends StatelessWidget {
  const _ActualDataBarChart({required this.result});

  final CommercialReportResult result;

  @override
  Widget build(BuildContext context) {
    final labelColumn = result.columns.first;
    String? valueColumn;
    for (final column in result.columns.skip(1)) {
      if (result.rows.any((row) => row[column] is num)) {
        valueColumn = column;
        break;
      }
    }
    if (valueColumn == null) {
      return const Center(
        child: Text('This report has no numeric chart series.'),
      );
    }
    final rows = result.rows.take(12).toList(growable: false);
    final maximum = rows.fold<double>(0, (current, row) {
      final value = (row[valueColumn] as num? ?? 0).toDouble().abs();
      return value > current ? value : current;
    });
    if (maximum <= 0) {
      return const Center(
        child: Text('There is not enough numeric data to chart.'),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final row in rows)
              Expanded(
                child: Tooltip(
                  message: '${row[labelColumn]}: ${row[valueColumn] ?? 0}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor:
                                  ((row[valueColumn] as num? ?? 0)
                                              .toDouble()
                                              .abs() /
                                          maximum)
                                      .clamp(0.04, 1),
                              widthFactor: 0.75,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${row[labelColumn] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerDebtPanel extends StatefulWidget {
  const _CustomerDebtPanel({required this.state, required this.user});

  final AppState state;
  final StaffUser user;

  @override
  State<_CustomerDebtPanel> createState() => _CustomerDebtPanelState();
}

class _CustomerDebtPanelState extends State<_CustomerDebtPanel> {
  late Future<List<Map<String, Object?>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.state.commercial.listCustomerAccounts(widget.user);
  }

  void reload() => setState(() {
    future = widget.state.commercial.listCustomerAccounts(widget.user);
  });

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _ErrorCard(snapshot.error!);
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final accounts = snapshot.data!;
      if (accounts.isEmpty) {
        return const _EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          message: 'No customer accounts are available in this branch.',
        );
      }
      return Card(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Customer')),
                DataColumn(label: Text('Balance'), numeric: true),
                DataColumn(label: Text('Overdue'), numeric: true),
                DataColumn(label: Text('Credit limit'), numeric: true),
                DataColumn(label: Text('Credit status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: accounts
                  .map((account) {
                    final enabled =
                        (account['credit_enabled'] as num? ?? 1).toInt() == 1;
                    final balance = (account['balance'] as num? ?? 0)
                        .toDouble();
                    final overdue = (account['overdue_balance'] as num? ?? 0)
                        .toDouble();
                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${account['name']}'),
                              if ('${account['phone'] ?? ''}'.isNotEmpty)
                                Text(
                                  '${account['phone']}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        DataCell(Text(AppFormatters.money(balance))),
                        DataCell(
                          Text(
                            AppFormatters.money(overdue),
                            style: TextStyle(
                              color: overdue > 0
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                              fontWeight: overdue > 0 ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            AppFormatters.money(
                              (account['credit_limit'] as num? ?? 0).toDouble(),
                            ),
                          ),
                        ),
                        DataCell(
                          Chip(
                            avatar: Icon(
                              enabled
                                  ? Icons.check_circle_outline
                                  : Icons.block,
                              size: 17,
                            ),
                            label: Text(enabled ? 'Enabled' : 'Blocked'),
                          ),
                        ),
                        DataCell(
                          Wrap(
                            spacing: 4,
                            children: [
                              if (widget.user.can(
                                CommercialPermission.debtPayment,
                              ))
                                TextButton(
                                  onPressed: () => _credit(context, account),
                                  child: const Text('Credit'),
                                ),
                              if (balance > 0 &&
                                  widget.user.can(
                                    CommercialPermission.debtPayment,
                                  ))
                                TextButton(
                                  onPressed: () => _payment(context, account),
                                  child: const Text('Payment'),
                                ),
                              TextButton(
                                onPressed: () => _statement(context, account),
                                child: const Text('Statement'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      );
    },
  );

  Future<void> _credit(
    BuildContext context,
    Map<String, Object?> account,
  ) async {
    final limit = TextEditingController(
      text: (account['credit_limit'] as num? ?? 0).toStringAsFixed(2),
    );
    final reason = TextEditingController();
    var enabled = (account['credit_enabled'] as num? ?? 1).toInt() == 1;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Credit settings — ${account['name']}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow credit sales'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                TextField(
                  controller: limit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Credit limit'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason or approval note',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final parsed = double.tryParse(limit.text.trim());
    if (parsed == null || parsed < 0) {
      if (context.mounted) showFailure(context, 'Enter a valid credit limit.');
      return;
    }
    try {
      await widget.state.commercial.setCustomerCredit(
        actor: widget.user,
        customerId: account['id'] as int,
        enabled: enabled,
        creditLimit: parsed,
        reason: reason.text.trim(),
      );
      await widget.state.refreshAll();
      reload();
      if (context.mounted) showSuccess(context, 'Customer credit updated.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _payment(
    BuildContext context,
    Map<String, Object?> account,
  ) async {
    final amount = TextEditingController(
      text: (account['balance'] as num? ?? 0).toStringAsFixed(2),
    );
    final reference = TextEditingController();
    var method = 'Bank';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Record payment — ${account['name']}'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    helperText:
                        'Outstanding: ${AppFormatters.money((account['balance'] as num? ?? 0).toDouble())}',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  items: const ['Bank', 'Cash', 'Mobile Money', 'Card']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => method = value ?? method),
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(labelText: 'Reference'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final parsed = double.tryParse(amount.text.trim());
    if (parsed == null || parsed <= 0) {
      if (context.mounted)
        showFailure(context, 'Enter a valid payment amount.');
      return;
    }
    try {
      await widget.state.commercial.recordCustomerPayment(
        actor: widget.user,
        customerId: account['id'] as int,
        amount: parsed,
        paymentMethod: method,
        reference: reference.text.trim(),
        cashSessionId: method == 'Cash'
            ? (widget.state.currentCashSession?['id'] as int?)
            : null,
      );
      await widget.state.refreshAll();
      reload();
      if (context.mounted) showSuccess(context, 'Customer payment recorded.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _statement(
    BuildContext context,
    Map<String, Object?> account,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AppPdfPreviewDialog(
        title: 'Customer statement — ${account['name']}',
        fileName: 'Customer-Statement-${account['id']}.pdf',
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const {'A4': PdfPageFormat.a4},
        canChangeOrientation: false,
        canChangePageFormat: false,
        buildPdf: (_) =>
            widget.state.commercialDocuments.buildCustomerStatementPdf(
              customerId: account['id'] as int,
              branchId: widget.user.branchId,
              settings: widget.state.settings,
            ),
      ),
    );
  }
}

class _PurchasingPanel extends StatefulWidget {
  const _PurchasingPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  State<_PurchasingPanel> createState() => _PurchasingPanelState();
}

class _PurchasingPanelState extends State<_PurchasingPanel> {
  late Future<List<Map<String, Object?>>> future;
  @override
  void initState() {
    super.initState();
    future = widget.state.commercial.listPurchaseOrders(widget.user);
  }

  void reload() => setState(
    () => future = widget.state.commercial.listPurchaseOrders(widget.user),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('New purchase order'),
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorCard(snapshot.error!);
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty) {
              return const _EmptyState(
                icon: Icons.shopping_cart_outlined,
                message: 'No purchase orders yet.',
              );
            }
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final order = snapshot.data![index];
                return Card(
                  child: ListTile(
                    title: Text(
                      '${order['po_no']} • ${order['supplier_name']}',
                    ),
                    subtitle: Text(
                      '${order['status']} • ${AppFormatters.money((order['total'] as num).toDouble())} • Balance ${AppFormatters.money((order['balance_due'] as num).toDouble())}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => _action(context, order, value),
                      itemBuilder: (_) => [
                        if (order['status'] != 'received' &&
                            order['status'] != 'cancelled')
                          const PopupMenuItem(
                            value: 'receive',
                            child: Text('Receive outstanding stock'),
                          ),
                        const PopupMenuItem(
                          value: 'pay',
                          child: Text('Record supplier payment'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );

  Future<void> _create(BuildContext context) async {
    if (widget.state.suppliers.isEmpty || widget.state.products.isEmpty) {
      showFailure(context, 'Add a supplier and product first.');
      return;
    }
    final supplier = widget.state.suppliers.first;
    final product = widget.state.products.first;
    final quantity = await _askNumber(context, 'Order quantity');
    if (quantity == null) return;
    try {
      await widget.state.commercial.createPurchaseOrder(
        actor: widget.user,
        supplierId: supplier.id!,
        items: [
          {
            'product_id': product.id,
            'description': product.name,
            'quantity': quantity,
            'unit_cost': product.costPrice,
            'tax_rate': 0.0,
          },
        ],
      );
      if (mounted) {
        showSuccess(context, 'Purchase order created.');
        reload();
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _action(
    BuildContext context,
    Map<String, Object?> order,
    String action,
  ) async {
    try {
      final id = order['id'] as int;
      if (action == 'receive') {
        final items = await widget.state.commercial.purchaseOrderItems(
          actor: widget.user,
          purchaseOrderId: id,
        );
        final quantities = <int, double>{};
        for (final item in items) {
          final outstanding =
              (item['ordered_qty'] as num).toDouble() -
              (item['received_qty'] as num).toDouble();
          if (outstanding > 0) quantities[item['id'] as int] = outstanding;
        }
        await widget.state.commercial.receivePurchaseOrder(
          actor: widget.user,
          purchaseOrderId: id,
          quantitiesByItemId: quantities,
        );
      } else {
        final amount = await _askNumber(context, 'Supplier payment amount');
        if (amount == null) return;
        await widget.state.commercial.recordSupplierPayment(
          actor: widget.user,
          supplierId: order['supplier_id'] as int,
          purchaseOrderId: id,
          amount: amount,
          paymentMethod: widget.state.currentCashSession == null
              ? 'Bank'
              : 'Cash',
          reference: '',
          cashSessionId: widget.state.currentCashSession?['id'] as int?,
        );
      }
      await widget.state.refreshAll();
      if (mounted) {
        showSuccess(context, 'Purchase record updated.');
        reload();
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: user.can(CommercialPermission.reportsView)
        ? state.commercial.lowStockSuggestions(user)
        : Future.value(const []),
    builder: (context, snapshot) => ListView(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (user.can(CommercialPermission.stockAdjust))
              _ActionCard(
                icon: Icons.tune,
                title: 'Stock adjustment',
                subtitle:
                    'Record damaged, expired, missing or corrected stock.',
                onPressed: () => _adjust(context),
              ),
            if (user.can(CommercialPermission.stockCount))
              _ActionCard(
                icon: Icons.fact_check_outlined,
                title: 'Physical stock count',
                subtitle:
                    'Freeze expected quantities, count and approve discrepancies.',
                onPressed: () => _count(context),
              ),
            _ActionCard(
              icon: Icons.qr_code_2,
              title: 'Barcode labels',
              subtitle: 'Generate printable Code 128, EAN or UPC labels.',
              onPressed: () => _labels(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Low-stock purchasing suggestions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (snapshot.hasError) _ErrorCard(snapshot.error!),
        if (!snapshot.hasData) const Center(child: CircularProgressIndicator()),
        for (final item in snapshot.data ?? const <Map<String, Object?>>[])
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(item['name'] as String),
              subtitle: Text(
                'Stock ${item['stock_qty']} • Reorder level ${item['low_stock_level']}',
              ),
              trailing: Text('Suggested ${item['suggested_quantity']}'),
            ),
          ),
      ],
    ),
  );

  Future<void> _adjust(BuildContext context) async {
    if (state.products.isEmpty) return;
    final amount = await _askNumber(
      context,
      'Quantity change (use negative to reduce)',
    );
    if (amount == null) return;
    try {
      await state.commercial.adjustStock(
        actor: user,
        productId: state.products.first.id!,
        quantityChange: amount,
        reason: amount < 0 ? 'Damaged' : 'Correction',
        note: 'Commercial Suite adjustment',
      );
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Stock adjusted.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _count(BuildContext context) async {
    try {
      final id = await state.commercial.startStockCount(
        actor: user,
        notes: 'Physical count',
      );
      final items = await state.commercial.stockCountItems(
        actor: user,
        stockCountId: id,
      );
      for (final item in items) {
        await state.commercial.saveStockCountQuantity(
          actor: user,
          stockCountId: id,
          productId: item['product_id'] as int,
          countedQuantity: (item['expected_qty'] as num).toDouble(),
        );
      }
      await state.commercial.approveStockCount(actor: user, stockCountId: id);
      await state.refreshAll();
      if (context.mounted)
        showSuccess(
          context,
          'Stock count created and approved with current quantities.',
        );
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _labels(BuildContext context) async {
    if (state.products.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AppPdfPreviewDialog(
        title: 'Barcode labels',
        buildPdf: (_) =>
            state.buildBarcodeLabels(state.products.take(30).toList()),
        fileName: 'barcode-labels.pdf',
        initialPageFormat: PdfPageFormat.a4,
        pageFormats: const {'A4': PdfPageFormat.a4},
      ),
    );
  }
}

class _CashReturnsPanel extends StatefulWidget {
  const _CashReturnsPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  State<_CashReturnsPanel> createState() => _CashReturnsPanelState();
}

class _CashReturnsPanelState extends State<_CashReturnsPanel> {
  @override
  Widget build(BuildContext context) {
    final session = widget.state.currentCashSession;
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.point_of_sale, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session == null
                            ? 'No open cash session'
                            : 'Cash session is open',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        session == null
                            ? 'Open a shift before accepting cash.'
                            : 'Opening float: ${AppFormatters.money((session['opening_float'] as num).toDouble())}',
                      ),
                    ],
                  ),
                ),
                if (widget.user.can(CommercialPermission.cashManage))
                  FilledButton(
                    onPressed: session == null
                        ? () => _open(context)
                        : () => _close(context),
                    child: Text(session == null ? 'Open shift' : 'Close shift'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.user.can(CommercialPermission.salesRefund))
          _ActionCard(
            icon: Icons.assignment_return_outlined,
            title: 'Return and refund',
            subtitle:
                'Return full or partial quantities and restore sale-linked stock.',
            onPressed: () => _return(context),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final float = await _askNumber(context, 'Opening cash float');
    if (float == null) return;
    try {
      final registers = await widget.state.commercial.listCashRegisters(
        widget.user,
      );
      if (registers.isEmpty)
        throw StateError('No cash register is configured.');
      await widget.state.commercial.openCashSession(
        actor: widget.user,
        registerId: registers.first['id'] as int,
        openingFloat: float,
      );
      await widget.state.refreshAll();
      if (mounted) showSuccess(context, 'Cash shift opened.');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _close(BuildContext context) async {
    final actual = await _askNumber(context, 'Actual cash counted');
    if (actual == null) return;
    try {
      final result = await widget.state.commercial.closeCashSession(
        actor: widget.user,
        cashSessionId: widget.state.currentCashSession!['id'] as int,
        actualCash: actual,
        note: '',
      );
      await widget.state.refreshAll();
      if (mounted)
        showSuccess(
          context,
          'Shift closed. Variance: ${AppFormatters.money(result['variance']!)}',
        );
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _return(BuildContext context) async {
    final completed = widget.state.sales;
    if (completed.isEmpty) {
      showFailure(context, 'No completed sale is available for return.');
      return;
    }
    try {
      final sale = completed.first;
      final items = await widget.state.commercial.returnableSaleItems(
        actor: widget.user,
        saleId: sale.id!,
      );
      final item = items.cast<Map<String, Object?>>().firstWhere(
        (row) => (row['returnable_quantity'] as num).toDouble() > 0,
      );
      final quantity = await _askNumber(context, 'Return quantity');
      if (quantity == null) return;
      await widget.state.commercial.createReturn(
        actor: widget.user,
        saleId: sale.id!,
        quantitiesBySaleItemId: {item['id'] as int: quantity},
        refundMethod: widget.state.currentCashSession == null
            ? 'Store credit'
            : 'Cash',
        reason: 'Customer return',
        restock: true,
        cashSessionId: widget.state.currentCashSession?['id'] as int?,
      );
      await widget.state.refreshAll();
      if (mounted) showSuccess(context, 'Return recorded.');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
}

class _StaffBranchesPanel extends StatelessWidget {
  const _StaffBranchesPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (user.can(CommercialPermission.staffManage))
            _ActionCard(
              icon: Icons.person_add_alt_1,
              title: 'Add staff account',
              subtitle: 'Assign a secure role and branch.',
              onPressed: () => _addStaff(context),
            ),
          if (user.can(CommercialPermission.branchesManage))
            _ActionCard(
              icon: Icons.add_business_outlined,
              title: 'Add branch',
              subtitle: 'Create separate inventory, staff and cash register.',
              onPressed: () => _addBranch(context),
            ),
          if (user.can(CommercialPermission.branchesManage))
            _ActionCard(
              icon: Icons.swap_horiz,
              title: 'Transfer stock',
              subtitle: 'Dispatch stock to another branch and receive it once.',
              onPressed: () => _createTransfer(context),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'Branches',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      for (final branch in state.branches)
        Card(
          child: ListTile(
            leading: const Icon(Icons.store_outlined),
            title: Text(branch.name),
            subtitle: Text(
              '${branch.code} • ${branch.address} • '
              '${branch.isActive ? 'Active' : 'Disabled'}',
            ),
            trailing: user.can(CommercialPermission.branchesManage)
                ? PopupMenuButton<String>(
                    onSelected: (action) =>
                        _branchAction(context, branch, action),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit branch'),
                      ),
                      PopupMenuItem(
                        value: branch.isActive ? 'disable' : 'enable',
                        child: Text(
                          branch.isActive
                              ? 'Disable branch'
                              : 'Reactivate branch',
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      if (user.can(CommercialPermission.branchesManage)) ...[
        const SizedBox(height: 16),
        Text(
          'Stock transfers',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        FutureBuilder<List<Map<String, Object?>>>(
          future: state.commercial.listStockTransfers(user),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorCard(snapshot.error!);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No branch stock transfers yet.'),
              );
            }
            return Column(
              children: [
                for (final transfer in snapshot.data!)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(
                        '${transfer['transfer_no']} • ${transfer['source_branch_name']} → ${transfer['destination_branch_name']}',
                      ),
                      subtitle: Text(
                        '${transfer['status']} • ${transfer['notes'] ?? ''}',
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Transfer actions',
                        onSelected: (action) =>
                            _transferAction(context, transfer, action),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'details',
                            child: Text('View quantities and history'),
                          ),
                          if (transfer['status'] == 'draft' &&
                              transfer['source_branch_id'] == user.branchId &&
                              user.can(
                                CommercialPermission.stockTransferApprove,
                              ))
                            const PopupMenuItem(
                              value: 'approve',
                              child: Text('Approve'),
                            ),
                          if (transfer['status'] == 'draft' &&
                              user.can(
                                CommercialPermission.stockTransferApprove,
                              ))
                            const PopupMenuItem(
                              value: 'reject',
                              child: Text('Reject'),
                            ),
                          if ({
                                'draft',
                                'approved',
                              }.contains(transfer['status']) &&
                              transfer['source_branch_id'] == user.branchId &&
                              user.can(
                                CommercialPermission.stockTransferApprove,
                              ))
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Text('Cancel'),
                            ),
                          if (transfer['status'] == 'approved' &&
                              transfer['source_branch_id'] == user.branchId &&
                              user.can(
                                CommercialPermission.stockTransferApprove,
                              ))
                            const PopupMenuItem(
                              value: 'dispatch',
                              child: Text('Dispatch'),
                            ),
                          if ({
                                'dispatched',
                                'partially_received',
                              }.contains(transfer['status']) &&
                              transfer['destination_branch_id'] ==
                                  user.branchId &&
                              user.can(
                                CommercialPermission.stockTransferReceive,
                              ))
                            const PopupMenuItem(
                              value: 'receive',
                              child: Text('Receive / discrepancy'),
                            ),
                          if (transfer['status'] == 'completed' &&
                              transfer['source_branch_id'] == user.branchId &&
                              user.can(
                                CommercialPermission.stockTransferApprove,
                              ))
                            const PopupMenuItem(
                              value: 'reverse',
                              child: Text('Controlled reversal'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      if (user.can(CommercialPermission.staffManage)) ...[
        const SizedBox(height: 16),
        FutureBuilder<List<StaffUser>>(
          future: state.commercial.listStaff(user),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorCard(snapshot.error!);
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Staff',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final staff in snapshot.data!)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(staff.name),
                      subtitle: Text(
                        '${staff.role.label} • ${staff.username} • '
                        '${staff.isActive ? 'Active' : 'Disabled'}'
                        '${staff.lockedUntil != null ? ' • Locked' : ''}\n'
                        'Last login: ${staff.lastLoginAt ?? 'Never'}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) =>
                            _staffAction(context, staff, action),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit role and branch'),
                          ),
                          const PopupMenuItem(
                            value: 'branches',
                            child: Text('Assign branches'),
                          ),
                          const PopupMenuItem(
                            value: 'reset_pin',
                            child: Text('Reset PIN'),
                          ),
                          PopupMenuItem(
                            value: staff.isActive ? 'disable' : 'enable',
                            child: Text(
                              staff.isActive ? 'Disable' : 'Reactivate',
                            ),
                          ),
                          PopupMenuItem(
                            value: staff.lockedUntil == null
                                ? 'lock'
                                : 'unlock',
                            child: Text(
                              staff.lockedUntil == null
                                  ? 'Lock account'
                                  : 'Unlock account',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'sessions',
                            child: Text('Session history'),
                          ),
                          if (user.can(CommercialPermission.auditView))
                            const PopupMenuItem(
                              value: 'audit',
                              child: Text('Audit history'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ],
  );

  Future<void> _createTransfer(BuildContext context) async {
    final destinations = state.branches
        .where((branch) => branch.isActive && branch.id != user.branchId)
        .toList(growable: false);
    if (destinations.isEmpty || state.products.isEmpty) {
      showFailure(
        context,
        'Add another branch and at least one product first.',
      );
      return;
    }
    final draft = await showDialog<StockTransferDraftResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockTransferDraftDialog(
        destinations: destinations,
        products: state.products,
      ),
    );
    if (draft == null) return;
    try {
      await state.commercial.createStockTransfer(
        actor: user,
        destinationBranchId: draft.destinationBranchId,
        quantitiesByProductId: draft.quantities,
        notes: draft.notes,
      );
      await state.refreshAll();
      if (context.mounted) {
        showSuccess(context, 'Stock-transfer draft created.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _transferAction(
    BuildContext context,
    Map<String, Object?> transfer,
    String action,
  ) async {
    final transferId = transfer['id'] as int;
    try {
      switch (action) {
        case 'details':
          await _showTransferDetails(context, transferId);
          return;
        case 'approve':
          final reason = await _askRequiredText(
            context,
            'Approval note',
            required: false,
          );
          if (reason == null) return;
          await state.commercial.approveStockTransfer(
            actor: user,
            transferId: transferId,
            reason: reason,
          );
          break;
        case 'reject':
          final reason = await _askRequiredText(context, 'Rejection reason');
          if (reason == null) return;
          await state.commercial.rejectStockTransfer(
            actor: user,
            transferId: transferId,
            reason: reason,
          );
          break;
        case 'cancel':
          final reason = await _askRequiredText(context, 'Cancellation reason');
          if (reason == null) return;
          await state.commercial.cancelStockTransfer(
            actor: user,
            transferId: transferId,
            reason: reason,
          );
          break;
        case 'dispatch':
          final items = await state.commercial.stockTransferItems(
            actor: user,
            transferId: transferId,
          );
          await state.commercial.dispatchStockTransfer(
            actor: user,
            transferId: transferId,
            dispatchedByProductId: {
              for (final item in items)
                item['product_id'] as int: (item['quantity'] as num).toDouble(),
            },
          );
          break;
        case 'receive':
          final items = await state.commercial.stockTransferItems(
            actor: user,
            transferId: transferId,
          );
          if (!context.mounted) return;
          final receipt = await showDialog<StockTransferReceiptResult>(
            context: context,
            barrierDismissible: false,
            builder: (_) => StockTransferReceiptDialog(items: items),
          );
          if (receipt == null) return;
          await state.commercial.receiveStockTransfer(
            actor: user,
            transferId: transferId,
            receivedByProductId: receipt.received,
            damagedByProductId: receipt.damaged,
            missingByProductId: receipt.missing,
            excessByProductId: receipt.excess,
            discrepancyReasons: receipt.reasons,
          );
          break;
        case 'reverse':
          final reason = await _askRequiredText(context, 'Reversal reason');
          if (reason == null) return;
          await state.commercial.reverseStockTransfer(
            actor: user,
            transferId: transferId,
            reason: reason,
          );
          break;
      }
      await state.refreshAll();
      if (context.mounted) {
        showSuccess(context, 'Stock transfer updated.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _showTransferDetails(
    BuildContext context,
    int transferId,
  ) async {
    final items = await state.commercial.stockTransferItems(
      actor: user,
      transferId: transferId,
    );
    final history = await state.commercial.stockTransferHistory(
      actor: user,
      transferId: transferId,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stock-transfer details'),
        content: SizedBox(
          width: 760,
          height: 560,
          child: ListView(
            children: [
              Text(
                'Quantities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final item in items)
                ListTile(
                  title: Text(
                    item['product_name'] as String? ??
                        'Product ${item['product_id']}',
                  ),
                  subtitle: Text(
                    'Requested ${item['quantity']} • '
                    'dispatched ${item['dispatched_quantity']} • '
                    'received ${item['received_quantity']} • '
                    'damaged ${item['damaged_quantity']} • '
                    'missing ${item['missing_quantity']} • '
                    'excess ${item['excess_quantity']}\n'
                    '${item['discrepancy_reason'] ?? ''}',
                  ),
                ),
              const Divider(),
              Text(
                'Status history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final row in history)
                ListTile(
                  title: Text(
                    '${row['old_status'] ?? ''} → ${row['new_status'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${row['changed_by_name'] ?? 'System'} • '
                    '${row['changed_at'] ?? ''}\n${row['reason'] ?? ''}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _staffAction(
    BuildContext context,
    StaffUser staff,
    String action,
  ) async {
    try {
      switch (action) {
        case 'edit':
          await _editStaff(context, staff);
          break;
        case 'branches':
          await _assignBranches(context, staff);
          break;
        case 'reset_pin':
          final pin = await _askRequiredText(context, 'New temporary PIN');
          if (pin == null) return;
          await state.commercial.resetStaffPin(
            actor: user,
            userId: staff.id,
            newPin: pin,
            forceChange: true,
          );
          break;
        case 'disable':
        case 'enable':
          await state.commercial.setStaffActive(
            actor: user,
            userId: staff.id,
            active: action == 'enable',
          );
          break;
        case 'lock':
        case 'unlock':
          await state.commercial.setStaffLocked(
            actor: user,
            userId: staff.id,
            locked: action == 'lock',
          );
          break;
        case 'sessions':
          await _showStaffSessions(context, staff);
          return;
        case 'audit':
          await _showStaffAudit(context, staff);
          return;
      }
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Staff account updated.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _editStaff(BuildContext context, StaffUser staff) async {
    final name = TextEditingController(text: staff.name);
    final username = TextEditingController(text: staff.username);
    var role = staff.role;
    var branchId = staff.branchId;
    var forcePinChange = staff.forcePinChange;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit staff account'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<StaffRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final value in StaffRole.values)
                      if (value != StaffRole.owner ||
                          user.role == StaffRole.owner)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? role),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: branchId,
                  decoration: const InputDecoration(
                    labelText: 'Primary branch',
                  ),
                  items: [
                    for (final branch in state.branches)
                      if (branch.isActive)
                        DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => branchId = value ?? branchId),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Force PIN change on next sign-in'),
                  value: forcePinChange,
                  onChanged: (value) =>
                      setDialogState(() => forcePinChange = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    try {
      if (accepted == true) {
        await state.commercial.updateStaff(
          actor: user,
          userId: staff.id,
          name: name.text,
          username: username.text,
          role: role,
          primaryBranchId: branchId,
          forcePinChange: forcePinChange,
        );
      }
    } finally {
      name.dispose();
      username.dispose();
    }
  }

  Future<void> _assignBranches(BuildContext context, StaffUser staff) async {
    final existing = await state.commercial.accessibleBranches(staff);
    final selected = existing.map((branch) => branch.id).toSet();
    if (selected.isEmpty) selected.add(staff.branchId);
    var primary = staff.branchId;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign branches — ${staff.name}'),
          content: SizedBox(
            width: 520,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final branch in state.branches)
                  if (branch.isActive)
                    CheckboxListTile(
                      value: selected.contains(branch.id),
                      title: Text(branch.name),
                      subtitle: Text(
                        branch.id == primary ? 'Primary branch' : branch.code,
                      ),
                      secondary: Radio<int>(
                        value: branch.id,
                        groupValue: primary,
                        onChanged: selected.contains(branch.id)
                            ? (value) => setDialogState(
                                () => primary = value ?? primary,
                              )
                            : null,
                      ),
                      onChanged: (value) => setDialogState(() {
                        if (value == true) {
                          selected.add(branch.id);
                        } else if (selected.length > 1) {
                          selected.remove(branch.id);
                          if (primary == branch.id) {
                            primary = selected.first;
                          }
                        }
                      }),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty || !selected.contains(primary)
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Save assignment'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await state.commercial.assignStaffBranches(
        actor: user,
        userId: staff.id,
        branchIds: selected,
        primaryBranchId: primary,
      );
    }
  }

  Future<void> _showStaffSessions(BuildContext context, StaffUser staff) async {
    final sessions = (await state.commercial.listStaffSessions(
      actor: user,
      userId: staff.id,
    )).map((row) => Map<String, Object?>.from(row)).toList(growable: false);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Session history — ${staff.name}'),
          content: SizedBox(
            width: 680,
            height: 480,
            child: sessions.isEmpty
                ? const Center(child: Text('No staff sessions were recorded.'))
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (_, index) {
                      final session = sessions[index];
                      final active = session['ended_at'] == null;
                      return ListTile(
                        leading: Icon(active ? Icons.login : Icons.logout),
                        title: Text(
                          '${session['branch_name']} • '
                          '${active ? 'Active' : 'Ended'}',
                        ),
                        subtitle: Text(
                          '${session['started_at']}'
                          '${active ? '' : ' → ${session['ended_at']}'}',
                        ),
                        trailing: active && session['user_id'] != user.id
                            ? TextButton(
                                onPressed: () async {
                                  await state.commercial.terminateStaffSession(
                                    actor: user,
                                    sessionId: session['id'] as int,
                                    reason: 'Terminated by administrator',
                                  );
                                  session['ended_at'] = DateTime.now()
                                      .toIso8601String();
                                  setDialogState(() {});
                                },
                                child: const Text('Terminate'),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStaffAudit(BuildContext context, StaffUser staff) async {
    final entries = await state.commercial.staffAuditHistory(
      actor: user,
      userId: staff.id,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Audit history — ${staff.name}'),
        content: SizedBox(
          width: 760,
          height: 520,
          child: entries.isEmpty
              ? const Center(child: Text('No audit entries were recorded.'))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    return ListTile(
                      title: Text(entry.action),
                      subtitle: Text(
                        '${entry.createdAt} • ${entry.entityType} '
                        '${entry.entityId}\n${entry.reason}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _branchAction(
    BuildContext context,
    BranchRecord branch,
    String action,
  ) async {
    try {
      if (action == 'edit') {
        final name = TextEditingController(text: branch.name);
        final code = TextEditingController(text: branch.code);
        final address = TextEditingController(text: branch.address);
        final phone = TextEditingController(text: branch.phone);
        final email = TextEditingController(text: branch.email);
        final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Edit branch'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: code,
                    decoration: const InputDecoration(labelText: 'Code'),
                  ),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        try {
          if (accepted == true) {
            await state.commercial.updateBranch(
              actor: user,
              branchId: branch.id,
              name: name.text,
              code: code.text,
              address: address.text,
              phone: phone.text,
              email: email.text,
            );
          }
        } finally {
          name.dispose();
          code.dispose();
          address.dispose();
          phone.dispose();
          email.dispose();
        }
      } else {
        await state.commercial.setBranchActive(
          actor: user,
          branchId: branch.id,
          active: action == 'enable',
        );
      }
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Branch updated.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _addStaff(BuildContext context) async {
    final name = TextEditingController();
    final username = TextEditingController();
    final pin = TextEditingController();
    var role = StaffRole.cashier;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add staff account'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pin,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'PIN'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<StaffRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    for (final value in StaffRole.values)
                      if (value != StaffRole.owner)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                  ],
                  onChanged: (value) => setState(() => role = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await state.commercial.createStaff(
        actor: user,
        branchId: user.branchId,
        name: name.text,
        username: username.text,
        pin: pin.text,
        role: role,
      );
      if (context.mounted) showSuccess(context, 'Staff account created.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _addBranch(BuildContext context) async {
    final name = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add branch'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Branch name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Branch code'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.commercial.createBranch(
        actor: user,
        name: name.text,
        code: code.text,
      );
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Branch created.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}

class _PremiumToolsPanel extends StatelessWidget {
  const _PremiumToolsPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (user.can(CommercialPermission.backupsManage)) ...[
            _ActionCard(
              icon: Icons.enhanced_encryption_outlined,
              title: 'Encrypted backup',
              subtitle: 'Create an AES-GCM protected database backup.',
              onPressed: () => _backup(context),
            ),
            _ActionCard(
              icon: Icons.restore_outlined,
              title: 'Restore backup',
              subtitle:
                  'Verify, restore and roll back safely if integrity checks fail.',
              onPressed: () => _restore(context),
            ),
            _ActionCard(
              icon: Icons.schedule_outlined,
              title: 'Automatic backup',
              subtitle:
                  'Store the encryption password securely and run daily catch-up backups.',
              onPressed: () => _automaticBackup(context),
            ),
            _ActionCard(
              icon: Icons.cloud_upload_outlined,
              title: 'Cloud backup',
              subtitle:
                  'Upload an encrypted backup to an HTTPS WebDAV destination.',
              onPressed: () => _cloudBackup(context),
            ),
          ],
          if (user.can(CommercialPermission.importsManage))
            _ActionCard(
              icon: Icons.upload_file_outlined,
              title: 'Import data',
              subtitle:
                  'Import products, customers, suppliers or opening stock from CSV/XLSX.',
              onPressed: () => _import(context),
            ),
          if (user.can(CommercialPermission.remoteDashboard))
            _ActionCard(
              icon: Icons.phone_android_outlined,
              title: 'Remote owner dashboard',
              subtitle:
                  'Start a read-only, token-protected local network dashboard.',
              onPressed: () => _remote(context),
            ),
          if (user.can(CommercialPermission.updatesManage))
            _ActionCard(
              icon: Icons.system_update_alt,
              title: 'Secure update check',
              subtitle: 'Verify release metadata and SHA-256 before download.',
              onPressed: () => _updates(context),
            ),
          if (user.can(CommercialPermission.expensesManage))
            _ActionCard(
              icon: Icons.event_repeat_outlined,
              title: 'Recurring expense',
              subtitle: 'Schedule rent, utilities, salaries and subscriptions.',
              onPressed: () => _recurring(context),
            ),
        ],
      ),
    ],
  );

  Future<void> _backup(BuildContext context) async {
    final password = await _askText(context, 'Backup password', obscure: true);
    if (password == null || password.isEmpty) return;
    try {
      final path = await state.createEncryptedBackup(password);
      if (context.mounted)
        showSuccess(context, 'Encrypted backup created: $path');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['abmbackup'],
      );
      final path = selection?.files.single.path;
      if (path == null) return;
      final password = await _askText(
        context,
        'Backup password',
        obscure: true,
      );
      if (password == null || password.isEmpty) return;
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore encrypted backup?'),
          content: const Text(
            'A safety copy of the current database will be created first. '
            'After a successful restore, the application will lock so the restored staff data can be loaded safely.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await state.restoreEncryptedBackup(path, password);
      if (context.mounted) {
        showSuccess(
          context,
          'Backup restored. Sign in using the restored staff account.',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _automaticBackup(BuildContext context) async {
    final password = await _askText(
      context,
      'Automatic-backup password',
      obscure: true,
    );
    if (password == null || password.isEmpty) return;
    try {
      await state.enableAutomaticBackup(password: password, intervalHours: 24);
      if (context.mounted) {
        showSuccess(context, 'Daily encrypted backup is enabled.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _cloudBackup(BuildContext context) async {
    final endpointText = await _askText(context, 'HTTPS WebDAV folder URL');
    if (endpointText == null || endpointText.isEmpty) return;
    final username = await _askText(context, 'WebDAV username');
    if (username == null) return;
    final password = await _askText(context, 'WebDAV password', obscure: true);
    if (password == null) return;
    final backupPassword = await _askText(
      context,
      'Encryption password for this backup',
      obscure: true,
    );
    if (backupPassword == null) return;
    try {
      final backupPath = await state.createEncryptedBackup(backupPassword);
      await state.secureConfig.saveWebDavPassword(password);
      await state.uploadWebDavBackup(
        backupPath: backupPath,
        endpoint: Uri.parse(endpointText),
        username: username,
        password: password,
      );
      if (context.mounted)
        showSuccess(context, 'Encrypted cloud backup uploaded.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final type = await _chooseImportType(context);
      if (type == null) return;
      final imported = await state.imports.importFile(
        actor: user,
        path: path,
        importType: type,
      );
      await state.refreshAll();
      if (context.mounted) {
        showSuccess(
          context,
          'Imported ${imported.importedRows} rows; skipped ${imported.skippedRows}; failed ${imported.failedRows}.',
        );
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _remote(BuildContext context) async {
    try {
      final url = await state.startRemoteDashboard();
      if (context.mounted)
        showSuccess(context, 'Remote dashboard started at $url');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _updates(BuildContext context) async {
    final text = await _askText(context, 'HTTPS update manifest URL');
    if (text == null || text.isEmpty) return;
    try {
      final info = await state.updates.check(Uri.parse(text));
      if (context.mounted)
        showSuccess(
          context,
          info.isNewer
              ? 'Update ${info.availableVersion} is available.'
              : 'This installation is up to date.',
        );
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  Future<void> _recurring(BuildContext context) async {
    final amount = await _askNumber(context, 'Recurring expense amount');
    if (amount == null) return;
    try {
      await state.commercial.createRecurringExpense(
        actor: user,
        title: 'Monthly operating expense',
        category: 'Operations',
        amount: amount,
        frequency: 'monthly',
        startDate: DateTime.now().add(const Duration(days: 30)),
        paymentMethod: 'Bank',
      );
      if (context.mounted) showSuccess(context, 'Recurring expense scheduled.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
}

class _AuditPanel extends StatelessWidget {
  const _AuditPanel({required this.state, required this.user});
  final AppState state;
  final StaffUser user;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AuditEntry>>(
    future: state.commercial.listAudit(actor: user),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _ErrorCard(snapshot.error!);
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.data!.isEmpty)
        return const _EmptyState(
          icon: Icons.manage_search_outlined,
          message: 'No audit entries yet.',
        );
      return ListView.builder(
        itemCount: snapshot.data!.length,
        itemBuilder: (context, index) {
          final entry = snapshot.data![index];
          return Card(
            child: ListTile(
              leading: Icon(
                entry.success
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
              ),
              title: Text(entry.action.replaceAll('.', ' › ')),
              subtitle: Text(
                '${entry.userName ?? 'System'} • ${entry.branchName ?? ''} • ${entry.createdAt.toLocal()}\n${entry.reason}',
              ),
              isThreeLine: true,
            ),
          );
        },
      );
    },
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 330,
    child: Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(subtitle),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard(this.error);
  final Object error;
  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(error.toString()),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56),
        const SizedBox(height: 12),
        Text(message),
      ],
    ),
  );
}

Future<double?> _askNumber(BuildContext context, String label) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return value == null ? null : double.tryParse(value.trim());
}

Future<String?> _askText(
  BuildContext context,
  String label, {
  bool obscure = false,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

Future<String?> _askRequiredText(
  BuildContext context,
  String label, {
  bool required = true,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            if (required && text.isEmpty) return;
            Navigator.pop(context, text);
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

Future<String?> _chooseImportType(BuildContext context) => showDialog<String>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('Import data type'),
    children: [
      for (final value in const [
        'products',
        'customers',
        'suppliers',
        'opening_stock',
      ])
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, value),
          child: Text(value.replaceAll('_', ' ')),
        ),
    ],
  ),
);
