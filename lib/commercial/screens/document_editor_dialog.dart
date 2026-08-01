import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/contact.dart';
import '../../models/product.dart';
import '../models/commercial_models.dart';

class CommercialDocumentEditorDialog extends StatefulWidget {
  const CommercialDocumentEditorDialog({
    super.key,
    required this.products,
    required this.customers,
    this.initialDraft,
  });

  final List<Product> products;
  final List<BusinessContact> customers;
  final CommercialDocumentDraft? initialDraft;

  @override
  State<CommercialDocumentEditorDialog> createState() =>
      _CommercialDocumentEditorDialogState();
}

class _CommercialDocumentEditorDialogState
    extends State<CommercialDocumentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _barcode = TextEditingController();
  late final TextEditingController _overallDiscount;
  late final TextEditingController _overallTax;
  late final TextEditingController _notes;
  late final TextEditingController _terms;
  late final TextEditingController _paymentInstructions;
  late String _type;
  int? _customerId;
  DateTime? _validUntil;
  DateTime? _dueAt;
  DateTime? _documentDate;
  final List<_LineController> _lines = [];

  static const _documentTypes = <String, String>{
    'quotation': 'Quotation',
    'estimate': 'Estimate',
    'proforma': 'Pro-forma invoice',
    'invoice': 'Standard invoice',
    'tax_invoice': 'Tax invoice',
    'delivery_note': 'Delivery note',
    'purchase_order': 'Purchase order',
    'goods_received_note': 'Goods-received note',
    'credit_note': 'Credit note',
    'customer_statement': 'Customer statement',
    'supplier_statement': 'Supplier statement',
    'refund_receipt': 'Refund receipt',
  };

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _type = draft?.type ?? 'quotation';
    _customerId = draft?.customerId;
    _validUntil =
        draft?.validUntil ?? DateTime.now().add(const Duration(days: 14));
    _dueAt = draft?.dueAt;
    _documentDate = draft?.documentDate ?? DateTime.now();
    _overallDiscount = TextEditingController(
      text: (draft?.discount ?? 0).toStringAsFixed(2),
    );
    _overallTax = TextEditingController(
      text: (draft?.tax ?? 0).toStringAsFixed(2),
    );
    _notes = TextEditingController(text: draft?.notes ?? '');
    _terms = TextEditingController(
      text: draft?.terms ?? 'Prices are valid until the stated date.',
    );
    _paymentInstructions = TextEditingController(
      text: draft?.paymentInstructions ?? '',
    );
    if (draft != null && draft.items.isNotEmpty) {
      for (final item in draft.items) {
        _lines.add(_LineController.fromItem(item));
      }
    } else {
      _addProductLine(widget.products.isEmpty ? null : widget.products.first);
    }
  }

  @override
  void dispose() {
    _barcode.dispose();
    _overallDiscount.dispose();
    _overallTax.dispose();
    _notes.dispose();
    _terms.dispose();
    _paymentInstructions.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addProductLine(Product? product) {
    setState(() {
      _lines.add(_LineController.fromProduct(product));
    });
  }

  void _addServiceLine() {
    setState(() {
      _lines.add(_LineController.service());
    });
  }

  void _addBarcodeProduct() {
    final query = _barcode.text.trim().toLowerCase();
    if (query.isEmpty) return;
    Product? match;
    for (final product in widget.products) {
      if (product.barcode.trim().toLowerCase() == query ||
          product.sku.trim().toLowerCase() == query) {
        match = product;
        break;
      }
    }
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active product matches that barcode.'),
        ),
      );
      return;
    }
    _addProductLine(match);
    _barcode.clear();
  }

  CommercialDocumentDraft _buildDraft() {
    final items = _lines.map((line) => line.toItem()).toList(growable: false);
    return CommercialDocumentDraft(
      type: _type,
      customerId: _customerId,
      items: items,
      discount: double.tryParse(_overallDiscount.text.trim()) ?? 0,
      tax: double.tryParse(_overallTax.text.trim()) ?? 0,
      notes: _notes.text.trim(),
      terms: _terms.text.trim(),
      validUntil: _validUntil,
      dueAt: _dueAt,
      paymentInstructions: _paymentInstructions.text.trim(),
      documentDate: _documentDate,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one product or service line.'),
        ),
      );
      return;
    }
    final draft = _buildDraft();
    if (draft.total < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document total cannot be negative.')),
      );
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _buildDraft();
    return AlertDialog(
      title: Text(
        widget.initialDraft == null
            ? 'Create commercial document'
            : 'Edit commercial document',
      ),
      content: SizedBox(
        width: 980,
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Document type',
                      ),
                      items: _documentTypes.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setState(() => _type = value ?? _type),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _customerId,
                      decoration: const InputDecoration(labelText: 'Customer'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Walk-in / unassigned'),
                        ),
                        for (final customer in widget.customers)
                          DropdownMenuItem<int?>(
                            value: customer.id,
                            child: Text(customer.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _customerId = value),
                    ),
                  ),
                  _DateField(
                    label: 'Document date',
                    value: _documentDate,
                    onChanged: (value) => setState(() => _documentDate = value),
                  ),
                  _DateField(
                    label: 'Validity date',
                    value: _validUntil,
                    onChanged: (value) => setState(() => _validUntil = value),
                  ),
                  _DateField(
                    label: 'Due date',
                    value: _dueAt,
                    onChanged: (value) => setState(() => _dueAt = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcode,
                      decoration: const InputDecoration(
                        labelText: 'Barcode or SKU',
                        prefixIcon: Icon(Icons.qr_code_scanner),
                      ),
                      onSubmitted: (_) => _addBarcodeProduct(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _addBarcodeProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('Barcode add'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _addProductLine(
                      widget.products.isEmpty ? null : widget.products.first,
                    ),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Product line'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addServiceLine,
                    icon: const Icon(Icons.miscellaneous_services_outlined),
                    label: const Text('Service line'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _lines.isEmpty
                    ? const Center(
                        child: Text('Add a product or service line.'),
                      )
                    : ListView.separated(
                        itemCount: _lines.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final line = _lines[index];
                          return _LineEditor(
                            key: ValueKey(line.identity),
                            line: line,
                            products: widget.products,
                            onChanged: () => setState(() {}),
                            onRemove: () {
                              setState(() {
                                _lines.removeAt(index).dispose();
                              });
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: _overallDiscount,
                      decoration: const InputDecoration(
                        labelText: 'Overall discount',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _nonNegativeNumber,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: TextFormField(
                      controller: _overallTax,
                      decoration: const InputDecoration(
                        labelText: 'Overall tax amount',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _nonNegativeNumber,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: _paymentInstructions,
                      decoration: const InputDecoration(
                        labelText: 'Payment instructions',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: _terms,
                      decoration: const InputDecoration(labelText: 'Terms'),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 18,
                  children: [
                    Text('Subtotal: ${AppFormatters.money(draft.subtotal)}'),
                    Text('Tax: ${AppFormatters.money(draft.totalTax)}'),
                    Text(
                      'Total: ${AppFormatters.money(draft.total)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          label: Text(
            widget.initialDraft == null ? 'Save draft' : 'Save changes',
          ),
        ),
      ],
    );
  }

  static String? _nonNegativeNumber(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return 'Enter a non-negative number';
    return null;
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    super.key,
    required this.line,
    required this.products,
    required this.onChanged,
    required this.onRemove,
  });

  final _LineController line;
  final List<Product> products;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int?>(
                    initialValue: line.productId,
                    decoration: const InputDecoration(
                      labelText: 'Product / service',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Manual service'),
                      ),
                      for (final product in products)
                        DropdownMenuItem<int?>(
                          value: product.id,
                          child: Text(product.name),
                        ),
                    ],
                    onChanged: (value) {
                      line.setProduct(
                        value == null
                            ? null
                            : products.firstWhere(
                                (product) => product.id == value,
                              ),
                      );
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: line.description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove line',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NumberField(
                  controller: line.quantity,
                  label: 'Quantity',
                  width: 110,
                  positive: true,
                  onChanged: onChanged,
                ),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: line.unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                    onChanged: (_) => onChanged(),
                  ),
                ),
                _NumberField(
                  controller: line.unitPrice,
                  label: 'Unit price',
                  width: 130,
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: line.costPrice,
                  label: 'Cost',
                  width: 120,
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: line.discount,
                  label: 'Line discount',
                  width: 135,
                  onChanged: onChanged,
                ),
                _NumberField(
                  controller: line.taxRate,
                  label: 'Tax %',
                  width: 100,
                  onChanged: onChanged,
                ),
                SizedBox(
                  width: 145,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tax inclusive'),
                    value: line.taxInclusive,
                    onChanged: (value) {
                      line.taxInclusive = value;
                      onChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppFormatters.money(line.toItem().total),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.width,
    required this.onChanged,
    this.positive = false,
  });

  final TextEditingController controller;
  final String label;
  final double width;
  final VoidCallback onChanged;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          final number = double.tryParse(value?.trim() ?? '');
          if (number == null || number < 0 || (positive && number <= 0)) {
            return positive ? 'Must be > 0' : 'Must be ≥ 0';
          }
          return null;
        },
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2200),
            initialDate: value ?? DateTime.now(),
          );
          if (selected != null) onChanged(selected);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today_outlined)
                : IconButton(
                    tooltip: 'Clear date',
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.clear),
                  ),
          ),
          child: Text(
            value == null
                ? 'Not set'
                : '${value!.year.toString().padLeft(4, '0')}-'
                      '${value!.month.toString().padLeft(2, '0')}-'
                      '${value!.day.toString().padLeft(2, '0')}',
          ),
        ),
      ),
    );
  }
}

