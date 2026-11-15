import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sbill/core/database/app_database.dart';

void main() {
  test('sync queue persists event type, operation and retry diagnostics', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final now = DateTime.now();

    await db.saveItem(ItemsCompanion.insert(
      id: 'sync-item',
      name: 'Sync Item',
      priceMinor: 1000,
      stockQuantity: const Value(2),
      createdAt: now,
      updatedAt: now,
    ));

    final queue = await db.pendingSyncQueue();
    expect(queue, hasLength(1));
    expect(queue.single.entityType, 'item');
    expect(queue.single.entityId, 'sync-item');
    expect(queue.single.operation, 'upsert');

    await db.failSyncQueueEntry(queue.single.id, queue.single.attempts, 'temporary network error');
    final retried = await db.pendingSyncQueue();
    expect(retried.single.attempts, 1);
    expect(retried.single.lastError, 'temporary network error');

    await db.deleteSyncQueueEntry(retried.single.id);
    expect(await db.pendingSyncCount(), 0);
  });

  test('purchase stock changes enqueue item upserts without requiring cloud', () async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final now = DateTime.now();

    await db.saveSupplier(SuppliersCompanion.insert(
      id: 'supplier-sync',
      name: 'Local Supplier',
      createdAt: now,
      updatedAt: now,
    ));
    await db.saveItem(ItemsCompanion.insert(
      id: 'item-sync',
      name: 'Local Product',
      priceMinor: 5000,
      createdAt: now,
      updatedAt: now,
    ));
    await db.recordPurchase(
      purchaseId: 'purchase-sync',
      purchaseNumber: 'PUR-SYNC',
      supplierId: 'supplier-sync',
      lines: const [
        PurchaseLine(
          id: 'purchase-line-sync',
          itemId: 'item-sync',
          quantity: 4,
          unitCostMinor: 2000,
          taxRateBps: 0,
        ),
      ],
      discountMinor: 0,
      paidMinor: 0,
    );

    final events = await db.pendingSyncQueue();
    expect(events.where((event) => event.entityType == 'item'), hasLength(1));
    expect(await db.pendingSyncCount(), 1);
    expect((await db.select(db.items).getSingle()).stockQuantity, 4);
  });
}
