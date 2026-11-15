import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../billing/billing_calculator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
part 'app_database.g.dart';

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get priceMinor => integer()();
  IntColumn get costMinor => integer().withDefault(const Constant(0))();
  RealColumn get taxRate => real().withDefault(const Constant(0))();
  IntColumn get stockQuantity => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  TextColumn get category => text().nullable()();
  TextColumn get barcode => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get customerId => text().nullable()();
  IntColumn get subtotalMinor => integer()();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  IntColumn get taxMinor => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer()();
  TextColumn get paymentMethod => text()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemNameSnapshot => text()();
  TextColumn get skuSnapshot => text().nullable()();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceMinor => integer()();
  RealColumn get taxRate => real()();
  IntColumn get taxMinor => integer()();
  IntColumn get lineTotalMinor => integer()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get gstin => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseNumber => text()();
  TextColumn get supplierId => text()();
  IntColumn get subtotalMinor => integer()();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  IntColumn get taxMinor => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer()();
  IntColumn get paidMinor => integer().withDefault(const Constant(0))();
  TextColumn get paymentStatus => text().withDefault(const Constant('unpaid'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class PurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemNameSnapshot => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitCostMinor => integer()();
  RealColumn get taxRate => real()();
  IntColumn get taxMinor => integer()();
  IntColumn get lineTotalMinor => integer()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get category => text()();
  TextColumn get description => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get incurredAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class StockAdjustments extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  IntColumn get quantityDelta => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class StockBatches extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get purchaseItemId => text().nullable()();
  IntColumn get quantity => integer()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class TopSellingItem {
  const TopSellingItem({
    required this.name,
    required this.quantity,
    required this.totalMinor,
  });

  final String name;
  final double quantity;
  final int totalMinor;
}

@DriftDatabase(tables: [Items, Customers, Invoices, InvoiceItems, SyncQueue, Suppliers, Purchases, PurchaseItems, Expenses, StockAdjustments, StockBatches])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting() : super(NativeDatabase.memory());
  @override int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(suppliers);
            await m.createTable(purchases);
            await m.createTable(purchaseItems);
            await m.createTable(expenses);
            await m.createTable(stockAdjustments);
            await m.createTable(stockBatches);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Stream<List<Item>> watchActiveItems() => (select(items)
    ..where((t) => t.isActive.equals(true))
    ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<List<Item>> searchItems(String value) {
    final q = '%' + value.trim() + '%';
    return (select(items)..where((t) =>
      t.isActive.equals(true) &
      (t.name.like(q) | t.sku.like(q) | t.barcode.like(q))
    )).get();
  }


  Future<Item?> findItemConflict({
    required String sku,
    required String barcode,
    String? excludingId,
  }) async {
    final normalizedSku = sku.trim().toLowerCase();
    final normalizedBarcode = barcode.trim();
    if (normalizedSku.isEmpty && normalizedBarcode.isEmpty) return null;
    final rows = await select(items).get();
    for (final item in rows) {
      if (item.id == excludingId) continue;
      if (normalizedSku.isNotEmpty &&
          (item.sku ?? '').trim().toLowerCase() == normalizedSku) {
        return item;
      }
      if (normalizedBarcode.isNotEmpty &&
          (item.barcode ?? '').trim() == normalizedBarcode) {
        return item;
      }
    }
    return null;
  }

  Future<void> saveItem(ItemsCompanion item) async {
    await into(items).insertOnConflictUpdate(item);
    await into(syncQueue).insert(SyncQueueCompanion.insert(
      entityType: 'item', entityId: item.id.value, operation: 'upsert', createdAt: DateTime.now()));
  }

  Future<List<Customer>> getCustomers({String query = ''}) {
    final q = '%' + query.trim() + '%';
    final stmt = select(customers)..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (query.trim().isNotEmpty) {
      stmt.where((t) => t.name.like(q) | t.phone.like(q) | t.email.like(q));
    }
    return stmt.get();
  }

  Future<Customer?> customerById(String id) =>
      (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Invoice?> invoiceById(String id) =>
      (select(invoices)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<InvoiceItem>> invoiceItemsFor(String invoiceId) =>
      (select(invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();

  Future<List<Invoice>> invoicesForCustomer(String customerId) => (select(invoices)
    ..where((t) => t.customerId.equals(customerId))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<int> creditOutstandingMinor() async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(total_minor), 0) AS amount '
      'FROM invoices WHERE payment_method = ? AND status != ?',
      variables: [
        const Variable<String>('credit'),
        const Variable<String>('cancelled'),
      ],
      readsFrom: {invoices},
    ).getSingle();
    return row.read<int>('amount');
  }

  Future<List<TopSellingItem>> topSellingItems({int limit = 5}) async {
    final rows = await customSelect(
      'SELECT item_name_snapshot AS name, '
      'SUM(quantity) AS quantity, '
      'SUM(line_total_minor) AS total_minor '
      'FROM invoice_items '
      'GROUP BY item_name_snapshot '
      'ORDER BY quantity DESC '
      'LIMIT ?',
      variables: [Variable<int>(limit)],
      readsFrom: {invoiceItems},
    ).get();
    return rows
        .map((row) => TopSellingItem(
              name: row.read<String>('name'),
              quantity: row.read<num>('quantity').toDouble(),
              totalMinor: row.read<int>('total_minor'),
            ))
        .toList();
  }

  Future<int> todaySalesMinor() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await (select(invoices)..where((t) => t.createdAt.isBiggerOrEqualValue(start))).get();
    return rows.fold<int>(0, (sum, row) => sum + row.totalMinor);
  }

  Future<int> todayInvoiceCount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await (select(invoices)..where((t) => t.createdAt.isBiggerOrEqualValue(start))).get();
    return rows.length;
  }

  Future<int> lowStockCount() => (select(items)..where((t) =>
      t.isActive.equals(true) & t.stockQuantity.isSmallerOrEqual(t.lowStockThreshold))).get().then((r) => r.length);

  Future<void> saveCustomer(CustomersCompanion customer) async {
    await into(customers).insertOnConflictUpdate(customer);
    await into(syncQueue).insert(SyncQueueCompanion.insert(
      entityType: 'customer', entityId: customer.id.value, operation: 'upsert', createdAt: DateTime.now()));
  }

  Future<void> checkout({
    required String invoiceId,
    required String invoiceNumber,
    required List<CartLine> cart,
    String? customerId,
    required int discountMinor,
    required String paymentMethod,
  }) async {
    if (cart.isEmpty) throw ArgumentError('Cart is empty.');
    if (paymentMethod.trim().isEmpty) {
      throw ArgumentError('Payment method is required.');
    }
    if (cart.any((line) => line.quantity <= 0)) {
      throw ArgumentError('Every cart quantity must be positive.');
    }

    // Aggregate repeated product lines before checking or decrementing stock.
    final quantities = <String, int>{};
    for (final line in cart) {
      quantities.update(
        line.item.id,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    await transaction(() async {
      final now = DateTime.now();
      final currentItems = <String, Item>{};
      for (final entry in quantities.entries) {
        final current = await (select(items)
              ..where((table) => table.id.equals(entry.key)))
            .getSingleOrNull();
        if (current == null || !current.isActive) {
          throw StateError('A product in this cart is no longer available.');
        }
        if (entry.value > current.stockQuantity) {
          throw StateError('Insufficient stock for ${current.name}. Available: ${current.stockQuantity}.');
        }
        currentItems[entry.key] = current;
      }

      final effectiveLines = cart.map((line) {
        final current = currentItems[line.item.id]!;
        return BillingLine(
          unitPriceMinor: current.priceMinor,
          quantity: line.quantity,
          taxRateBps: (current.taxRate * 100).round(),
        );
      }).toList();
      final totals = const BillingCalculator().calculate(
        lines: effectiveLines,
        discountMinor: discountMinor,
      );

      await into(invoices).insert(InvoicesCompanion.insert(
        id: invoiceId,
        invoiceNumber: invoiceNumber,
        customerId: Value(customerId),
        subtotalMinor: totals.subtotalMinor,
        discountMinor: Value(totals.discountMinor),
        taxMinor: Value(totals.taxMinor),
        totalMinor: totals.totalMinor,
        paymentMethod: paymentMethod.trim().toLowerCase(),
        createdAt: now,
        updatedAt: now,
      ));

      var remainingDiscount = totals.discountMinor;
      var remainingSubtotal = totals.subtotalMinor;
      for (var index = 0; index < cart.length; index++) {
        final line = cart[index];
        final current = currentItems[line.item.id]!;
        final lineSubtotal = current.priceMinor * line.quantity;
        final lineDiscount = index == cart.length - 1
            ? remainingDiscount
            : remainingSubtotal == 0
                ? 0
                : (lineSubtotal * remainingDiscount + remainingSubtotal ~/ 2) ~/
                    remainingSubtotal;
        remainingDiscount -= lineDiscount;
        remainingSubtotal -= lineSubtotal;

        final lineTax = const BillingCalculator().taxFor(
          lineSubtotal - lineDiscount,
          (current.taxRate * 100).round(),
        );
        await into(invoiceItems).insert(InvoiceItemsCompanion.insert(
          id: line.id,
          invoiceId: invoiceId,
          itemId: current.id,
          itemNameSnapshot: current.name,
          skuSnapshot: Value(current.sku),
          quantity: line.quantity,
          unitPriceMinor: current.priceMinor,
          taxRate: current.taxRate,
          taxMinor: lineTax,
          lineTotalMinor: lineSubtotal - lineDiscount + lineTax,
        ));
      }

      // Conditional SQL updates prevent stale carts or simultaneous checkouts
      // from selling stock that is no longer available.
      for (final entry in quantities.entries) {
        final changed = await customUpdate(
          'UPDATE items '
          'SET stock_quantity = stock_quantity - ?, updated_at = ?, sync_status = ? '
          'WHERE id = ? AND is_active = 1 AND stock_quantity >= ?',
          variables: [
            Variable<int>(entry.value),
            Variable<DateTime>(now),
            const Variable<String>('pending'),
            Variable<String>(entry.key),
            Variable<int>(entry.value),
          ],
          updates: {items},
        );
        if (changed != 1) {
          throw StateError('Stock changed during checkout. Refresh the cart and try again.');
        }
      }

      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'invoice',
        entityId: invoiceId,
        operation: 'upsert',
        createdAt: now,
      ));
      for (final itemId in quantities.keys) {
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'item',
          entityId: itemId,
          operation: 'upsert',
          createdAt: now,
        ));
      }
    });
  }

  Future<int> pendingSyncCount() => select(syncQueue).get().then((r) => r.length);

  Future<List<SyncQueueData>> pendingSyncQueue({int limit = 50}) => (select(syncQueue)
    ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
    ..limit(limit)).get();

  Future<void> deleteSyncQueueEntry(int id) =>
      (delete(syncQueue)..where((t) => t.id.equals(id))).go();

  Future<void> failSyncQueueEntry(int id, int attempts, String error) =>
      (update(syncQueue)..where((t) => t.id.equals(id))).write(
        SyncQueueCompanion(
          attempts: Value(attempts + 1),
          lastError: Value(error),
        ),
      );

  Future<List<Item>> activeItemsForExport() => (select(items)
    ..where((t) => t.isActive.equals(true))
    ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();

  Future<CustomerStats> customerStats(String customerId) async {
    final rows = await invoicesForCustomer(customerId);
    var totalMinor = 0;
    var creditMinor = 0;
    for (final row in rows) {
      totalMinor += row.totalMinor;
      if (row.paymentMethod == 'credit') creditMinor += row.totalMinor;
    }
    return CustomerStats(
      invoiceCount: rows.length,
      totalMinor: totalMinor,
      creditMinor: creditMinor,
    );
  }

  Future<Map<String, dynamic>> exportSnapshot() async {
    final itemRows = await select(items).get();
    final customerRows = await select(customers).get();
    final invoiceRows = await select(invoices).get();
    final invoiceItemRows = await select(invoiceItems).get();
    return {
      'format': 'sbill-backup-v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'items': itemRows.map((x) => {
        'id': x.id, 'sku': x.sku, 'name': x.name, 'description': x.description,
        'priceMinor': x.priceMinor, 'costMinor': x.costMinor, 'taxRate': x.taxRate,
        'stockQuantity': x.stockQuantity, 'lowStockThreshold': x.lowStockThreshold,
        'category': x.category, 'barcode': x.barcode, 'isActive': x.isActive,
        'createdAt': x.createdAt.toIso8601String(), 'updatedAt': x.updatedAt.toIso8601String(),
      }).toList(),
      'customers': customerRows.map((x) => {
        'id': x.id, 'name': x.name, 'phone': x.phone, 'email': x.email,
        'address': x.address, 'notes': x.notes,
        'createdAt': x.createdAt.toIso8601String(), 'updatedAt': x.updatedAt.toIso8601String(),
      }).toList(),
      'invoices': invoiceRows.map((x) => {
        'id': x.id, 'invoiceNumber': x.invoiceNumber, 'customerId': x.customerId,
        'subtotalMinor': x.subtotalMinor, 'discountMinor': x.discountMinor,
        'taxMinor': x.taxMinor, 'totalMinor': x.totalMinor, 'paymentMethod': x.paymentMethod,
        'status': x.status, 'notes': x.notes,
        'createdAt': x.createdAt.toIso8601String(), 'updatedAt': x.updatedAt.toIso8601String(),
      }).toList(),
      'invoiceItems': invoiceItemRows.map((x) => {
        'id': x.id, 'invoiceId': x.invoiceId, 'itemId': x.itemId,
        'itemNameSnapshot': x.itemNameSnapshot, 'skuSnapshot': x.skuSnapshot,
        'quantity': x.quantity, 'unitPriceMinor': x.unitPriceMinor,
        'taxRate': x.taxRate, 'taxMinor': x.taxMinor, 'lineTotalMinor': x.lineTotalMinor,
      }).toList(),
    };
  }

  Future<int> importProductRows(List<Map<String, String>> rows) async {
    final existing = await select(items).get();
    final bySku = <String, Item>{};
    final byBarcode = <String, Item>{};
    final byName = <String, Item>{};
    for (final item in existing) {
      if ((item.sku ?? '').isNotEmpty) bySku[item.sku!.trim().toLowerCase()] = item;
      if ((item.barcode ?? '').isNotEmpty) byBarcode[item.barcode!.trim()] = item;
      byName[item.name.trim().toLowerCase()] = item;
    }

    var imported = 0;
    await transaction(() async {
      for (final row in rows) {
        final name = _rowValue(row, const ['name', 'product', 'product_name', 'item_name']).trim();
        if (name.isEmpty) continue;
        final sku = _rowValue(row, const ['sku', 'code']).trim();
        final barcode = _rowValue(row, const ['barcode', 'bar_code']).trim();
        final existingItem = (sku.isNotEmpty ? bySku[sku.toLowerCase()] : null) ??
            (barcode.isNotEmpty ? byBarcode[barcode] : null) ??
            byName[name.toLowerCase()];
        final now = DateTime.now();
        final id = existingItem?.id ?? const Uuid().v4();
        final companion = ItemsCompanion(
          id: Value(id),
          sku: Value(sku.isEmpty ? null : sku),
          name: Value(name),
          barcode: Value(barcode.isEmpty ? null : barcode),
          category: Value(_rowValue(row, const ['category', 'group']).trim().isEmpty
              ? null : _rowValue(row, const ['category', 'group']).trim()),
          priceMinor: Value(_rowMoneyMinor(row, const ['price', 'price_rupees', 'selling_price', 'rate'])),
          taxRate: Value(_rowDouble(row, const ['tax', 'tax_rate', 'gst'])),
          stockQuantity: Value(_rowInt(row, const ['stock', 'quantity', 'stock_quantity'])),
          lowStockThreshold: Value(_rowInt(row, const ['low_stock_threshold', 'reorder_level'], fallback: 5)),
          createdAt: Value(existingItem?.createdAt ?? now),
          updatedAt: Value(now),
          isActive: const Value(true),
          syncStatus: const Value('pending'),
        );
        if (existingItem != null) continue;
        await into(items).insert(
          ItemsCompanion.insert(
            id: id,
            sku: companion.sku,
            name: name,
            priceMinor: companion.priceMinor.value,
            taxRate: companion.taxRate,
            stockQuantity: companion.stockQuantity,
            lowStockThreshold: companion.lowStockThreshold,
            category: companion.category,
            barcode: companion.barcode,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'item', entityId: id, operation: 'upsert', createdAt: now,
        ));
        final saved = (await (select(items)..where((t) => t.id.equals(id))).getSingle());
        if ((saved.sku ?? '').isNotEmpty) bySku[saved.sku!.trim().toLowerCase()] = saved;
        if ((saved.barcode ?? '').isNotEmpty) byBarcode[saved.barcode!.trim()] = saved;
        byName[saved.name.trim().toLowerCase()] = saved;
        imported++;
      }
    });
    return imported;
  }

  Future<int> importCustomerRows(List<Map<String, String>> rows) async {
    final existing = await select(customers).get();
    final byPhone = <String, Customer>{};
    final byEmail = <String, Customer>{};
    final byName = <String, Customer>{};
    for (final customer in existing) {
      if ((customer.phone ?? '').isNotEmpty) byPhone[customer.phone!.trim()] = customer;
      if ((customer.email ?? '').isNotEmpty) byEmail[customer.email!.trim().toLowerCase()] = customer;
      byName[customer.name.trim().toLowerCase()] = customer;
    }

    var imported = 0;
    await transaction(() async {
      for (final row in rows) {
        final name = _rowValue(row, const ['name', 'customer', 'customer_name']).trim();
        if (name.isEmpty) continue;
        final phone = _rowValue(row, const ['phone', 'mobile', 'contact']).trim();
        final email = _rowValue(row, const ['email', 'email_address']).trim();
        final existingCustomer = (phone.isNotEmpty ? byPhone[phone] : null) ??
            (email.isNotEmpty ? byEmail[email.toLowerCase()] : null) ??
            byName[name.toLowerCase()];
        final now = DateTime.now();
        final id = existingCustomer?.id ?? const Uuid().v4();
        final companion = CustomersCompanion(
          id: Value(id),
          name: Value(name),
          phone: Value(phone.isEmpty ? null : phone),
          email: Value(email.isEmpty ? null : email),
          address: Value(_rowValue(row, const ['address', 'location']).trim().isEmpty
              ? null : _rowValue(row, const ['address', 'location']).trim()),
          notes: Value(_rowValue(row, const ['notes', 'note']).trim().isEmpty
              ? null : _rowValue(row, const ['notes', 'note']).trim()),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        );
        if (existingCustomer != null) continue;
        await into(customers).insert(
          CustomersCompanion.insert(
            id: id,
            name: name,
            phone: companion.phone,
            email: companion.email,
            address: companion.address,
            notes: companion.notes,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'customer', entityId: id, operation: 'upsert', createdAt: now,
        ));
        final saved = await (select(customers)..where((t) => t.id.equals(id))).getSingle();
        if ((saved.phone ?? '').isNotEmpty) byPhone[saved.phone!.trim()] = saved;
        if ((saved.email ?? '').isNotEmpty) byEmail[saved.email!.trim().toLowerCase()] = saved;
        byName[saved.name.trim().toLowerCase()] = saved;
        imported++;
      }
    });
    return imported;
  }

  Future<int> importSnapshot(Map<String, dynamic> snapshot) async {
    if (snapshot['format'] != 'sbill-backup-v1') {
      throw ArgumentError('Unsupported SBILL backup format.');
    }
    final itemRows = (snapshot['items'] as List?)?.whereType<Map>().toList() ?? const [];
    final customerRows = (snapshot['customers'] as List?)?.whereType<Map>().toList() ?? const [];
    final invoiceRows = (snapshot['invoices'] as List?)?.whereType<Map>().toList() ?? const [];
    final invoiceItemRows = (snapshot['invoiceItems'] as List?)?.whereType<Map>().toList() ?? const [];

    var imported = 0;
    final importedItemIds = <String>[];
    final importedCustomerIds = <String>[];
    final importedInvoiceIds = <String>[];
    final now = DateTime.now();

    await transaction(() async {
      final existingItemIds = (await select(items).get()).map((row) => row.id).toSet();
      final existingCustomerIds = (await select(customers).get()).map((row) => row.id).toSet();
      final existingInvoiceIds = (await select(invoices).get()).map((row) => row.id).toSet();
      final existingInvoiceItemIds = (await select(invoiceItems).get()).map((row) => row.id).toSet();

      for (final row in itemRows) {
        final id = row['id'].toString();
        if (existingItemIds.contains(id)) continue;
        final createdNow = _rowDate(row['updatedAt']) ?? now;
        await into(items).insert(ItemsCompanion(
          id: Value(id),
          sku: Value(_nullable(row['sku'])),
          name: Value(row['name'].toString()),
          description: Value(_nullable(row['description'])),
          priceMinor: Value(_number(row['priceMinor'])),
          costMinor: Value(_number(row['costMinor'])),
          taxRate: Value(_decimal(row['taxRate'])),
          stockQuantity: Value(_number(row['stockQuantity'])),
          lowStockThreshold: Value(_number(row['lowStockThreshold'], 5)),
          category: Value(_nullable(row['category'])),
          barcode: Value(_nullable(row['barcode'])),
          isActive: Value(row['isActive'] != false),
          createdAt: Value(_rowDate(row['createdAt']) ?? createdNow),
          updatedAt: Value(createdNow),
          syncStatus: const Value('pending'),
        ));
        importedItemIds.add(id);
        imported++;
      }
      for (final row in customerRows) {
        final id = row['id'].toString();
        if (existingCustomerIds.contains(id)) continue;
        final createdNow = _rowDate(row['updatedAt']) ?? now;
        await into(customers).insert(CustomersCompanion(
          id: Value(id),
          name: Value(row['name'].toString()),
          phone: Value(_nullable(row['phone'])),
          email: Value(_nullable(row['email'])),
          address: Value(_nullable(row['address'])),
          notes: Value(_nullable(row['notes'])),
          createdAt: Value(_rowDate(row['createdAt']) ?? createdNow),
          updatedAt: Value(createdNow),
          syncStatus: const Value('pending'),
        ));
        importedCustomerIds.add(id);
        imported++;
      }
      for (final row in invoiceRows) {
        final id = row['id'].toString();
        if (existingInvoiceIds.contains(id)) continue;
        final createdNow = _rowDate(row['updatedAt']) ?? now;
        await into(invoices).insert(InvoicesCompanion(
          id: Value(id),
          invoiceNumber: Value(row['invoiceNumber'].toString()),
          customerId: Value(_nullable(row['customerId'])),
          subtotalMinor: Value(_number(row['subtotalMinor'])),
          discountMinor: Value(_number(row['discountMinor'])),
          taxMinor: Value(_number(row['taxMinor'])),
          totalMinor: Value(_number(row['totalMinor'])),
          paymentMethod: Value(row['paymentMethod'].toString()),
          status: Value(row['status']?.toString() ?? 'completed'),
          notes: Value(_nullable(row['notes'])),
          createdAt: Value(_rowDate(row['createdAt']) ?? createdNow),
          updatedAt: Value(createdNow),
          syncStatus: const Value('pending'),
        ));
        importedInvoiceIds.add(id);
        imported++;
      }
      for (final row in invoiceItemRows) {
        final id = row['id'].toString();
        final invoiceId = row['invoiceId'].toString();
        if (existingInvoiceItemIds.contains(id) || !importedInvoiceIds.contains(invoiceId)) continue;
        await into(invoiceItems).insert(InvoiceItemsCompanion(
          id: Value(id),
          invoiceId: Value(invoiceId),
          itemId: Value(row['itemId'].toString()),
          itemNameSnapshot: Value(row['itemNameSnapshot'].toString()),
          skuSnapshot: Value(_nullable(row['skuSnapshot'])),
          quantity: Value(_number(row['quantity'])),
          unitPriceMinor: Value(_number(row['unitPriceMinor'])),
          taxRate: Value(_decimal(row['taxRate'])),
          taxMinor: Value(_number(row['taxMinor'])),
          lineTotalMinor: Value(_number(row['lineTotalMinor'])),
        ));
        imported++;
      }
      for (final id in importedItemIds) {
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'item', entityId: id, operation: 'upsert', createdAt: DateTime.now(),
        ));
      }
      for (final id in importedCustomerIds) {
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'customer', entityId: id, operation: 'upsert', createdAt: DateTime.now(),
        ));
      }
      for (final id in importedInvoiceIds) {
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'invoice', entityId: id, operation: 'upsert', createdAt: DateTime.now(),
        ));
      }
    });
    return imported;
  }

  static String _rowValue(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static int _rowMoneyMinor(
    Map<String, String> row,
    List<String> keys,
  ) => (_rowDouble(row, keys) * 100).round();

  static double _rowDouble(Map<String, String> row, List<String> keys) {
    final value = _rowValue(row, keys).replaceAll(RegExp(r'[^0-9.\-]'), '');
    return double.tryParse(value) ?? 0;
  }

  static int _rowInt(
    Map<String, String> row,
    List<String> keys, {
    int fallback = 0,
  }) {
    final value = _rowValue(row, keys);
    return int.tryParse(value) ?? fallback;
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  static int _number(Object? value, [int fallback = 0]) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  static double _decimal(Object? value, [double fallback = 0]) =>
      double.tryParse(value?.toString() ?? '') ?? fallback;

  static DateTime? _rowDate(Object? value) {
    final text = value?.toString();
    return text == null ? null : DateTime.tryParse(text);
  }

  Future<void> clearLocalData() async {
    await transaction(() async {
      await delete(invoiceItems).go();
      await delete(invoices).go();
      await delete(customers).go();
      await delete(items).go();
      await delete(syncQueue).go();
    });
  }

  Future<List<Invoice>> recentInvoices({int limit = 30}) => (select(invoices)
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ..limit(limit))
    .get();
}

class CartLine {
  CartLine({required this.id, required this.item, this.quantity = 1});
  final String id;
  final Item item;
  final int quantity;
  CartLine copyWith({int? quantity}) =>
      CartLine(id: id, item: item, quantity: quantity ?? this.quantity);
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationSupportDirectory();
  return NativeDatabase.createInBackground(File(p.join(dir.path, 'sbill.sqlite')));
});


class CustomerStats {
  const CustomerStats({
    required this.invoiceCount,
    required this.totalMinor,
    required this.creditMinor,
  });

  final int invoiceCount;
  final int totalMinor;
  final int creditMinor;
}
