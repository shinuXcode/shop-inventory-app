import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  @override String get primaryKey => 'id';
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
  @override String get primaryKey => 'id';
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
  @override String get primaryKey => 'id';
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
  @override String get primaryKey => 'id';
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

@DriftDatabase(tables: [Items, Customers, Invoices, InvoiceItems, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting() : super(NativeDatabase.memory());
  @override int get schemaVersion => 1;

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
    if (paymentMethod.trim().isEmpty) throw ArgumentError('Payment method is required.');

    final calculator = const BillingCalculator();
    final totals = calculator.calculate(
      lines: cart.map((line) => BillingLine(
        unitPriceMinor: line.item.priceMinor,
        quantity: line.quantity,
        taxRateBps: (line.item.taxRate * 100).round(),
      )).toList(),
      discountMinor: discountMinor,
    );

    await transaction(() async {
      final now = DateTime.now();
      for (final line in cart) {
        if (line.quantity <= 0) throw ArgumentError('Quantity must be positive.');
        if (line.quantity > line.item.stockQuantity) {
          throw StateError('Insufficient stock for ' + line.item.name);
        }
      }

      await into(invoices).insert(InvoicesCompanion.insert(
        id: invoiceId, invoiceNumber: invoiceNumber, customerId: Value(customerId),
        subtotalMinor: totals.subtotalMinor, discountMinor: Value(totals.discountMinor),
        taxMinor: Value(totals.taxMinor), totalMinor: totals.totalMinor,
        paymentMethod: paymentMethod, createdAt: now, updatedAt: now));

      for (final line in cart) {
        final lineSubtotal = line.item.priceMinor * line.quantity;
        final lineDiscount = totals.subtotalMinor == 0 ? 0 :
            ((lineSubtotal * discountMinor) / totals.subtotalMinor).round();
        final lineTax = calculator.taxFor(
          lineSubtotal - lineDiscount,
          (line.item.taxRate * 100).round(),
        );
        await into(invoiceItems).insert(InvoiceItemsCompanion.insert(
          id: line.id, invoiceId: invoiceId, itemId: line.item.id,
          itemNameSnapshot: line.item.name, skuSnapshot: Value(line.item.sku),
          quantity: line.quantity, unitPriceMinor: line.item.priceMinor,
          taxRate: line.item.taxRate, taxMinor: lineTax,
          lineTotalMinor: lineSubtotal - lineDiscount + lineTax));

        await (update(items)..where((t) => t.id.equals(line.item.id))).write(
          ItemsCompanion(
            stockQuantity: Value(line.item.stockQuantity - line.quantity),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      }

      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'invoice', entityId: invoiceId, operation: 'upsert', createdAt: now));
    });
  }

  Future<List<Invoice>> recentInvoices({int limit = 30}) => (select(invoices)
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])..limit(limit)).get();
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
