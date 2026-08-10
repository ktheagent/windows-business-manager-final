
from pathlib import Path

p = Path("lib/commercial/screens/commercial_suite_screen.dart")
text = p.read_text(encoding="utf-8")

def replace_between(class_marker, start_marker, end_marker, replacement):
    global text
    c = text.index(class_marker)
    s = text.index(start_marker, c)
    e = text.index(end_marker, s)
    text = text[:s] + replacement.rstrip() + "\n" + text[e:]

replace_between(
    "class _PurchasesPanelState",
    "  Future<void> _create(BuildContext context) async {",
    "  Future<void> _action(",
    r'''  Future<void> _create(BuildContext context) async {
    if (widget.state.suppliers.isEmpty || widget.state.products.isEmpty) {
      showFailure(context, 'Add a supplier and product first.');
      return;
    }
    int? supplierId;
    int? productId;
    final qty = TextEditingController(text: '1');
    final unitCost = TextEditingController();
    final draft = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New purchase order'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: widget.state.suppliers
                      .where((s) => s.id != null)
                      .map((s) => DropdownMenuItem(value: s.id!, child: Text(s.name)))
                      .toList(growable: false),
                  onChanged: (v) => setDialogState(() => supplierId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: widget.state.products
                      .where((item) => item.id != null && item.isActive)
                      .map((item) => DropdownMenuItem(
                            value: item.id!,
                            child: Text('${item.name} • ${item.sku}'),
                          ))
                      .toList(growable: false),
                  onChanged: (v) {
                    setDialogState(() => productId = v);
                    if (v != null) {
                      final product = widget.state.products.firstWhere((item) => item.id == v);
                      unitCost.text = product.costPrice.toStringAsFixed(2);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qty,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Unit cost'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: supplierId == null || productId == null
                  ? null
                  : () {
                      final quantity = double.tryParse(qty.text.trim());
                      final cost = double.tryParse(unitCost.text.trim());
                      if (quantity == null || quantity <= 0 || cost == null || cost < 0) return;
                      Navigator.pop(dialogContext, {
                        'supplier_id': supplierId!,
                        'product_id': productId!,
                        'quantity': quantity,
                        'unit_cost': cost,
                      });
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    qty.dispose();
    unitCost.dispose();
    if (draft == null || !mounted) return;
    final product = widget.state.products.firstWhere(
      (item) => item.id == draft['product_id'],
    );
    try {
      await widget.state.commercial.createPurchaseOrder(
        actor: widget.user,
        supplierId: draft['supplier_id'] as int,
        items: [
          {
            'product_id': product.id,
            'description': product.name,
            'quantity': draft['quantity'] as double,
            'unit_cost': draft['unit_cost'] as double,
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
''')

replace_between(
    "class _InventoryPanel",
    "  Future<void> _adjust(BuildContext context) async {",
    "  Future<void> _count(BuildContext context) async {",
    r'''  Future<void> _adjust(BuildContext context) async {
    if (state.products.isEmpty) {
      showFailure(context, 'Add a product before adjusting stock.');
      return;
    }
    int? productId;
    String reason = 'Correction';
    final amount = TextEditingController();
    final note = TextEditingController();
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Stock adjustment'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: state.products
                      .where((item) => item.id != null && item.isActive)
                      .map((item) => DropdownMenuItem(
                            value: item.id!,
                            child: Text('${item.name} • Stock ${item.stockQty}'),
                          ))
                      .toList(growable: false),
                  onChanged: (v) => setDialogState(() => productId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity change',
                    helperText: 'Use a negative value to reduce stock.',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: const [
                    DropdownMenuItem(value: 'Correction', child: Text('Correction')),
                    DropdownMenuItem(value: 'Damaged', child: Text('Damaged')),
                    DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                    DropdownMenuItem(value: 'Missing', child: Text('Missing')),
                    DropdownMenuItem(value: 'Found', child: Text('Found stock')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => reason = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: productId == null
                  ? null
                  : () {
                      final change = double.tryParse(amount.text.trim());
                      if (change == null || change == 0) return;
                      Navigator.pop(dialogContext, {
                        'product_id': productId!,
                        'amount': change,
                        'reason': reason,
                        'note': note.text.trim(),
                      });
                    },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    note.dispose();
    if (result == null || !context.mounted) return;
    try {
      await state.commercial.adjustStock(
        actor: user,
        productId: result['product_id'] as int,
        quantityChange: result['amount'] as double,
        reason: result['reason'] as String,
        note: result['note'] as String,
      );
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Stock adjusted.');
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
''')

