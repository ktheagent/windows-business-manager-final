import 'package:airmonlink_business_manager/models/product.dart';
import 'package:airmonlink_business_manager/services/database_service.dart';

Future<Product> createTestProduct(
  DatabaseService database, {
  String name = 'Test Product',
  String sku = 'TEST-001',
  String barcode = '1234567890128',
  double costPrice = 5,
  double sellingPrice = 10,
  double stockQty = 100,
}) async {
  final product = Product(
    id: null,
    name: name,
    sku: sku,
    barcode: barcode,
    category: 'Testing',
    costPrice: costPrice,
    sellingPrice: sellingPrice,
    stockQty: stockQty,
    lowStockLevel: 5,
    createdAt: DateTime.now(),
  );
  final id = await database.addProduct(product);
  return product.copyWith(id: id);
}
