import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../models/commercial_models.dart';

class StockTransferDraftResult {
  const StockTransferDraftResult({
    required this.destinationBranchId,
    required this.quantities,
    required this.notes,
  });

  final int destinationBranchId;
  final Map<int, double> quantities;
  final String notes;
}

class StockTransferDraftDialog extends StatefulWidget {
  const StockTransferDraftDialog({
    super.key,
    required this.destinations,
    required this.products,
  });

  final List<BranchRecord> destinations;
  final List<Product> products;

  @override
  State<StockTransferDraftDialog> createState() =>
      _StockTransferDraftDialogState();
}

class _StockTransferDraftDialogState extends State<StockTransferDraftDialog> {
  late int destinationId;
  final search = TextEditingController();
  final notes = TextEditingController();
  final quantities = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    destinationId = widget.destinations.first.id;
  }

  @override
  void dispose() {
    search.dispose();
    notes.dispose();
    for (final controller in quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _toggle(Product product, bool selected) {
    final id = product.id!;
    setState(() {
      if (selected) {
        quantities[id] = TextEditingController(text: '1');
      } else {
        quantities.remove(id)?.dispose();
      }
    });
  }

  void _submit() {
    final values = <int, double>{};
    for (final entry in quantities.entries) {
      final value = double.tryParse(entry.value.text.trim());
      if (value == null || value <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Every selected product needs a positive quantity.'),
          ),
        );
        return;
      }
      values[entry.key] = value;
    }
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one product.')),
      );
      return;
    }
    Navigator.of(context).pop(
      StockTransferDraftResult(
        destinationBranchId: destinationId,
        quantities: values,
        notes: notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final products = widget.products
        .where(
          (product) =>
              product.id != null &&
              (query.isEmpty ||
                  product.name.toLowerCase().contains(query) ||
                  product.sku.toLowerCase().contains(query) ||
                  product.barcode.toLowerCase().contains(query)),
        )
        .toList(growable: false);
    return AlertDialog(
      title: const Text('Create stock-transfer draft'),
      content: SizedBox(
        width: 720,
        height: 620,
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              initialValue: destinationId,
              decoration: const InputDecoration(
                labelText: 'Destination branch',
              ),
              items: [
                for (final branch in widget.destinations)
                  DropdownMenuItem(
                    value: branch.id,
                    child: Text('${branch.name} (${branch.code})'),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => destinationId = value ?? destinationId),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: search,
              decoration: const InputDecoration(
                labelText: 'Search product, SKU or barcode',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: products.isEmpty
                  ? const Center(child: Text('No matching active products.'))
                  : ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final selected = quantities.containsKey(product.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) =>
                              _toggle(product, value ?? false),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.sku} • available ${product.stockQty}',
                          ),
                          secondary: selected
                              ? SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: quantities[product.id],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Quantity',
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Transfer notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save draft'),
        ),
      ],
    );
  }
}

class StockTransferReceiptResult {
  const StockTransferReceiptResult({
    required this.received,
    required this.damaged,
    required this.missing,
    required this.excess,
    required this.reasons,
  });

  final Map<int, double> received;
  final Map<int, double> damaged;
  final Map<int, double> missing;
  final Map<int, double> excess;
  final Map<int, String> reasons;
}

class StockTransferReceiptDialog extends StatefulWidget {
  const StockTransferReceiptDialog({super.key, required this.items});

  final List<Map<String, Object?>> items;

  @override
  State<StockTransferReceiptDialog> createState() =>
      _StockTransferReceiptDialogState();
}

class _StockTransferReceiptDialogState
    extends State<StockTransferReceiptDialog> {
  final received = <int, TextEditingController>{};
  final damaged = <int, TextEditingController>{};
  final missing = <int, TextEditingController>{};
  final excess = <int, TextEditingController>{};
  final reasons = <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      final productId = item['product_id'] as int;
      final dispatched =
          (item['dispatched_quantity'] as num? ?? item['quantity'] as num)
              .toDouble();
      final alreadyReceived = (item['received_quantity'] as num? ?? 0)
          .toDouble();
      final alreadyDamaged = (item['damaged_quantity'] as num? ?? 0).toDouble();
      final alreadyMissing = (item['missing_quantity'] as num? ?? 0).toDouble();
      final outstanding =
          (dispatched - alreadyReceived - alreadyDamaged - alreadyMissing)
              .clamp(0, double.infinity)
              .toDouble();
      received[productId] = TextEditingController(text: outstanding.toString());
      damaged[productId] = TextEditingController(text: '0');
      missing[productId] = TextEditingController(text: '0');
      excess[productId] = TextEditingController(text: '0');
      reasons[productId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final group in [received, damaged, missing, excess, reasons]) {
      for (final controller in group.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _submit() {
    final receivedValues = <int, double>{};
    final damagedValues = <int, double>{};
    final missingValues = <int, double>{};
    final excessValues = <int, double>{};
    final reasonValues = <int, String>{};
    for (final item in widget.items) {
      final productId = item['product_id'] as int;
      final values = [
        double.tryParse(received[productId]!.text.trim()),
        double.tryParse(damaged[productId]!.text.trim()),
        double.tryParse(missing[productId]!.text.trim()),
        double.tryParse(excess[productId]!.text.trim()),
      ];
      if (values.any((value) => value == null || value < 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt quantities must be non-negative numbers.'),
          ),
        );
        return;
      }
      final reason = reasons[productId]!.text.trim();
      if ((values[1]! > 0 || values[2]! > 0 || values[3]! > 0) &&
          reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Explain every damaged, missing or excess quantity.'),
          ),
        );
        return;
      }
      receivedValues[productId] = values[0]!;
      damagedValues[productId] = values[1]!;
      missingValues[productId] = values[2]!;
      excessValues[productId] = values[3]!;
      if (reason.isNotEmpty) reasonValues[productId] = reason;
    }
    Navigator.of(context).pop(
      StockTransferReceiptResult(
        received: receivedValues,
        damaged: damagedValues,
        missing: missingValues,
        excess: excessValues,
        reasons: reasonValues,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receive stock transfer'),
      content: SizedBox(
        width: 860,
        height: 560,
        child: ListView.separated(
          itemCount: widget.items.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final productId = item['product_id'] as int;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item['product_name'] as String? ??
                      'Product ${item['product_id']}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Requested ${item['quantity']} • '
                  'dispatched ${item['dispatched_quantity']} • '
                  'already received ${item['received_quantity']}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ReceiptNumberField(
                      controller: received[productId]!,
                      label: 'Saleable received',
                    ),
                    _ReceiptNumberField(
                      controller: damaged[productId]!,
                      label: 'Damaged',
                    ),
                    _ReceiptNumberField(
                      controller: missing[productId]!,
                      label: 'Missing',
                    ),
                    _ReceiptNumberField(
                      controller: excess[productId]!,
                      label: 'Excess',
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: reasons[productId],
                        decoration: const InputDecoration(
                          labelText: 'Discrepancy reason',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.inventory_outlined),
          label: const Text('Record receipt'),
        ),
      ],
    );
  }
}

class _ReceiptNumberField extends StatelessWidget {
  const _ReceiptNumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    ),
  );
}
