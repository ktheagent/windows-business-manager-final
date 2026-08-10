from pathlib import Path

def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")

def replace_once(text: str, old: str, new: str, path: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one occurrence, found {count}: {old[:120]!r}")
    return text.replace(old, new, 1)

path = "lib/commercial/screens/document_editor_dialog.dart"
text = read(path)
text = replace_once(
    text,
    """    if (draft != null && draft.items.isNotEmpty) {
      for (final item in draft.items) {
        _lines.add(_LineController.fromItem(item));
      }
    } else {
      _addProductLine(widget.products.isEmpty ? null : widget.products.first);
    }
""",
    """    if (draft != null && draft.items.isNotEmpty) {
      for (final item in draft.items) {
        _lines.add(_LineController.fromItem(item));
      }
    }
""",
    path,
)
text = replace_once(
    text,
    """  void _addBarcodeProduct() {
    final query = _barcode.text.trim().toLowerCase();
    if (query.isEmpty) return;
""",
    """  void _addBarcodeProduct() {
    final query = _barcode.text.trim().toLowerCase();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan or enter a barcode or SKU first.')));
      return;
    }
""",
    path,
)
text = replace_once(
    text,
    """          content: Text('No active product matches that barcode.'),
""",
    """          content: Text('No product matches that barcode or SKU.'),
""",
    path,
)
text = replace_once(
    text,
    """                  OutlinedButton.icon(
                    onPressed: () => _addProductLine(
                      widget.products.isEmpty ? null : widget.products.first,
                    ),
""",
    """                  OutlinedButton.icon(
                    onPressed: () => _addProductLine(null),
""",
    path,
)
text = replace_once(
    text,
    """                        child: Text('Manual service'),
""",
    """                        child: Text('Select product / manual line'),
""",
    path,
)
text = replace_once(
    text,
    """  factory _LineController.service() => _LineController.fromProduct(null);
""",
    """  factory _LineController.service() => _LineController(
    productId: null,
    description: TextEditingController(),
    quantity: TextEditingController(text: '1'),
    unit: TextEditingController(text: 'service'),
    unitPrice: TextEditingController(text: '0.00'),
    costPrice: TextEditingController(text: '0.00'),
    discount: TextEditingController(text: '0.00'),
    taxRate: TextEditingController(text: '0.00'),
    taxInclusive: false,
  );
""",
    path,
)
text = replace_once(
    text,
    """  void setProduct(Product? product) {
    productId = product?.id;
    if (product != null) {
      description.text = product.name;
      unitPrice.text = product.sellingPrice.toStringAsFixed(2);
      costPrice.text = product.costPrice.toStringAsFixed(2);
    }
  }
""",
    """  void setProduct(Product? product) {
    productId = product?.id;
    if (product == null) {
      description.clear();
      unit.text = 'each';
      unitPrice.text = '0.00';
      costPrice.text = '0.00';
      return;
    }
    description.text = product.name;
    unit.text = 'each';
    unitPrice.text = product.sellingPrice.toStringAsFixed(2);
    costPrice.text = product.costPrice.toStringAsFixed(2);
  }
""",
    path,
)
write(path, text)

path = "lib/screens/pos_screen.dart"
text = read(path)
text = replace_once(
    text,
    """import '../core/formatters.dart';
""",
    """import '../core/formatters.dart';
import '../commercial/models/commercial_models.dart';
""",
    path,
)
text = replace_once(
    text,
    """            const SizedBox(height: 14),
            FilledButton.icon(
""",
    """            const SizedBox(height: 14),
            if (state.currentCashSession == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Cash sales require an open cash shift. Open one here before taking cash.',
                      ),
                   ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed:
                            state.currentUser?.can(CommercialPermission.cashManage) ==
                                true
                            ? () => _openCashShift(context, state)
                            : null,
                      icon: const Icon(Icons.point_of_sale_outlined),
                      label: const Text('Open cash shift'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
""",
    path,
)
helper = r"""  Future<double?> _askOpeningFloat(BuildContext context) async {
    final controller = TextEditingController(text: '0.00');
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Opening cash float'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Opening cash amount',
            helperText: 'Enter 0 if the drawer starts empty.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Open shift'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _openCashShift(BuildContext context, AppState state) async {
    final user = state.currentUser;
    if (user == null) {
      showFailure(context, 'Sign in before opening a cash shift.');
      return false;
    }
    if (!user.can(CommercialPermission.cashManage)) {
      showFailure(
        context,
        'Your staff role cannot open a cash shift. Ask a manager or owner.',
      );
      return false;
    }
    try {
      var registers = await state.commercial.listCashRegisters(user);
      if (registers.isEmpty) {
        await state.commercial.createCashRegister(
          actor: user,
          name: 'Main Register',
        );
        registers = await state.commercial.listCashRegisters(user);
      }
      if (!context.mounted || registers.isEmpty) return false;

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
                  onPressed: () =>
                      Navigator.pop(dialogContext, register['id'] as int),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(register['name'] as String),
                  ),
                ),
            ],
          ),
        );
      }
      if (registerId == null || !context.mounted) return false;

      final openingFloat = await _askOpeningFloat(context);
      if (openingFloat == null || !context.mounted) return false;

      await state.commercial.openCashSession(
        actor: user,
        registerId: registerId,
        openingFloat: openingFloat,
        note: 'Opened from point of sale',
      );
      await state.refreshAll();
      if (context.mounted) showSuccess(context, 'Cash shift opened.');
      return true;
    } catch (error) {
      if (context.mounted) showFailure(context, error);
      return false;
    }
  }

    """
text = replace_once(
    text,
    """  Future<void> _checkout(BuildContext context, AppState state) async {
""",
    helper + """  Future<void> _checkout(BuildContext context, AppState state) async {
""",
    path,
)
text = replace_once(
    text,
    """    if (checkout == null || !context.mounted) {
      return;
    }

    final draft = SaleDraft(
"",
    """    if (checkout == null || !context.mounted) {
      return;
    }

    if (checkout.paymentMethod == 'Cash' && state.currentCashSession == null) {
      final opened = await _openCashShift(context, state);
      if (!opened || !context.mounted) return;
    }

    final draft = SaleDraft(
""",
    path,
)
write(path, text)

path = "lib/commercial/screens/commercial_suite_screen.dart"
text = read(path)
old_return = r"""  Future<void> _return(BuildContext context) async {
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
"""
new_return = r"""  Future<void> _return(BuildContext context) async {
    final completed = widget.state.sales.where((sale) => sale.id != null).toList();
    if (completed.isEmpty) {
      showFailure(context, 'No completed sale is available for return.');
      return;
    }
    try {
      final saleIndex = await showDialog<int>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Select sale to return'),
          children: [
            for (var index = 0; index < completed.length; index++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, index),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(completed[index].invoiceNo),
                  subtitle: Text(
                    '${completed[index].paymentMethod} • '
                    '${AppFormatters.money(completed[index].total)} • '
                    '${completed[index].createdAt}',
                  ),
                ),
              ),
          ],
        ),
      );
      if (saleIndex == null) return;
      final sale = completed[saleIndex];

      final items = await widget.state.commercial.returnableSaleItems(
        actor: widget.user,
        saleId: sale.id!,
      );
      final available = items
          .cast<Map<String, Object?>>()
          .where((row) => (row['returnable_quantity'] as num).toDouble() > 0)
          .toList(growable: false);
      if (!context.mounted) return;
      if (available.isEmpty) {
        showFailure(context, 'This sale has no items remaining to return.');
        return;
      }

      final itemIndex = await showDialog<int>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: Text('Select item from ${sale.invoiceNo}'),
          children: [
            for (var index = 0; index < available.length; index++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, index),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    available[index]['product_name'] as String? ??
                        'Sale item ${available[index]['id']}',
                  ),
                  subtitle: Text(
                    'Returnable quantity: '
                    '${(available[index]['returnable_quantity'] as num).toDouble().toStringAsFixed(2)}',
                  ),
                ),
              ),
          ],
        ),
      );
      if (itemIndex == null) return;
      final item = available[itemIndex];
      final maximum = (item['returnable_quantity'] as num).toDouble();

      final quantity = await _askNumber(context, 'Return quantity');
      if (quantity == null) return;
      if (quantity <= 0 || quantity > maximum) {
        showFailure(
          context,
          'Return quantity must be greater than 0 and no more than '
          '${maximum.toStringAsFixed(2)}.',
        );
        return;
      }

      final reason = await _askRequiredText(context, 'Return reason');
      if (reason == null) return;
      if (!context.mounted) return;

      final refundMethod = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Refund method'),
          children: [
            if (widget.state.currentCashSession != null)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, 'Cash'),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.payments_outlined),
                  title: Text('Cash'),
                  subtitle: Text('Refund from the currently open cash shift.'),
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'Store credit'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.account_balance_wallet_outlined),
                title: Text('Store credit'),
                subtitle: Text('Do not remove cash from the register.'),
              ),
            ),
          ],
        ),
      );
      if (refundMethod == null || !context.mounted) return;

      final restock = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Restock returned item?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('Restock item'),
                subtitle: Text('Add the returned quantity back to inventory.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.block_outlined),
                title: Text('Do not restock'),
                subtitle: Text('Use for damaged, expired or unusable goods.'),
              ),
            ),
          ],
        ),
      );
      if (restock == null) return;

      await widget.state.commercial.createReturn(
        actor: widget.user,
        saleId: sale.id!,
        quantitiesBySaleItemId: {item['id'] as int: quantity},
        refundMethod: refundMethod,
        reason: reason,
        restock: restock,
        cashSessionId: refundMethod == 'Cash'
            ? widget.state.currentCashSession?['id'] as int?
            : null,
      );
      await widget.state.refreshAll();
      if (mounted) showSuccess(context, 'Return recorded.');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }
