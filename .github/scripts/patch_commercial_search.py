from pathlib import Path
import re

path = Path("lib/commercial/screens/document_editor_dialog.dart")
text = path.read_text(encoding="utf-8")

def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    text = text.replace(old, new, 1)

def sub_once(pattern: str, replacement: str, label: str, flags: int = 0) -> None:
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")

replace_once(
    "final _barcode = TextEditingController();",
    "final _productSearch = TextEditingController();",
    "product search controller",
)
replace_once(
    "_barcode.dispose();",
    "_productSearch.dispose();",
    "product search dispose",
)

sub_once(
    r'''(?ms)^(\s*)\}\s*else\s*\{\s*
        _addProductLine\(\s*
        widget\.products\.isEmpty\s*\?\s*null\s*:\s*widget\.products\.first
        \s*\);\s*
        \}''',
    r"\1}",
    "automatic first-product block",
    flags=re.VERBOSE,
)

start_marker = "  void _addBarcodeProduct() {"
end_marker = "  CommercialDocumentDraft _buildDraft() {"
start = text.find(start_marker)
end = text.find(end_marker, start)
if start == -1 or end == -1:
    raise SystemExit("commercial product search method boundaries not found")

search_methods = r'''  int _productSearchRank(Product product, String query) {
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
      final rank = _productSearchRank(
        a,
        query,
      ).compareTo(_productSearchRank(b, query));
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

'''
text = text[:start] + search_methods + text[end:]

replace_once(
    "controller: _barcode,",
    "controller: _productSearch,",
    "search field controller",
)
replace_once(
    "labelText: 'Barcode or SKU',",
    "labelText: 'Product name, SKU, barcode or category',",
    "search field label",
)
replace_once(
    "prefixIcon: Icon(Icons.qr_code_scanner),",
    "prefixIcon: Icon(Icons.search),",
    "search field icon",
)
replace_once(
    "onSubmitted: (_) => _addBarcodeProduct(),",
    "onSubmitted: (_) => _addSearchedProduct(),",
    "search submit",
)
replace_once(
    "onPressed: _addBarcodeProduct,",
    "onPressed: _addSearchedProduct,",
    "search button action",
)
replace_once(
    "label: const Text('Barcode add'),",
    "label: const Text('Find & add'),",
    "search button label",
)

sub_once(
    r'''(?ms)onPressed:\s*\(\)\s*=>\s*_addProductLine\(\s*
        widget\.products\.isEmpty\s*\?\s*null\s*:\s*widget\.products\.first,\s*
        \),''',
    "onPressed: () => _addProductLine(null),",
    "product-line button auto selection",
    flags=re.VERBOSE,
)

for token in [
    "_barcode",
    "_addBarcodeProduct",
    "widget.products.first",
    "labelText: 'Barcode or SKU'",
    "Barcode add",
]:
    if token in text:
        raise SystemExit(f"old commercial product-search behavior remains: {token}")

for token in [
    "_productSearch",
    "_addSearchedProduct",
    "_matchingProducts",
    "Product name, SKU, barcode or category",
    "Find & add",
    "_addProductLine(null)",
]:
    if token not in text:
        raise SystemExit(f"new commercial product-search behavior missing: {token}")

path.write_text(text, encoding="utf-8")
