from pathlib import Path

path = Path("lib/commercial/screens/document_editor_dialog.dart")
lines = path.read_text(encoding="utf-8").splitlines()

for i, line in enumerate(lines):
    if "final _barcode = TextEditingController();" in line:
        lines[i] = line.replace("_barcode", "_productSearch")
        break
else:
    raise SystemExit("barcode controller not found")

i = 0
removed = False
while i < len(lines) - 2:
    if (
        lines[i].strip() == "} else {"
        and "_addProductLine(widget.products.isEmpty ? null : widget.products.first);" in lines[i + 1]
        and lines[i + 2].strip() == "}"
    ):
        indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
        lines[i:i + 3] = [indent + "}"]
        removed = True
        break
    i += 1
if not removed:
    raise SystemExit("automatic first-product block not found")

for i, line in enumerate(lines):
    if "_barcode.dispose();" in line:
        lines[i] = line.replace("_barcode", "_productSearch")
        break
else:
    raise SystemExit("barcode dispose not found")

start = next((i for i, line in enumerate(lines) if line.strip() == "void _addBarcodeProduct() {"), None)
end = next(
    (
        i
        for i, line in enumerate(lines)
        if start is not None
        and i > start
        and line.strip().startswith("CommercialDocumentDraft _buildDraft()")
    ),
    None,
)
if start is None or end is None:
    raise SystemExit("search helper boundaries not found")

method = r'''  int _productSearchRank(Product product, String query) {
    final name = product.name.trim().toLowerCase();
    final sku = product.sku.trim().toLowerCase();
    final barcode = product.barcode.trim().toLowerCase();
    final category = product.category.trim().toLowerCase();

    if (barcode == query || sku == query) return 0;
    if (name == query) return 1;
    if (name.startsWith(query)) return 2;
    if (sku.startsWith(query) || barcode.startsWith(query)) return 3;
    if (category == query || category.startsWith(query)) return 4;
    if (name.contains(query)) return 5;
    if (sku.contains(query) || barcode.contains(query)) return 6;
    if (category.contains(query)) return 7;
    return 99;
  }

  List<Product> _matchingProducts(String query) {
    final matches = widget.products
        .where((product) => _productSearchRank(product, query) < 99)
        .toList();
    matches.sort((a, b) {
      final rank = _productSearchRank(a, query)
          .compareTo(_productSearchRank(b, query));
      if (rank != 0) return rank;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matches;
  }

  Future<Product?> _chooseProduct(
    List<Product> matches,
    String query,
  ) async {
    final visible = matches.take(50).toList(growable: false);
    return showDialog<Product>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Select product for "$query"'),
        content: SizedBox(
          width: 640,
          height: 460,
          child: ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = visible[index];
              final details = <String>[
                if (product.sku.trim().isNotEmpty) 'SKU: ${product.sku.trim()}',
                if (product.barcode.trim().isNotEmpty)
                  'Barcode: ${product.barcode.trim()}',
                'Category: ${product.category}',
                'Stock: ${product.stockQty}',
                'Price: ${AppFormatters.money(product.sellingPrice)}',
              ];
              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(details.join(' • ')),
                onTap: () => Navigator.of(dialogContext).pop(product),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSearchedProduct() async {
    final rawQuery = _productSearch.text.trim();
    final query = rawQuery.toLowerCase();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a product name, SKU, barcode, or category first.',
          ),
        ),
      );
      return;
    }

    final matches = _matchingProducts(query);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No product matches that name, SKU, barcode, or category.',
          ),
        ),
      );
      return;
    }

    Product? selected;
    final exactCodes = matches.where((product) {
      return product.barcode.trim().toLowerCase() == query ||
          product.sku.trim().toLowerCase() == query;
    }).toList(growable: false);

    if (exactCodes.length == 1) {
      selected = exactCodes.first;
    } else if (matches.length == 1) {
      selected = matches.first;
    } else {
      selected = await _chooseProduct(matches, rawQuery);
    }

    if (!mounted || selected == null) return;
    _addProductLine(selected);
    _productSearch.clear();
  }
'''.splitlines()

lines[start:end] = method

replacement_pairs = {
    "controller: _barcode,": "controller: _productSearch,",
    "labelText: 'Barcode or SKU',":
        "labelText: 'Search product by name, SKU, barcode, or category',",
    "prefixIcon: Icon(Icons.qr_code_scanner),":
        "prefixIcon: Icon(Icons.search),",
    "onSubmitted: (_) => _addBarcodeProduct(),":
        "onSubmitted: (_) => _addSearchedProduct(),",
    "onPressed: _addBarcodeProduct,":
        "onPressed: _addSearchedProduct,",
    "label: const Text('Barcode add'),":
        "label: const Text('Find & add'),",
}
found = {k: False for k in replacement_pairs}
for i, line in enumerate(lines):
    for old, new in replacement_pairs.items():
        if old in line:
            lines[i] = line.replace(old, new)
            found[old] = True

missing = [old for old, yes in found.items() if not yes]
if missing:
    raise SystemExit(f"quick-add UI patterns missing: {missing}")

changed_product_button = False
i = 0
while i < len(lines) - 2:
    if (
        "onPressed: () => _addProductLine(" in lines[i]
        and "widget.products.isEmpty ? null : widget.products.first," in lines[i + 1]
        and lines[i + 2].strip() == "),"
    ):
        indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
        lines[i:i + 3] = [indent + "onPressed: () => _addProductLine(null),"]
        changed_product_button = True
        break
    i += 1
if not changed_product_button:
    raise SystemExit("Product line auto-selection block not found")

text = "\n".join(lines) + "\n"

for token in [
    "_barcode",
    "_addBarcodeProduct",
    "widget.products.first",
    "labelText: 'Barcode or SKU'",
    "Barcode add",
]:
    if token in text:
        raise SystemExit(f"old product-search behavior remains: {token}")

for token in [
    "_productSearch",
    "_addSearchedProduct",
    "_matchingProducts",
    "Search product by name, SKU, barcode, or category",
    "Find & add",
    "_addProductLine(null)",
]:
    if token not in text:
        raise SystemExit(f"new product-search behavior missing: {token}")

path.write_text(text, encoding="utf-8")