"""
text = replace_once(text, old_return, new_return, path)
write(path, text)

path = "lib/core/app_theme.dart"
text = read(path)
text = replace_once(
    text,
    """        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
        ),
""",
    """        hintStyle: const TextStyle(
          color: Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
""",
    path,
)
write(path, text)

path = "pubspec.yaml"
text = replace_once(read(path), "version: 1.3.0+8", "version: 1.3.0+9", path)
write(path, text)

path = ".github/workflows/windows-build.yml"
text = read(path)
for old, new in [
    ("1.3.0+8", "1.3.0+9"),
    ("Build8", "Build9"),
    ("Build 8", "Build 9"),
    ("BUILD8-LOCAL-VALIDATION.json", "BUILD9-LOCAL-VALIDATION.json"),
]:
    text = text.replace(old, new)
write(path, text)

for path in ["tool/package_windows.ps1", "tool/package_source.ps1"]:
    text = read(path)
    text = replace_once(text, "$build = '8'", "$build = '9'", path)
    write(path, text)

path = "tool/build_installer.ps1"
text = replace_once(
    read(path),
    "$productPrefix = 'Airmonlink-Business-Manager-1.3.0-Build8'",
    "$productPrefix = 'Airmonlink-Business-Manager-1.3.0-Build9'",
    path,
)
write(path, text)

path = "installer/airmonlink_business_manager.iss"
text = read(path)
for old, new in [
    ('#define MyAppBuild "8"', '#define MyAppBuild "9"'),
    ('#define MyAppFileVersion "1.3.0.8"', '#define MyAppFileVersion "1.3.0.9"'),
    ("Airmonlink-Business-Manager-1.3.0-Build8-Setup", "Airmonlink-Business-Manager-1.3.0-Build9-Setup"),
]:
    text = replace_once(text, old, new, path)
write(path, text)

path = "tool/validate_source_checkpoint.py"
text = read(path)
text = replace_once(
    text,
    r're.search(r"(?m)^version:\*\1\.3\.0\\+8\s*$", pubspec)',
    r're.search(r"(?m)^version:\*\1\.3\.0\\+9\s*$", pubspec)',
    path,
)
text = text.replace("Build 8 application identity", "Build 9 application identity")
text = text.replace("version: 1.3.0+8", "version: 1.3.0+9")
text = text.replace("Airmonlink-Business-Manager-1.3.0-Build8-", "Airmonlink-Business-Manager-1.3.0-Build9-")
text = text.replace("Build 8 SQLite schema simulation", "Build 9 SQLite schema simulation")
text = text.replace("BUILD8-SOURCE-VALIDATION.json", "BUILD9-SOURCE-VALIDATION.json")
write(path, text)

path = "tool/local_release_validation.py"
text = read(path)
text = replace_once(
    text,
    r 'bool(re.search(r"(?m)^version:\s*1\.3\.0\+8\s*$", pubspec))',
    r 'bool(re.search(r"(?m)^version:\s*1\.3\.0\+9\s*$", pubspec))',
    path,
)
text = text.replace("BUILD8-IDENTITY", "BUILD9-IDENTITY")
text = text.replace("pubspec version must be 1.3.0+8", "pubspec version must be 1.3.0+9")
text = text.replace("Build8-", "Build9-")
text = text.replace("BUILD8-LOCAL-VALIDATION.json", "BUILD9-LOCAL-VALIDATION.json")
write(path, text)

path = "README.md"
text = read(path)
text = text.replace("- Version: `1.3.0+8`", "- Version: `1.3.0+9`")
text = text.replace("- Release branch: `feature/build8-commercial-suite-complete`", "- Release branch: `main`")
text = text.replace("Airmonlink-Business-Manager-1.3.0-Build8-", "Airmonlink-Business-Manager-1.3.0-Build9-")
build9 = """## Build 9 corrective workflow release

- New commercial documents start empty and never auto-select the first product.
- Product lines require an explicit product choice or manual entry; service lines remain distinct.
- POS cash checkout provides an actionable open-cash-shift flow with register selection and opening float.
- Returns require explicit sale, item, quantity, reason, refund method and restock choices.
- Purchase orders, stock adjustments, stock counts and cash registers use explicit user selection.
- Input labels and hints use higher contrast for better readability.
- Database schema remains version 8; no user-data migration is required for this UI/workflow correction.

"""
anchor = "## Existing functions preserved\n"
text = replace_once(text, anchor, build9 + anchor, path)
write(path, text)

path = "CHANGELOG.md"
text = read(path)
entry = """## 1.3.0+9 — 2026-08-10
### Workflow corrections
- Removed automatic first-product selection from new commercial documents and product-line creation.
- Added explicit POS cash-shift opening with cash-register selection and opening float.
- Added explicit sale, item, quantity, reason, refund-method and restock selection for returns.
- Preserved and validated explicit purchase-order, stock-adjustment, physical-count and cash-register workflows.
- Increased input label and hint contrast for clearer selected values and form context.
- Kept SQLite schema version 8 and existing user data unchanged.

"""
text = replace_once(text, "# Changelog\n\n", "# Changelog\n\n" + entry, path)
write(path, text)

print("Build 9 final workflow corrections staged.")
