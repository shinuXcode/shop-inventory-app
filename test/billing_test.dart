import 'package:flutter_test/flutter_test.dart';
import 'package:sbill/core/database/app_database.dart';

void main() {
  test('cart line copies quantity without changing product', () {
    final item = Item(
      id: '1', sku: null, name: 'Pen', description: null, priceMinor: 1000,
      costMinor: 0, taxRate: 0, stockQuantity: 10, lowStockThreshold: 2,
      category: null, barcode: null, isActive: true,
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
      syncStatus: 'pending', lastSyncedAt: null);
    final line = CartLine(id: 'line', item: item);
    final copy = line.copyWith(quantity: 3);
    expect(copy.quantity, 3);
    expect(copy.item.id, '1');
  });
}
