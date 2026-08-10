import 'package:flutter/material.dart';

import '../../models/contact.dart';
import '../../models/product.dart';
import '../../models/sale.dart';

typedef PurchaseOrderChoice = ({
  int supplierId,
  int productId,
  double quantity,
  double unitCost,
});

typedef StockAdjustmentChoice = ({
  int productId,
  double quantityChange,
  String reason,
  String note,
});

typedef ReturnChoice = ({
  int saleItemId,
  double quantity,
  String refundMethod,
  String reason,
  bool restock,
});

typedef CashShiftChoice = ({
  int registerId,
  double openingFloat,
});

typedef PaymentChoice = ({
  String method,
  String reference,
});

Future<PurchaseOrderChoice?> showPurchaseOrderChoiceDialog(
  BuildContext context, {
  required List<BusinessContact> suppliers,
  required List<Product> products,
}) async {
  int? supplierId;
  int? productId;
  final quantity = TextEditingController(text: '1');
  final unitCost = TextEditingController();

  final result = await showDialog<PurchaseOrderChoice>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) ?