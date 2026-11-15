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

  Future<Item> seedItem({int stock = 10}) async {
    final now = DateTime(2026);
    await db.saveItem(ItemsCompanion.insert(
      id: 'item-1',
      sku: const Value('USB001'),
      name: 'USB Cable',
      priceMinor: 19900,
      taxRate: const Value(18),
      stockQuantity: Value(stock),
      lowStockThreshold: const Value(2),
      createdAt: now,
      updatedAt: now,
    ));
    return (await db.select(db.items).getSingle());
  }

  test('checkout creates one invoice, item and reduces stock atomically', () async {
    final item = await seedItem();
    await db.checkout(
      invoiceId: 'invoice-1',
      invoiceNumber: 'INV-1',
      cart: [CartLine(id: 'line-1', item: item, quantity: 2)],
      discountMinor: 0,
      paymentMethod: 'cash',
    );

    expect((await db.select(db.invoices).get()).length, 1);
    expect((await db.select(db.invoiceItems).get()).length, 1);
    expect((await db.select(db.items).getSingle()).stockQuantity, 8);
    expect((await db.select(db.syncQueue).get()).length, 3);
  });

  test('checkout applies customer, discount and payment method to stored invoice', () async {
    final item = await seedItem();
    await db.checkout(
      invoiceId: 'invoice-discount',
      invoiceNumber: 'INV-DISCOUNT',
      customerId: 'customer-1',
      cart: [CartLine(id: 'line-discount', item: item, quantity: 2)],
      discountMinor: 1000,
      paymentMethod: 'upi',
    );
    final invoice = await db.invoiceById('invoice-discount');
    expect(invoice, isNotNull);
    expect(invoice!.customerId, 'customer-1');
    expect(invoice.discountMinor, 1000);
    expect(invoice.taxMinor, 6984);
    expect(invoice.totalMinor, 45784);
    expect(invoice.paymentMethod, 'upi');
    expect((await db.select(db.syncQueue).get()).length, 3);
  });

  test('insufficient stock rolls back invoice and stock changes', () async {
    final item = await seedItem(stock: 2);

    expect(
      () => db.checkout(
        invoiceId: 'invoice-fail',
        invoiceNumber: 'INV-FAIL',
        cart: [CartLine(id: 'line-fail', item: item, quantity: 3)],
        discountMinor: 0,
        paymentMethod: 'cash',
      ),
      throwsStateError,
    );

    expect((await db.select(db.invoices).get()), isEmpty);
    expect((await db.select(db.invoiceItems).get()), isEmpty);
    expect((await db.select(db.items).getSingle()).stockQuantity, 2);
    expect((await db.select(db.syncQueue).get()).length, 1);
  });

  test('stale cart cannot oversell stock after another checkout', () async {
    final staleItem = await seedItem(stock: 10);

    await db.checkout(
      invoiceId: 'invoice-first',
      invoiceNumber: 'INV-FIRST',
      cart: [CartLine(id: 'line-first', item: staleItem, quantity: 7)],
      discountMinor: 0,
      paymentMethod: 'cash',
    );

    await expectLater(
      db.checkout(
        invoiceId: 'invoice-second',
        invoiceNumber: 'INV-SECOND',
        cart: [CartLine(id: 'line-second', item: staleItem, quantity: 7)],
        discountMinor: 0,
        paymentMethod: 'cash',
      ),
      throwsStateError,
    );

    expect((await db.select(db.items).getSingle()).stockQuantity, 3);
    expect((await db.select(db.invoices).get()).length, 1);
  });

  test('concurrent checkouts cannot sell the same final unit twice', () async {
    final item = await seedItem(stock: 1);

    Future<bool> attempt(String suffix) async {
      try {
        await db.checkout(
          invoiceId: 'invoice-$suffix',
          invoiceNumber: 'INV-$suffix',
          cart: [CartLine(id: 'line-$suffix', item: item, quantity: 1)],
          discountMinor: 0,
          paymentMethod: 'cash',
        );
        return true;
      } on StateError {
        return false;
      }
    }

    final outcomes = await Future.wait([attempt('a'), attempt('b')]);
    expect(outcomes.where((success) => success), hasLength(1));
    expect((await db.select(db.items).getSingle()).stockQuantity, 0);
    expect((await db.select(db.invoices).get()).length, 1);
  });
}
