from pathlib import Path

def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"pattern not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")

editor = "lib/commercial/screens/document_editor_dialog.dart"

replace_once(
    editor,
    """    } else {
      _addProductLine(widget.products.isEmpty ? null : widget.products.first);
    }""",
    """    }""",
)

replace_once(
    editor,
    """                    onPressed: () => _addProductLine(
                      widget.products.isEmpty ? null : widget.products.first,
                    ),""",
    """                    onPressed: () => _addProductLine(null),""",
)

replace_once(
    editor,
    """                        child: Text('Manual service'),""",
    """                        child: Text('Select product / manual service'),""",
)

replace_once(
    editor,
    """    if (query.isEmpty) return;""",
    """    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan or enter a barcode or SKU first.'),
        ),
      );
      return;
    }""",
)

replace_once(
    editor,
    """          content: Text('No active product matches that barcode.'),""",
    """          content: Text('No active product matches that barcode or SKU.'),""",
)

replace_once(
    editor,
    """  factory _LineController.service() => _LineController.fromProduct(null);""",
    """  factory _LineController.service() {
    final line = _LineController.fromProduct(null);
    line.unit.text = 'service';
    return line;
  }""",
)

replace_once(
    editor,
    """  void setProduct(Product? product) {
    productId = product?.id;
    if (product != null) {
      description.text = product.name;
      unitPrice.text = product.sellingPrice.toStringAsFixed(2);
      costPrice.text = product.costPrice.toStringAsFixed(2);
    }
  }""",
    """  void setProduct(Product? product) {
    productId = product?.id;
    if (product == null) {
      description.clear();
      unit.text = 'service';
      unitPrice.text = '0.00';
      costPrice.text = '0.00';
      return;
    }
    unit.text = 'each';
    description.text = product.name;
    unitPrice.text = product.sellingPrice.toStringAsFixed(2);
    costPrice.text = product.costPrice.toStringAsFixed(2);
  }""",
)

replace_once(
    editor,
    """                    child: DropdownButtonFormField<String>(
                      initialValue: _type,""",
    """                    child: DropdownButtonFormField<String>(
                      initialValue: _type,
                      style: const TextStyle(
                        color: Color(0xFF0F2A5A),
                        fontWeight: FontWeight.w800,
                      ),
                      dropdownColor: Colors.white,""",
)

replace_once(
    editor,
    """                    child: DropdownButtonFormField<int?>(
                      initialValue: _customerId,""",
    """                    child: DropdownButtonFormField<int?>(
                      initialValue: _customerId,
                      style: const TextStyle(
                        color: Color(0xFF0F2A5A),
                        fontWeight: FontWeight.w700,
                      ),
                      dropdownColor: Colors.white,""",
)

replace_once(
    editor,
    """                  child: DropdownButtonFormField<int?>(
                    initialValue: line.productId,""",
    """                  child: DropdownButtonFormField<int?>(
                    initialValue: line.productId,
                    style: const TextStyle(
                      color: Color(0xFF0F2A5A),
                      fontWeight: FontWeight.w700,
                    ),
                    dropdownColor: Colors.white,""",
)

theme = "lib/core/app_theme.dart"
replace_once(
    theme,
    """        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
        ),""",
    """        hintStyle: const TextStyle(
          color: Color(0xFF52637A),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
        ),""",
)

pos = "lib/screens/pos_screen.dart"
replace_once(
    pos,
    """import '../core/formatters.dart';""",
    """import '../commercial/models/commercial_models.dart';
import '../core/formatters.dart';""",
)

replace_once(
    pos,
    """            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _cart.isEmpty ? null : () => _checkout(context, state),""",
    """            const SizedBox(height: 14),
            if (state.currentCashSession == null) ...[
              OutlinedButton.icon(
                onPressed: state.can(CommercialPermission.cashManage)
                    ? () => _openCashShift(context, state)
                    : null,
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('Open cash shift'),
              ),
              const SizedBox(height: 8),
              Text(
                state.can(CommercialPermission.cashManage)
                    ? 'Cash sales require an open shift.'
                    : 'Cash sales require an open shift. Ask an authorized user to open one.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: _cart.isEmpty ? null : () => _checkout(context, state),""",
)

replace_once(
    pos,
    """  Future<void> _checkout(BuildContext context, AppState state) async {
    final discountController = TextEditingController(text: '0.00');""",
    """  Future<bool> _openCashShift(BuildContext context, AppState state) async {
    if (state.currentCashSession != null) return true;
    final user = state.currentUser;
    if (user == null) {
      showFailure(context, 'Sign in before opening a cash shift.');
      return false;
    }
    if (!user.can(CommercialPermission.cashManage)) {
      showFailure(
        context,
        'Cash sale requires an open shift. Ask an authorized user to open one.',
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
      if (registers.isEmpty) {
        throw StateError('Unable to configure a cash register.');
      }
      await state.commercial.openCashSession(
        actor: user,
        registerId: registers.first['id'] as int,
        openingFloat: 0,
        note: 'Opened from Point of Sale',
      );
      await state.refreshAll();
      if (!context.mounted) return false;
      showSuccess(context, 'Cash shift opened.');
      return state.currentCashSession != null;
    } catch (error) {
      if (context.mounted) showFailure(context, error);
      return false;
    }
  }

  Future<void> _checkout(BuildContext context, AppState state) async {
    final discountController = TextEditingController(text: '0.00');""",
)

replace_once(
    pos,
    """    if (checkout == null || !context.mounted) {
      return;
    }
    final draft = SaleDraft(""",
    """    if (checkout == null || !context.mounted) {
      return;
    }
    if (checkout.paymentMethod == 'Cash' &&
        state.currentCashSession == null) {
      final opened = await _openCashShift(context, state);
      if (!opened || !context.mounted) return;
    }
    final draft = SaleDraft(""",
)

replace_once("pubspec.yaml", "version: 1.3.0+8", "version: 1.3.0+9")
