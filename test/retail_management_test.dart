import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sbill/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting();
  });

  tearDown(() async {
    await db.close();
  });

  test('purchase updates stock, cost, supplier balance and expiry batch atomically', () async {
    final now = DateTime.now();
    await db.saveSupplier(SuppliersCompanion.insert(
      id: 'supplier-1',
      name: 'Test Supplier',
      createdAt: now,
      updatedAt: now,
    ));
    await db.saveItem(ItemsCompanion.insert(
      id: 'item-1',
      name: 'Test Product',
      priceMinor: 10000,
      costMinor: const Value(4000),
      stockQuantity: const Value(10),
      createdAt: now,
      updatedAt: now,
    ));
    final item = await (db.select(db.items)..where((t) => t.id.equals('item-1'))).getSingle();

    await db.recordPurchase(
      purchaseId: 'purchase-1',
      purchaseNumber: 'PUR-001',
      supplierId: 'supplier-1',
      lines: [
        PurchaseLine(
          id: 'purchase-line-1',
          itemId: item.id,
          quantity: 5,
          unitCostMinor: 5000,
          taxRateBps: 1800,
          expiryDate: now.add(const Duration(days: 90)),
        ),
      ],
      discountMinor: 0,
      paidMinor: 10000,
    );

    final saved = await (db.select(db.items)..where((t) => t.id.equals('item-1'))).getSingle();
    expect(saved.stockQuantity, 15);
    expect(saved.costMinor, 5000);
    expect(await db.supplierOutstandingMinor('supplier-1'), 19500);
    expect((await db.recentPurchases()).single.paymentStatus, 'partial');
    expect((await db.expiringStock(withinDays: 120)), hasLength(1));
  });

  test('checkout reduces purchased expiry batches and snapshots cost for profit', () async {
    final now = DateTime.now();
    await db.saveSupplier(SuppliersCompanion.insert(
      id: 'supplier-1',
      name: 'Test Supplier',
      createdAt: now,
      updatedAt: now,
    ));
    await db.saveItem(ItemsCompanion.insert(
      id: 'item-1',
      name: 'Test Product',
      priceMinor: 10000,
      costMinor: const Value(5000),
      stockQuantity: const Value(5),
      createdAt: now,
      updatedAt: now,
    ));
    await db.into(db.stockBatches).insert(StockBatchesCompanion.insert(
      id: 'batch-1',
      itemId: 'item-1',
      quantity: 5,
      expiryDate: Value(now.add(const Duration(days: 60))),
      createdAt: now,
    ));
    final item = await (db.select(db.items)..where((t) => t.id.equals('item-1'))).getSingle();

    await db.checkout(
      invoiceId: 'invoice-1',
      invoiceNumber: 'INV-001',
      cart: [CartLine(id: 'line-1', item: item, quantity: 2)],
      discountMinor: 1000,
      paymentMethod: 'cash',
    );

    final line = await db.invoiceItemsFor('invoice-1');
    expect(line.single.unitCostMinor, 5000);
    expect(line.single.lineDiscountMinor, 1000);
    expect((await db.select(db.stockBatches).getSingle()).quantity, 3);
    expect(
      await db.grossProfitBetween(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      ),
      9000,
    );
  });

  test('stock adjustments cannot make stock negative and are auditable', () async {
    final now = DateTime.now();
    await db.saveItem(ItemsCompanion.insert(
      id: 'item-1',
      name: 'Test Product',
      priceMinor: 10000,
      stockQuantity: const Value(3),
      createdAt: now,
      updatedAt: now,
    ));

    await db.adjustStock(
      id: 'adjust-1',
      itemId: 'item-1',
      quantityDelta: -2,
      reason: 'Damaged goods',
    );
    expect((await db.select(db.items).getSingle()).stockQuantity, 1);
    expect((await db.select(db.stockAdjustments).getSingle()).reason, 'Damaged goods');

    await expectLater(
      db.adjustStock(
        id: 'adjust-2',
        itemId: 'item-1',
        quantityDelta: -2,
        reason: 'Incorrect count',
      ),
      throwsStateError,
    );
    expect((await db.select(db.items).getSingle()).stockQuantity, 1);
  });

  test('expenses are stored and included in date-range totals', () async {
    final now = DateTime.now();
    await db.addExpense(
      id: 'expense-1',
      category: 'Electricity',
      description: 'Monthly bill',
      amountMinor: 250000,
      incurredAt: now,
    );
    expect(
      await db.expensesBetween(
        now.subtract(const Duration(days: 1)),
        now.add(const Duration(days: 1)),
      ),
      250000,
    );
  });
}
