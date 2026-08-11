from pathlib import Path
import re

def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")

def replace_once(text: str, old: str, new: str, path: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one occurrence, found {count}: {old[:140]!r}")
    return text.replace(old, new, 1)

path = "lib/commercial/services/commercial_service.dart"
text = read(path)

text = replace_once(
    text,
    "'document_no': _number(_documentPrefix(draft.type), now),",
    """'document_no': await _uniqueDocumentNumber(
          txn,
          prefix: _documentPrefix(draft.type),
          at: now,
        ),""",
    path,
)

text = replace_once(
    text,
    """'document_no': _number(
          _documentPrefix(source['document_type'] as String),
          now,
        ),""",
    """'document_no': await _uniqueDocumentNumber(
          txn,
          prefix: _documentPrefix(source['document_type'] as String),
          at: now,
        ),""",
    path,
)

marker = """  static String _number(String prefix, DateTime dateTime) {
"""
helper = """  static Future<String> _uniqueDocumentNumber(
    DatabaseExecutor db, {
    required String prefix,
    required DateTime at,
  }) async {
    final base = _number(prefix, at);
    var candidate = base;
    var attempt = 0;
    while (true) {
      final existing =
          firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM documents WHERE document_no = ?',
              [candidate],
            ),
          ) ??
          0;
      if (existing == 0) return candidate;
      attempt += 1;
      candidate = '$base-$attempt';
    }
  }

"""
text = replace_once(text, marker, helper + marker, path)
write(path, text)

path = "lib/commercial/screens/document_editor_dialog.dart"
text = read(path)

text = replace_once(
    text,
    """          child: Column(
            children: [
""",
    """          child: ListView(
            children: [
""",
    path,
)

text = replace_once(
    text,
    """              Expanded(
                child: _lines.isEmpty
""",
    """              SizedBox(
                height: 260,
                child: _lines.isEmpty
""",
    path,
)

text = replace_once(
    text,
    """                  Expanded(
                    child: TextField(
                      controller: _barcode,
""",
    """                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _barcode,
""",
    path,
)

text = text.replace(
    "child: DropdownButtonFormField<String>(\n",
    "child: DropdownButtonFormField<String>(\n                      isExpanded: true,\n",
)
text = text.replace(
    "child: DropdownButtonFormField<int?>(\n",
    "child: DropdownButtonFormField<int?>(\n                      isExpanded: true,\n",
)

text = text.replace("label: const Text('Barcode add'),", "label: const Text('Add'),", 1)
text = text.replace("label: const Text('Product line'),", "label: const Text('Product'),", 1)
text = text.replace("label: const Text('Service line'),", "label: const Text('Service'),", 1)
write(path, text)

test_path = Path("test/build9_workflow_regression_test.dart")
test_path.write_text(
    """import 'package:airmonlink_business_manager/commercial/screens/document_editor_dialog.dart';
import 'package:airmonlink_business_manager/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Build 9 new commercial document starts empty and fits compact window',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final product = Product(
        id: 1,
        name: 'Alpha Product',
        sku: 'ALPHA-1',
        barcode: '10001',
        category: 'General',
        costPrice: 4,
        sellingPrice: 10,
        stockQty: 20,
        lowStockLevel: 5,
        createdAt: DateTime(2026, 8, 10),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CommercialDocumentEditorDialog(
                      products: [product],
                      customers: const [],
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      expect(find.text('Add a product or service line.'), findsOneWidget);
      expect(find.text('Alpha Product'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
""",
    encoding="utf-8",
)

print("Build 9 validation hardening staged.")
