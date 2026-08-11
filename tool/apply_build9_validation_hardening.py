from pathlib import Path

def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")

def apply_edit(text: str, old: str, new: str, path: str, label: str) -> str:
    old_count = text.count(old)
    new_count = text.count(new)
    if old_count == 1 and new_count == 0:
        return text.replace(old, new, 1)
    if old_count == 0 and new_count == 1:
        print(f"{path}: {label} already applied")
        return text
    raise SystemExit(
        f"{path}: {label} anchor mismatch "
        f"(old={old_count}, new={new_count})"
    )

path = "lib/commercial/screens/document_editor_dialog.dart"
text = read(path)

edits = [
    (
        "          child: Column(\n"
        "            children: [",
        "          child: ListView(\n"
        "            children: [",
        "scrollable dialog body",
    ),
    (
        "                    child: DropdownButtonFormField<String>(\n"
        "                      initialValue: _type,",
        "                    child: DropdownButtonFormField<String>(\n"
        "                      isExpanded: true,\n"
        "                      initialValue: _type,",
        "expanded document-type dropdown",
    ),
    (
        "                    child: DropdownButtonFormField<int?>(\n"
        "                      initialValue: _customerId,",
        "                    child: DropdownButtonFormField<int?>(\n"
        "                      isExpanded: true,\n"
        "                      initialValue: _customerId,",
        "expanded customer dropdown",
    ),
    (
        "              Row(\n"
        "                children: [\n"
        "                  Expanded(\n"
        "                    child: TextField(\n"
        "                      controller: _barcode,",
        "              Wrap(\n"
        "                spacing: 8,\n"
        "                runSpacing: 8,\n"
        "                crossAxisAlignment: WrapCrossAlignment.center,\n"
        "                children: [\n"
        "                  SizedBox(\n"
        "                    width: 260,\n"
        "                    child: TextField(\n"
        "                      controller: _barcode,",
        "responsive barcode/product/service toolbar",
    ),
    (
        "              Expanded(\n"
        "                child: _lines.isEmpty",
        "              SizedBox(\n"
        "                height: 260,\n"
        "                child: _lines.isEmpty",
        "bounded line-items area",
    ),
    (
        "                  child: DropdownButtonFormField<int?>(\n"
        "                    initialValue: line.productId,",
        "                  child: DropdownButtonFormField<int?>(\n"
        "                    isExpanded: true,\n"
        "                    initialValue: line.productId,",
        "expanded product/service dropdown",
    ),
    (
        "                              child: Text(entry.value),",
        "                              child: Text(\n"
        "                                entry.value,\n"
        "                                overflow: TextOverflow.ellipsis,\n"
        "                              ),",
        "document-type text overflow handling",
    ),
    (
        "                          child: Text('Walk-in / unassigned'),",
        "                          child: Text(\n"
        "                            'Walk-in / unassigned',\n"
        "                            overflow: TextOverflow.ellipsis,\n"
        "                          ),",
        "walk-in customer text overflow handling",
    ),
    (
        "                            child: Text(customer.name),",
        "                            child: Text(\n"
        "                              customer.name,\n"
        "                              overflow: TextOverflow.ellipsis,\n"
        "                            ),",
        "customer text overflow handling",
    ),
    (
        "                        child: Text('Select product / manual line'),",
        "                        child: Text(\n"
        "                          'Select product / manual line',\n"
        "                          overflow: TextOverflow.ellipsis,\n"
        "                        ),",
        "manual-line text overflow handling",
    ),
    (
        "                          child: Text(product.name),",
        "                          child: Text(\n"
        "                            product.name,\n"
        "                            overflow: TextOverflow.ellipsis,\n"
        "                          ),",
        "product text overflow handling",
    ),
    (
        "                    label: const Text('Barcode add'),",
        "                    label: const Text('Add'),",
        "compact barcode button label",
    ),
    (
        "                    label: const Text('Product line'),",
        "                    label: const Text('Product'),",
        "compact product button label",
    ),
    (
        "                    label: const Text('Service line'),",
        "                    label: const Text('Service'),",
        "compact service button label",
    ),
]

for old, new, label in edits:
    text = apply_edit(text, old, new, path, label)

# Write only after every anchor has validated in memory.
write(path, text)

test_path = Path("test/build9_workflow_regression_test.dart")
test_text = "\n".join([
    "import 'package:airmonlink_business_manager/commercial/screens/document_editor_dialog.dart';",
    "import 'package:airmonlink_business_manager/models/product.dart';",
    "import 'package:flutter/material.dart';",
    "import 'package:flutter_test/flutter_test.dart';",
    "",
    "void main() {",
    "  testWidgets(",
    "    'Build 9 new commercial document starts empty and fits compact window',",
    "    (tester) async {",
    "      await tester.binding.setSurfaceSize(const Size(800, 600));",
    "      addTearDown(() => tester.binding.setSurfaceSize(null));",
    "",
    "      final product = Product(",
    "        id: 1,",
    "        name: 'Alpha Product',",
    "        sku: 'ALPHA-1',",
    "        barcode: '10001',",
    "        category: 'General',",
    "        costPrice: 4,",
    "        sellingPrice: 10,",
    "        stockQty: 20,",
    "        lowStockLevel: 5,",
    "        createdAt: DateTime(2026, 8, 10),",
    "      );",
    "",
    "      await tester.pumpWidget(",
    "        MaterialApp(",
    "          home: Scaffold(",
    "            body: Builder(",
    "              builder: (context) => Center(",
    "                child: FilledButton(",
    "                  onPressed: () => showDialog<void>(",
    "                    context: context,",
    "                    builder: (_) => CommercialDocumentEditorDialog(",
    "                      products: [product],",
    "                      customers: const [],",
    "                    ),",
    "                  ),",
    "                  child: const Text('Open editor'),",
    "               ),",
    "              ),",
    "            ),",
    "        ),",
    "      ),",
    "",
    "      await tester.tap(find.text('Open editor'));",
    "      await tester.pumpAndSettle();",
    "",
    "      expect(",
    "        find.text('Add a product or service line.'),",
    "        findsOneWidget,",
    "      );",
    "      expect(find.text('Alpha Product'), findsNothing);",
    "      expect(tester.takeException(), isNull);",
    "    },",
    "  );",
    "}",
    "",
])
test_path.write_text(test_text, encoding="utf-8")
print("Build 9 validation hardening applied.")
