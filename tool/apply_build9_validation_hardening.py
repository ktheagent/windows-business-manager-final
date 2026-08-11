from pathlib import Path

def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")

def replace_state(
    text: str,
    old: str,
    new: str,
    path: str,
    label: str,
) -> str:
    old_count = text.count(old)
    new_count = text.count(new)

    if old_count == 1 and new_count == 0:
        return text.replace(old, new, 1)
    if old_count == 0 and new_count == 1:
        print(f"{path}: {label} already present")
        return text

    raise SystemExit(
        f"{path}: {label} anchor mismatch "
        f"(old={old_count}, new={new_count})"
    )

path = "lib/commercial/screens/document_editor_dialog.dart"
text = read(path)

edits = [
    (
        "          key: _formKey,\n"
        "          child: Column(\n"
        "            children: [",
        "          key: _formKey,\n"
        "          child: ListView(\n"
        "            children: [",
        "scrollable dialog body",
    ),
    (
        "              Expanded(\n"
        "                child: _lines.isEmpty\n"
        "                    ? const Center(",
        "              SizedBox(\n"
        "                height: 260,\n"
        "                child: _lines.isEmpty\n"
        "                    ? const Center(",
        "bounded line-items area",
    ),
    (
        "Expanded(\n"
        "                    child: TextField(\n"
        "                      controller: _barcode,",
        "SizedBox(\n"
        "                    width: 220,\n"
        "                    child: TextField(\n"
        "                      controller: _barcode,",
        "compact barcode field",
    ),
    (
        "child: DropdownButtonFormField<String>(\n"
        "                     initialValue: _type,",
        "child: DropdownButtonFormField<String>(\n"
        "                     isExpanded: true,\n"
        "                     initialValue: _type,",
        "expanded document-type dropdown",
    ),
    (
        "child: DropdownButtonFormField<int?>(\n"
        "                     initialValue: _customerId,",
        "child: DropdownButtonFormField<int?>(\n"
        "                      isExpanded: true,\n"
        "                      initialValue: _customerId,",
        "expanded customer dropdown",
    ),
    (
        "child: DropdownButtonFormField<int?>(\n"
        "                    initialValue: line.productId,",
        "child: DropdownButtonFormField<int?>(\n"
        "                    isExpanded: true,\n"
        "                    initialValue: line.productId,",
        "expanded product/service dropdown",
    ),
    (
        "label: const Text('Barcode add'),",
        "label: const Text('Add'),",
        "short barcode button label",
    ),
    (
        "label: const Text('Product line'),",
        "label: const Text('Product'),",
        "short product button label",
    ),
    (
        "label: const Text('Service line'),",
        "label: const Text('Service'),",
        "short service button label",
    ),
]

for old, new, label in edits:
    text = replace_state(text, old, new, path, label)

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