class _LineController {
  _LineController({
    required this.productId,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.costPrice,
    required this.discount,
    required this.taxRate,
    required this.taxInclusive,
  });

  factory _LineController.fromProduct(Product? product) => _LineController(
    productId: product?.id,
    description: TextEditingController(text: product?.name ?? ''),
    quantity: TextEditingController(text: '1'),
    unit: TextEditingController(text: 'each'),
    unitPrice: TextEditingController(
      text: (product?.sellingPrice ?? 0).toStringAsFixed(2),
    ),
    costPrice: TextEditingController(
      text: (product?.costPrice ?? 0).toStringAsFixed(2),
    ),
    discount: TextEditingController(text: '0.00'),
    taxRate: TextEditingController(text: '0.00'),
    taxInclusive: false,
  );

  factory _LineController.service() => _LineController.fromProduct(null);

  factory _LineController.fromItem(
    CommercialDocumentItem item,
  ) => _LineController(
    productId: item.productId,
    description: TextEditingController(text: item.description),
    quantity: TextEditingController(text: item.quantity.toString()),
    unit: TextEditingController(text: item.unit),
    unitPrice: TextEditingController(text: item.unitPrice.toStringAsFixed(2)),
    costPrice: TextEditingController(text: item.costPrice.toStringAsFixed(2)),
    discount: TextEditingController(text: item.lineDiscount.toStringAsFixed(2)),
    taxRate: TextEditingController(text: item.taxRate.toString()),
    taxInclusive: item.taxInclusive,
  );

  final Object identity = Object();
  int? productId;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController unitPrice;
  final TextEditingController costPrice;
  final TextEditingController discount;
  final TextEditingController taxRate;
  bool taxInclusive;

  void setProduct(Product? product) {
    productId = product?.id;
    if (product != null) {
      description.text = product.name;
      unitPrice.text = product.sellingPrice.toStringAsFixed(2);
      costPrice.text = product.costPrice.toStringAsFixed(2);
    }
  }

  CommercialDocumentItem toItem() => CommercialDocumentItem(
    productId: productId,
    description: description.text.trim(),
    quantity: double.tryParse(quantity.text.trim()) ?? 0,
    unit: unit.text.trim(),
    unitPrice: double.tryParse(unitPrice.text.trim()) ?? 0,
    costPrice: double.tryParse(costPrice.text.trim()) ?? 0,
    lineDiscount: double.tryParse(discount.text.trim()) ?? 0,
    taxRate: double.tryParse(taxRate.text.trim()) ?? 0,
    taxInclusive: taxInclusive,
  );

  void dispose() {
    description.dispose();
    quantity.dispose();
    unit.dispose();
    unitPrice.dispose();
    costPrice.dispose();
    discount.dispose();
    taxRate.dispose();
  }
}
