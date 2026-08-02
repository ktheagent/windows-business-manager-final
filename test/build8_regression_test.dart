import 'package:airmonlink_business_manager/commercial/models/commercial_models.dart';
import 'package:airmonlink_business_manager/commercial/services/advanced_report_service.dart';
import 'package:airmonlink_business_manager/commercial/services/commercial_service.dart';
import 'package:airmonlink_business_manager/core/money.dart';
import 'package:airmonlink_business_manager/models/contact.dart';
import 'package:airmonlink_business_manager/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixtures.dart';

void main() {
  group('Build 8 financial calculations', () {
    test('minor-unit arithmetic avoids binary floating point drift', () {
      expect(MoneyMath.add([0.1, 0.2]), 0.3);
      expect(MoneyMath.subtract(10, 9.99), 0.01);
      expect(MoneyMath.percent(19.99, 15), 3);
    });

    test(
      'multi-line document totals include discounts and mixed tax modes',
      () {
        const draft = CommercialDocumentDraft(
          type: 'tax_invoice',
          customerId: null,
          items: [
            CommercialDocumentItem(
              description: 'Exclusive tax service',
              quantity: 2,
              unitPrice: 10,
              costPrice: 0,
              lineDiscount: 1,
              taxRate: 15,
            ),
            CommercialDocumentItem(
              description: 'Inclusive tax service',
              quantity: 1,
              unitPrice: 11.50,
              costPrice: 0,
              taxRate: 15,
              taxInclusive: true,
            ),
          ],
          discount: 0.50,
          tax: 0,
          notes: '',
          terms: '',
        );
        expect(draft.subtotal, 30.50);
        expect(draft.itemTax, 4.35);
        expect(draft.total, 32.85);
      },
    );
  });

  group('Build 8 commercial integrity', () {
    late DatabaseService database;
    late CommercialService commercial;
    late StaffUser owner;

    setUp(() async {
      database = DatabaseService.forTesting();
      commercial = CommercialService(database);
      owner = await commercial.createInitialOwner(
        name: 'Owner',
        username: 'owner',
        pin: '2468',
      );
      await createTestProduct(database);
    });

    tearDown(() => database.close());

    test('production database starts without demo business records', () async {
      final db = await database.database;
      expect(
        SqfliteFirstInt.value(await db.rawQuery('SELECT COUNT(*) FROM sales')),
        0,
      );
      expect(
        SqfliteFirstInt.value(
          await db.rawQuery('SELECT COUNT(*) FROM customers'),
        ),
        0,
      );
      expect(
        SqfliteFirstInt.value(
          await db.rawQuery('SELECT COUNT(*) FROM suppliers'),
        ),
        0,
      );
    });

    test(
      'temporary staff PIN must be changed and old PIN stops working',
      () async {
        final userId = await commercial.createStaff(
          actor: owner,
          branchId: owner.branchId,
          name: 'Cashier',
          username: 'cashier',
          pin: '1111',
          role: StaffRole.cashier,
          forcePinChange: true,
        );
        var cashier = await commercial.login(username: 'cashier', pin: '1111');
        expect(cashier.forcePinChange, isTrue);
        await commercial.changeOwnPin(
          actor: cashier,
          currentPin: '1111',
          newPin: '7391',
        );
        await commercial.endStaffSession(cashier);
        await expectLater(
          commercial.login(username: 'cashier', pin: '1111'),
          throwsStateError,
        );
        cashier = await commercial.login(username: 'cashier', pin: '7391');
        expect(cashier.id, userId);
        expect(cashier.forcePinChange, isFalse);
      },
    );

    test(
      'document draft edit duplicate cancellation and history persist',
      () async {
        final product = (await database.getProducts()).single;
        final firstDraft = CommercialDocumentDraft(
          type: 'quotation',
          customerId: null,
          items: [
            CommercialDocumentItem(
              productId: product.id,
              description: product.name,
              quantity: 1,
              unitPrice: 10,
              costPrice: 5,
            ),
          ],
          discount: 0,
          tax: 0,
          notes: 'Initial',
          terms: 'Seven days',
        );
        final documentId = await commercial.createDocument(
          actor: owner,
          draft: firstDraft,
        );
        await commercial.updateDocumentDraft(
          actor: owner,
          documentId: documentId,
          draft: CommercialDocumentDraft(
            type: 'quotation',
            customerId: null,
            items: [
              CommercialDocumentItem(
                productId: product.id,
                description: product.name,
                quantity: 2,
                unitPrice: 10,
                costPrice: 5,
                lineDiscount: 1,
              ),
            ],
            discount: 0,
            tax: 0,
            notes: 'Revised',
            terms: 'Fourteen days',
          ),
        );
        final copyId = await commercial.duplicateDocument(
          actor: owner,
          documentId: documentId,
        );
        await commercial.cancelDocument(
          actor: owner,
          documentId: documentId,
          reason: 'Customer changed request',
        );
        final db = await database.database;
        final original = (await db.query(
          'documents',
          where: 'id = ?',
          whereArgs: [documentId],
        )).single;
        final copy = (await db.query(
          'documents',
          where: 'id = ?',
          whereArgs: [copyId],
        )).single;
        expect(original['status'], 'cancelled');
        expect((original['total'] as num).toDouble(), 19);
        expect(copy['status'], 'draft');
        expect(copy['duplicated_from_id'], documentId);
        final history = await commercial.documentStatusHistory(
          actor: owner,
          documentId: documentId,
        );
        expect(history.map((row) => row['new_status']), contains('cancelled'));
      },
    );

    test(
      'purchase receipt transaction reference prevents duplicate posting',
      () async {
        final product = (await database.getProducts()).single;
        final supplierId = await database.addContact(
          BusinessContact(
            id: null,
            type: ContactType.supplier,
            name: 'Supplier',
            phone: '',
            email: '',
            balance: 0,
            createdAt: DateTime.now(),
          ),
        );
        final orderId = await commercial.createPurchaseOrder(
          actor: owner,
          supplierId: supplierId,
          items: [
            {
              'product_id': product.id,
              'description': product.name,
              'quantity': 5.0,
              'unit_cost': 5.0,
              'tax_rate': 0.0,
            },
          ],
        );
        final item = (await commercial.purchaseOrderItems(
          actor: owner,
          purchaseOrderId: orderId,
        )).single;
        await commercial.receivePurchaseOrder(
          actor: owner,
          purchaseOrderId: orderId,
          quantitiesByItemId: {item['id'] as int: 2},
          transactionRef: 'GRN-IDEMPOTENCY-1',
        );
        final stockAfterFirst = (await database.getProducts()).single.stockQty;
        await expectLater(
          commercial.receivePurchaseOrder(
            actor: owner,
            purchaseOrderId: orderId,
            quantitiesByItemId: {item['id'] as int: 1},
            transactionRef: 'GRN-IDEMPOTENCY-1',
          ),
          throwsA(anything),
        );
        expect((await database.getProducts()).single.stockQty, stockAfterFirst);
      },
    );

    test(
      'partial transfer records discrepancies and controlled reversal',
      () async {
        final product = (await database.getProducts()).single;
        final initialSource = product.stockQty;
        final destinationId = await commercial.createBranch(
          actor: owner,
          name: 'Destination',
          code: 'DST',
        );
        final transferId = await commercial.createStockTransfer(
          actor: owner,
          destinationBranchId: destinationId,
          quantitiesByProductId: {product.id!: 5},
        );
        await commercial.approveStockTransfer(
          actor: owner,
          transferId: transferId,
          reason: 'Stock verified',
        );
        await commercial.dispatchStockTransfer(
          actor: owner,
          transferId: transferId,
        );
        final destinationOwner = owner.copyWith(branchId: destinationId);
        await commercial.receiveStockTransfer(
          actor: destinationOwner,
          transferId: transferId,
          receivedByProductId: {product.id!: 3},
          damagedByProductId: {product.id!: 1},
          missingByProductId: {product.id!: 1},
          discrepancyReasons: {product.id!: 'One damaged and one missing'},
        );
        var transfer = (await commercial.listStockTransfers(owner)).single;
        expect(transfer['status'], 'completed');
        final destinationStock = (await database.getProducts(
          branchId: destinationId,
        )).single.stockQty;
        expect(destinationStock, 3);
        await commercial.reverseStockTransfer(
          actor: owner,
          transferId: transferId,
          reason: 'Approved correction',
        );
        transfer = (await commercial.listStockTransfers(owner)).single;
        expect(transfer['status'], 'reversed');
        expect(
          (await database.getProducts()).single.stockQty,
          initialSource - 2,
        );
        expect(
          (await database.getProducts(branchId: destinationId)).single.stockQty,
          0,
        );
      },
    );

    test('recurring automatic posting is idempotent for one due key', () async {
      final due = DateTime(2026, 7, 1);
      await commercial.createRecurringExpense(
        actor: owner,
        title: 'Internet',
        category: 'Utilities',
        amount: 50,
        paymentMethod: 'Bank',
        frequency: 'monthly',
        startDate: due,
        automaticPosting: true,
      );
      expect(
        await commercial.processDueRecurringExpenses(
          actor: owner,
          now: DateTime(2026, 7, 1, 12),
        ),
        1,
      );
      expect(
        await commercial.processDueRecurringExpenses(
          actor: owner,
          now: DateTime(2026, 7, 1, 13),
        ),
        0,
      );
      final db = await database.database;
      expect(
        SqfliteFirstInt.value(
          await db.rawQuery(
            'SELECT COUNT(*) FROM expenses WHERE recurring_expense_id IS NOT NULL',
          ),
        ),
        1,
      );
    });

    test('advanced reports enforce branch isolation', () async {
      final destinationId = await commercial.createBranch(
        actor: owner,
        name: 'Other branch',
        code: 'OTH',
      );
      final reportService = AdvancedReportService(database);
      await expectLater(
        reportService.run(
          actor: owner.copyWith(
            branchId: destinationId,
            role: StaffRole.cashier,
            permissions: {CommercialPermission.reportsView},
          ),
          kind: CommercialReportKind.revenue,
          filter: CommercialReportFilter(branchId: owner.branchId),
        ),
        throwsStateError,
      );
    });

    test('audit records cannot be updated or deleted', () async {
      await commercial.logAudit(
        actor: owner,
        action: 'regression.audit',
        entityType: 'test',
        entityId: '1',
      );
      final db = await database.database;
      await expectLater(
        db.rawUpdate("UPDATE audit_logs SET action = 'tampered'"),
        throwsA(anything),
      );
      await expectLater(
        db.rawDelete('DELETE FROM audit_logs'),
        throwsA(anything),
      );
    });
  });
}

/// Local equivalent of Sqflite.firstIntValue that keeps this test independent
/// of package implementation details.
abstract final class SqfliteFirstInt {
  static int value(List<Map<String, Object?>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) return 0;
    final value = rows.first.values.first;
    return (value as num? ?? 0).toInt();
  }
}
