import 'package:airmonlink_business_manager/commercial/screens/document_editor_dialog.dart';
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