replace_between(
    "class _InventoryPanel",
    "  Future<void> _count(BuildContext context) async {",
    "  Future<void> _labels(BuildContext context) async {",
    r'''  Future<void> _count(BuildContext context) async {
    try {
      final id = await state.commercial.startStockCount(
        actor: user,
        notes: 'Physical count',
      );
      final items = await state.commercial.stockCountItems(
        actor: user,
        stockCountId: id,
      );
      if (!context.mounted) return;
      final controllers = <int, TextEditingController>{
        for (final item in items)
          item['product_id'] as int: TextEditingController(),
      };
      final counts = await showDialog<Map<int, double>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Enter physical stock count'),
          content: SizedBox(
            width: 560,
            height: 440,
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                final productId = item['product_id'] as int;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['product_name'] as String? ?? 'Product $productId'),
                  subtitle: Text('Expected: ${item['expected_qty']}'),
                  trailing: SizedBox(
                    width: 140,
                    child: TextField(
                      controller: controllers[productId],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Counted'),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final values = <int, double>{};
                for (final entry in controllers.entries) {
                  final value = double.tryParse(entry.value.text.trim());
                  if (value == null || value < 0) return;
                  values[entry.key] = value;
                }
                Navigator.pop(dialogContext, values);
              },
              child: const Text('Save and approve'),
            ),
          ],
        ),
      );
      for (final controller in controllers.values) {
        controller.dispose();
      }
      if (counts == null || !context.mounted) return;
      for (final entry in counts.entries) {
        await state.commercial.saveStockCountQuantity(
          actor: user,
          stockCountId: id,
          productId: entry.key,
          countedQuantity: entry.value,
        );
      }
      await state.commercial.approveStockCount(actor: user, stockCountId: id);
      await state.refreshAll();
      if (context.mounted) {
        showSuccess(context, 'Physical stock count saved and approved.');
      }
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }
''')

replace_between(
    "class _CashReturnsPanelState",
    "  Future<void> _open(BuildContext context) async {",
    "  Future<void> _close(BuildContext context) async {",
    r'''  Future<void> _open(BuildContext context) async {
    final float = await _askNumber(context, 'Opening cash float');
    if (float == null) return;
    try {
      var registers = await widget.state.commercial.listCashRegisters(widget.user);
      if (registers.isEmpty) {
        await widget.state.commercial.createCashRegister(
          actor: widget.user,
          name: 'Main Register',
        );
        registers = await widget.state.commercial.listCashRegisters(widget.user);
      }
      if (registers.isEmpty) {
        throw StateError('Unable to configure a cash register.');
      }
      if (!context.mounted) return;
      int? registerId;
      if (registers.length == 1) {
        registerId = registers.first['id'] as int;
      } else {
        registerId = await showDialog<int>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Select cash register'),
            children: [
              for (final register in registers)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, register['id'] as int),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(register['name'] as String),
                  ),
                ),
            ],
          ),
        );
      }
      if (registerId == null) return;
      await widget.state.commercial.openCashSession(
        actor: widget.user,
        registerId: registerId,
        openingFloat: float,
      );
      await widget.state.refreshAll();
      if (mounted) showSuccess(context, 'Cash shift opened.');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
''')

p.write_text(text, encoding="utf-8")
print("commercial workflow fixes applied")
