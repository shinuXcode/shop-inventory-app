import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../billing/billing_calculator.dart';
import '../billing/indian_gst.dart';
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
  TextColumn get hsnSac => text().nullable()();
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
  IntColumn get cgstMinor => integer().withDefault(const Constant(0))();
  IntColumn get sgstMinor => integer().withDefault(const Constant(0))();
  IntColumn get igstMinor => integer().withDefault(const Constant(0))();
  TextColumn get gstSupplyType => text().withDefault(const Constant('intraState'))();
  IntColumn get totalMinor => integer()();
  IntColumn get paidMinor => integer().withDefault(const Constant(0))();
  TextColumn get paymentStatus => text().withDefault(const Constant('paid'))();
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
  TextColumn get hsnSacSnapshot => text().nullable()();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceMinor => integer()();
  IntColumn get unitCostMinor => integer().withDefault(const Constant(0))();
  IntColumn get lineDiscountMinor => integer().withDefault(const Constant(0))();
  IntColumn get cgstMinor => integer().withDefault(const Constant(0))();
  IntColumn get sgstMinor => integer().withDefault(const Constant(0))();
  IntColumn get igstMinor => integer().withDefault(const Constant(0))();
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

@DataClassName('StockBatchRow')
class StockBatches extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get purchaseItemId => text().nullable()();
  IntColumn get quantity => integer()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}


class CustomerPayments extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get invoiceId => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get paymentMethod => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get receivedAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class SupplierPayments extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text()();
  TextColumn get purchaseId => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get paymentMethod => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paidAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class SalesReturns extends Table {
  TextColumn get id => text()();
  TextColumn get returnNumber => text()();
  TextColumn get invoiceId => text()();
  TextColumn get customerId => text().nullable()();
  IntColumn get subtotalMinor => integer()();
  IntColumn get taxMinor => integer()();
  IntColumn get totalMinor => integer()();
  TextColumn get refundMethod => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column<Object>> get primaryKey => {id};
}

class SalesReturnItems extends Table {
  TextColumn get id => text()();
  TextColumn get returnId => text()();
  TextColumn get invoiceItemId => text()();
  TextColumn get itemId => text()();
  TextColumn get itemNameSnapshot => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitPriceMinor => integer()();
  RealColumn get taxRate => real()();
  IntColumn get taxMinor => integer()();
  IntColumn get lineTotalMinor => integer()();
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

@DriftDatabase(tables: [Items, Customers, Invoices, InvoiceItems, SyncQueue, Suppliers, Purchases, PurchaseItems, Expenses, StockAdjustments, StockBatches, CustomerPayments, SupplierPayments, SalesReturns, SalesReturnItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting() : super(NativeDatabase.memory());
  @override int get schemaVersion => 6;

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
          if (from < 3) {
            await m.addColumn(invoiceItems, invoiceItems.unitCostMinor);
            await m.addColumn(invoiceItems, invoiceItems.lineDiscountMinor);
          }
          if (from < 4) {
            await m.addColumn(invoices, invoices.cgstMinor);
            await m.addColumn(invoices, invoices.sgstMinor);
            await m.addColumn(invoices, invoices.igstMinor);
            await m.addColumn(invoices, invoices.gstSupplyType);
            await customStatement("UPDATE invoices SET gst_supply_type = 'unknown'");
            await m.addColumn(invoiceItems, invoiceItems.cgstMinor);
            await m.addColumn(invoiceItems, invoiceItems.sgstMinor);
            await m.addColumn(invoiceItems, invoiceItems.igstMinor);
          }
          if (from < 5) {
            await m.addColumn(items, items.hsnSac);
            await m.addColumn(invoiceItems, invoiceItems.hsnSacSnapshot);
          }
          if (from < 6) {
            await m.addColumn(invoices, invoices.paidMinor);
            await m.addColumn(invoices, invoices.paymentStatus);
            await customStatement(
              "UPDATE invoices SET paid_minor = CASE WHEN LOWER(payment_method) = 'credit' THEN 0 ELSE total_minor END, "
              "payment_status = CASE WHEN LOWER(payment_method) = 'credit' THEN 'unpaid' ELSE 'paid' END",
            );
            await m.createTable(customerPayments);
            await m.createTable(supplierPayments);
            await m.createTable(salesReturns);
            await m.createTable(salesReturnItems);
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
      'SELECT COALESCE(SUM(MAX(i.total_minor - '
      'CASE WHEN i.payment_status = \'paid\' AND i.paid_minor = 0 THEN i.total_minor ELSE i.paid_minor END - '
      'COALESCE((SELECT SUM(r.total_minor) FROM sales_returns r WHERE r.invoice_id = i.id), 0), 0)), 0) AS amount '
      'FROM invoices i WHERE i.status != ?',
      variables: [
        const Variable<String>('cancelled'),
      ],
      readsFrom: {invoices, salesReturns},
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

  Future<void> saveSupplier(SuppliersCompanion supplier) async {
    await into(suppliers).insertOnConflictUpdate(supplier);
    await into(syncQueue).insert(SyncQueueCompanion.insert(
      entityType: 'supplier',
      entityId: supplier.id.value,
      operation: 'upsert',
      createdAt: DateTime.now(),
    ));
  }

  Future<List<CustomerPayment>> customerPaymentsFor(String customerId) =>
      (select(customerPayments)
            ..where((t) => t.customerId.equals(customerId))
            ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
          .get();

  Future<List<SupplierPayment>> supplierPaymentsFor(String supplierId) =>
      (select(supplierPayments)
            ..where((t) => t.supplierId.equals(supplierId))
            ..orderBy([(t) => OrderingTerm.desc(t.paidAt)]))
          .get();

  Future<List<SalesReturn>> salesReturnsForInvoice(String invoiceId) =>
      (select(salesReturns)
            ..where((t) => t.invoiceId.equals(invoiceId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  Future<int> recordCustomerPayment({
    required String id,
    required String invoiceId,
    required int amountMinor,
    required String paymentMethod,
    String? reference,
    String? notes,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    final method = paymentMethod.trim().toLowerCase();
    if (method.isEmpty || method == 'credit') {
      throw ArgumentError('Choose a valid receipt method.');
    }
    return transaction(() async {
      final invoice = await invoiceById(invoiceId);
      if (invoice == null || invoice.customerId == null) {
        throw StateError('The invoice does not belong to a saved customer.');
      }
      if (invoice.status == 'cancelled' || invoice.status == 'returned') {
        throw StateError('Payments cannot be recorded against a cancelled or returned invoice.');
      }
      final existingReturns = await (select(salesReturns)
            ..where((t) => t.invoiceId.equals(invoiceId)))
          .get();
      final returnedMinor = existingReturns.fold<int>(0, (sum, value) => sum + value.totalMinor);
      final outstanding = invoice.totalMinor - invoice.paidMinor - returnedMinor;
      if (amountMinor > outstanding) {
        throw ArgumentError('Receipt exceeds the remaining invoice balance.');
      }
      final now = DateTime.now();
      await into(customerPayments).insert(CustomerPaymentsCompanion.insert(
        id: id,
        customerId: invoice.customerId!,
        invoiceId: Value(invoiceId),
        amountMinor: amountMinor,
        paymentMethod: method,
        reference: Value(_nullable(reference)),
        notes: Value(_nullable(notes)),
        receivedAt: now,
      ));
      final paid = invoice.paidMinor + amountMinor;
      await (update(invoices)..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(
          paidMinor: Value(paid),
          paymentStatus: Value(
            paid + returnedMinor >= invoice.totalMinor
                ? 'paid'
                : paid > 0 || returnedMinor > 0
                    ? 'partial'
                    : 'unpaid',
          ),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ),
      );
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'customerPayment',
        entityId: id,
        operation: 'upsert',
        createdAt: now,
      ));
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'invoice',
        entityId: invoiceId,
        operation: 'upsert',
        createdAt: now,
      ));
      return outstanding - amountMinor;
    });
  }

  Future<int> recordSupplierPayment({
    required String id,
    required String purchaseId,
    required int amountMinor,
    required String paymentMethod,
    String? reference,
    String? notes,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    final method = paymentMethod.trim().toLowerCase();
    if (method.isEmpty) throw ArgumentError('Choose a valid payment method.');
    return transaction(() async {
      final purchase = await (select(purchases)
            ..where((t) => t.id.equals(purchaseId)))
          .getSingleOrNull();
      if (purchase == null || purchase.paymentStatus == 'cancelled') {
        throw StateError('The purchase is unavailable for payment.');
      }
      final outstanding = purchase.totalMinor - purchase.paidMinor;
      if (amountMinor > outstanding) {
        throw ArgumentError('Payment exceeds the remaining supplier balance.');
      }
      final supplier = await (select(suppliers)
            ..where((t) => t.id.equals(purchase.supplierId)))
          .getSingleOrNull();
      if (supplier == null) throw StateError('The supplier record is missing.');
      final now = DateTime.now();
      await into(supplierPayments).insert(SupplierPaymentsCompanion.insert(
        id: id,
        supplierId: purchase.supplierId,
        purchaseId: Value(purchaseId),
        amountMinor: amountMinor,
        paymentMethod: method,
        reference: Value(_nullable(reference)),
        notes: Value(_nullable(notes)),
        paidAt: now,
      ));
      final paid = purchase.paidMinor + amountMinor;
      final status = paid >= purchase.totalMinor ? 'paid' : 'partial';
      await (update(purchases)..where((t) => t.id.equals(purchaseId))).write(
        PurchasesCompanion(
          paidMinor: Value(paid),
          paymentStatus: Value(status),
        ),
      );
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'supplierPayment',
        entityId: id,
        operation: 'upsert',
        createdAt: now,
      ));
      return outstanding - amountMinor;
    });
  }

  Future<String> recordSalesReturn({
    required String id,
    required String returnNumber,
    required String invoiceId,
    required List<SalesReturnLine> lines,
    required String refundMethod,
    String? notes,
    bool restock = true,
  }) async {
    if (lines.isEmpty) throw ArgumentError('Select at least one item to return.');
    final method = refundMethod.trim().toLowerCase();
    if (method.isEmpty) throw ArgumentError('Refund method is required.');
    final requested = <String, int>{};
    for (final line in lines) {
      if (line.quantity <= 0) throw ArgumentError('Return quantities must be positive.');
      requested.update(
        line.invoiceItemId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    return transaction(() async {
      final invoice = await invoiceById(invoiceId);
      if (invoice == null || invoice.status == 'cancelled') {
        throw StateError('The original invoice is unavailable for return.');
      }
      var subtotalMinor = 0;
      var taxMinor = 0;
      final now = DateTime.now();
      final returnItems = <SalesReturnItemsCompanion>[];
      for (final entry in requested.entries) {
        final original = await (select(invoiceItems)
              ..where((t) => t.id.equals(entry.key) & t.invoiceId.equals(invoiceId)))
            .getSingleOrNull();
        if (original == null) {
          throw StateError('A selected item does not belong to this invoice.');
        }
        final priorReturns = await (select(salesReturnItems)
              ..where((t) => t.invoiceItemId.equals(original.id)))
            .get();
        final previouslyReturnedQty = priorReturns.fold<int>(0, (sum, row) => sum + row.quantity);
        final previouslyReturnedTotal = priorReturns.fold<int>(0, (sum, row) => sum + row.lineTotalMinor);
        final previouslyReturnedTax = priorReturns.fold<int>(0, (sum, row) => sum + row.taxMinor);
        final remainingQty = original.quantity - previouslyReturnedQty;
        if (entry.value > remainingQty || remainingQty <= 0) {
          throw ArgumentError('Return quantity exceeds the quantity remaining on the original invoice.');
        }
        final remainingTotal = original.lineTotalMinor - previouslyReturnedTotal;
        final remainingTax = original.taxMinor - previouslyReturnedTax;
        final returnedTotal = entry.value == remainingQty
            ? remainingTotal
            : (remainingTotal * entry.value + remainingQty ~/ 2) ~/ remainingQty;
        final returnedTax = entry.value == remainingQty
            ? remainingTax
            : (remainingTax * entry.value + remainingQty ~/ 2) ~/ remainingQty;
        final item = await (select(items)..where((t) => t.id.equals(original.itemId))).getSingleOrNull();
        if (restock && item == null) {
          throw StateError('The original product no longer exists; disable restocking to record this return.');
        }
        if (restock) {
          await (update(items)..where((t) => t.id.equals(original.itemId))).write(
            ItemsCompanion(
              stockQuantity: Value(item!.stockQuantity + entry.value),
              updatedAt: Value(now),
              syncStatus: const Value('pending'),
            ),
          );
          final returnBatchId = const Uuid().v4();
          await into(stockBatches).insert(StockBatchesCompanion.insert(
            id: returnBatchId,
            itemId: original.itemId,
            quantity: entry.value,
            createdAt: now,
          ));
          await into(syncQueue).insert(SyncQueueCompanion.insert(
            entityType: 'stockBatch',
            entityId: returnBatchId,
            operation: 'upsert',
            createdAt: now,
          ));
          await into(syncQueue).insert(SyncQueueCompanion.insert(
            entityType: 'item',
            entityId: original.itemId,
            operation: 'upsert',
            createdAt: now,
          ));
        }
        final lineSubtotal = returnedTotal - returnedTax;
        subtotalMinor += lineSubtotal;
        taxMinor += returnedTax;
        returnItems.add(SalesReturnItemsCompanion.insert(
          id: const Uuid().v4(),
          returnId: id,
          invoiceItemId: original.id,
          itemId: original.itemId,
          itemNameSnapshot: original.itemNameSnapshot,
          quantity: entry.value,
          unitPriceMinor: original.unitPriceMinor,
          taxRate: original.taxRate,
          taxMinor: returnedTax,
          lineTotalMinor: returnedTotal,
        ));
      }
      await into(salesReturns).insert(SalesReturnsCompanion.insert(
        id: id,
        returnNumber: returnNumber,
        invoiceId: invoiceId,
        customerId: Value(invoice.customerId),
        subtotalMinor: subtotalMinor,
        taxMinor: taxMinor,
        totalMinor: subtotalMinor + taxMinor,
        refundMethod: method,
        notes: Value(_nullable(notes)),
        createdAt: now,
      ));
      for (final line in returnItems) {
        await into(salesReturnItems).insert(line);
      }
      final allReturns = await (select(salesReturns)
            ..where((t) => t.invoiceId.equals(invoiceId)))
          .get();
      final totalReturned = allReturns.fold<int>(0, (sum, row) => sum + row.totalMinor);
      final paidAndReturned = invoice.paidMinor + totalReturned;
      await (update(invoices)..where((t) => t.id.equals(invoiceId))).write(
        InvoicesCompanion(
          paymentStatus: Value(
            paidAndReturned >= invoice.totalMinor
                ? 'paid'
                : paidAndReturned > 0
                    ? 'partial'
                    : 'unpaid',
          ),
        ),
      );
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'salesReturn',
        entityId: id,
        operation: 'upsert',
        createdAt: now,
      ));
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'invoice',
        entityId: invoiceId,
        operation: 'upsert',
        createdAt: now,
      ));
      return id;
    });
  }

  Future<List<Supplier>> getSuppliers({String query = ''}) {
    final q = '%' + query.trim() + '%';
    final statement = select(suppliers)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (query.trim().isNotEmpty) {
      statement.where((t) =>
          t.name.like(q) | t.phone.like(q) | t.gstin.like(q));
    }
    return statement.get();
  }

  Future<List<Purchase>> recentPurchases({int limit = 100}) =>
      (select(purchases)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  Future<int> supplierOutstandingMinor(String supplierId) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(total_minor - paid_minor), 0) AS amount '
      'FROM purchases WHERE supplier_id = ? AND payment_status != ?',
      variables: [
        Variable<String>(supplierId),
        const Variable<String>('cancelled'),
      ],
      readsFrom: {purchases},
    ).getSingle();
    return row.read<int>('amount');
  }

  Future<void> recordPurchase({
    required String purchaseId,
    required String purchaseNumber,
    required String supplierId,
    required List<PurchaseLine> lines,
    required int discountMinor,
    required int paidMinor,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('A purchase needs at least one product.');
    }
    if (lines.any((line) =>
        line.quantity <= 0 ||
        line.unitCostMinor < 0 ||
        line.taxRateBps < 0 ||
        line.taxRateBps > 10000)) {
      throw ArgumentError('Purchase quantities, costs or tax rates are invalid.');
    }

    final quantities = <String, int>{};
    final purchaseCosts = <String, int>{};
    for (final line in lines) {
      quantities.update(
        line.itemId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
      purchaseCosts.update(
        line.itemId,
        (value) => value + line.unitCostMinor * line.quantity,
        ifAbsent: () => line.unitCostMinor * line.quantity,
      );
    }

    await transaction(() async {
      final supplier = await (select(suppliers)
            ..where((t) => t.id.equals(supplierId)))
          .getSingleOrNull();
      if (supplier == null) throw StateError('Select a valid supplier.');

      final currentItems = <String, Item>{};
      for (final itemId in quantities.keys) {
        final item = await (select(items)
              ..where((t) => t.id.equals(itemId)))
            .getSingleOrNull();
        if (item == null) {
          throw StateError('A purchased product no longer exists.');
        }
        currentItems[itemId] = item;
      }

      final totals = const BillingCalculator().calculate(
        lines: lines
            .map((line) => BillingLine(
                  unitPriceMinor: line.unitCostMinor,
                  quantity: line.quantity,
                  taxRateBps: line.taxRateBps,
                ))
            .toList(),
        discountMinor: discountMinor,
      );
      if (paidMinor < 0 || paidMinor > totals.totalMinor) {
        throw ArgumentError(
          'Amount paid must be between zero and the purchase total.',
        );
      }
      final status = paidMinor == totals.totalMinor
          ? 'paid'
          : paidMinor == 0
              ? 'unpaid'
              : 'partial';
      final now = DateTime.now();
      await into(purchases).insert(PurchasesCompanion.insert(
        id: purchaseId,
        purchaseNumber: purchaseNumber,
        supplierId: supplierId,
        subtotalMinor: totals.subtotalMinor,
        discountMinor: Value(totals.discountMinor),
        taxMinor: Value(totals.taxMinor),
        totalMinor: totals.totalMinor,
        paidMinor: Value(paidMinor),
        paymentStatus: Value(status),
        notes: Value(notes),
        createdAt: now,
      ));
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'purchase',
        entityId: purchaseId,
        operation: 'upsert',
        createdAt: now,
      ));
      if (paidMinor > 0) {
        final openingPaymentId = const Uuid().v4();
        await into(supplierPayments).insert(SupplierPaymentsCompanion.insert(
          id: openingPaymentId,
          supplierId: supplierId,
          purchaseId: Value(purchaseId),
          amountMinor: paidMinor,
          paymentMethod: paymentMethod.trim().isEmpty ? 'cash' : paymentMethod.trim().toLowerCase(),
          paidAt: now,
        ));
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'supplierPayment',
          entityId: openingPaymentId,
          operation: 'upsert',
          createdAt: now,
        ));
      }

      var remainingDiscount = discountMinor;
      var remainingSubtotal = totals.subtotalMinor;
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final item = currentItems[line.itemId]!;
        final base = line.unitCostMinor * line.quantity;
        final allocatedDiscount = index == lines.length - 1
            ? remainingDiscount
            : remainingSubtotal == 0
                ? 0
                : (base * remainingDiscount + remainingSubtotal ~/ 2) ~/
                    remainingSubtotal;
        remainingDiscount -= allocatedDiscount;
        remainingSubtotal -= base;
        final tax = const BillingCalculator().taxFor(
          base - allocatedDiscount,
          line.taxRateBps,
        );
        await into(purchaseItems).insert(PurchaseItemsCompanion.insert(
          id: line.id,
          purchaseId: purchaseId,
          itemId: item.id,
          itemNameSnapshot: item.name,
          quantity: line.quantity,
          unitCostMinor: line.unitCostMinor,
          taxRate: line.taxRateBps / 100,
          taxMinor: tax,
          lineTotalMinor: base - allocatedDiscount + tax,
        ));
        await into(stockBatches).insert(StockBatchesCompanion.insert(
          id: const Uuid().v4(),
          itemId: item.id,
          purchaseItemId: Value(line.id),
          quantity: line.quantity,
          expiryDate: Value(line.expiryDate),
          createdAt: now,
        ));
      }

      for (final entry in quantities.entries) {
        final item = currentItems[entry.key]!;
        final newQuantity = item.stockQuantity + entry.value;
        final weightedCost = newQuantity == 0
            ? 0
            : (item.costMinor * item.stockQuantity + purchaseCosts[entry.key]! +
                    newQuantity ~/ 2) ~/
                newQuantity;
        await (update(items)..where((t) => t.id.equals(entry.key))).write(
          ItemsCompanion(
            stockQuantity: Value(newQuantity),
            costMinor: Value(weightedCost),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'item',
          entityId: entry.key,
          operation: 'upsert',
          createdAt: now,
        ));
      }
    });
  }

  Future<void> addExpense({
    required String id,
    required String category,
    required int amountMinor,
    required DateTime incurredAt,
    String? description,
    String paymentMethod = 'cash',
  }) async {
    if (category.trim().isEmpty) {
      throw ArgumentError('Expense category is required.');
    }
    if (amountMinor <= 0) {
      throw ArgumentError('Expense amount must be positive.');
    }
    await into(expenses).insert(ExpensesCompanion.insert(
      id: id,
      category: category.trim(),
      description: Value(
        description?.trim().isEmpty == true ? null : description?.trim(),
      ),
      amountMinor: amountMinor,
      paymentMethod: Value(paymentMethod.trim().toLowerCase()),
      incurredAt: incurredAt,
    ));
    await into(syncQueue).insert(SyncQueueCompanion.insert(
      entityType: 'expense',
      entityId: id,
      operation: 'upsert',
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _consumeStockBatches(String itemId, int quantity) async {
    if (quantity <= 0) return;
    final batches = await (select(stockBatches)
          ..where((t) =>
              t.itemId.equals(itemId) & t.quantity.isBiggerThanValue(0)))
        .get();
    batches.sort((a, b) {
      final aExpiry = a.expiryDate ?? DateTime(9999);
      final bExpiry = b.expiryDate ?? DateTime(9999);
      final byExpiry = aExpiry.compareTo(bExpiry);
      return byExpiry != 0 ? byExpiry : a.createdAt.compareTo(b.createdAt);
    });
    var remaining = quantity;
    for (final batch in batches) {
      if (remaining == 0) break;
      final consumed = batch.quantity < remaining ? batch.quantity : remaining;
      await (update(stockBatches)..where((t) => t.id.equals(batch.id))).write(
        StockBatchesCompanion(quantity: Value(batch.quantity - consumed)),
      );
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'stockBatch',
        entityId: batch.id,
        operation: 'upsert',
        createdAt: DateTime.now(),
      ));
      remaining -= consumed;
    }
    // Any remaining units are legacy/opening stock that has no batch record.
  }

  Future<void> adjustStock({
    required String id,
    required String itemId,
    required int quantityDelta,
    required String reason,
  }) async {
    if (quantityDelta == 0) {
      throw ArgumentError('Stock adjustment cannot be zero.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('A stock adjustment reason is required.');
    }
    await transaction(() async {
      final now = DateTime.now();
      final changed = await customUpdate(
        'UPDATE items SET stock_quantity = stock_quantity + ?, updated_at = ?, sync_status = ? '
        'WHERE id = ? AND stock_quantity + ? >= 0',
        variables: [
          Variable<int>(quantityDelta),
          Variable<DateTime>(now),
          const Variable<String>('pending'),
          Variable<String>(itemId),
          Variable<int>(quantityDelta),
        ],
        updates: {items},
      );
      if (changed != 1) {
        throw StateError(
          'Stock adjustment would make inventory negative or the product is missing.',
        );
      }
      if (quantityDelta < 0) {
        await _consumeStockBatches(itemId, -quantityDelta);
      } else {
        final batchId = const Uuid().v4();
        await into(stockBatches).insert(StockBatchesCompanion.insert(
          id: batchId,
          itemId: itemId,
          quantity: quantityDelta,
          createdAt: now,
        ));
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'stockBatch',
          entityId: batchId,
          operation: 'upsert',
          createdAt: now,
        ));
      }
      await into(stockAdjustments).insert(StockAdjustmentsCompanion.insert(
        id: id,
        itemId: itemId,
        quantityDelta: quantityDelta,
        reason: reason.trim(),
        createdAt: now,
      ));
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'stockAdjustment',
        entityId: id,
        operation: 'upsert',
        createdAt: now,
      ));
      await into(syncQueue).insert(SyncQueueCompanion.insert(
        entityType: 'item',
        entityId: itemId,
        operation: 'upsert',
        createdAt: now,
      ));
    });
  }

  Future<List<StockBatchRow>> expiringStock({int withinDays = 30}) async {
    final end = DateTime.now().add(Duration(days: withinDays));
    final rows = await (select(stockBatches)
          ..where((t) =>
              t.quantity.isBiggerThanValue(0) & t.expiryDate.isNotNull()))
        .get();
    final result = rows.where((row) {
      final expiry = row.expiryDate;
      return expiry != null && !expiry.isAfter(end);
    }).toList();
    result.sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    return result;
  }

  Future<List<StockAdjustment>> recentStockAdjustments({int limit = 100}) =>
      (select(stockAdjustments)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  Future<List<Expense>> recentExpenses({int limit = 50}) =>
      (select(expenses)
            ..orderBy([(t) => OrderingTerm.desc(t.incurredAt)])
            ..limit(limit))
          .get();

  Future<int> grossProfitBetween(DateTime start, DateTime end) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM((ii.unit_price_minor * ii.quantity) - '
      'ii.line_discount_minor - (ii.unit_cost_minor * ii.quantity)), 0) AS profit '
      'FROM invoice_items ii INNER JOIN invoices i ON i.id = ii.invoice_id '
      'WHERE i.created_at >= ? AND i.created_at < ? AND i.status != ?',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        const Variable<String>('cancelled'),
      ],
      readsFrom: {invoiceItems, invoices},
    ).getSingle();
    return row.read<int>('profit');
  }

  Future<GstSummary> gstSummaryBetween(DateTime start, DateTime end) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(cgst_minor), 0) AS cgst, '
      'COALESCE(SUM(sgst_minor), 0) AS sgst, '
      'COALESCE(SUM(igst_minor), 0) AS igst '
      'FROM invoices WHERE created_at >= ? AND created_at < ? AND status != ?',
      variables: [
        Variable<DateTime>(start),
        Variable<DateTime>(end),
        const Variable<String>('cancelled'),
      ],
      readsFrom: {invoices},
    ).getSingle();
    return GstSummary(
      cgstMinor: row.read<int>('cgst'),
      sgstMinor: row.read<int>('sgst'),
      igstMinor: row.read<int>('igst'),
    );
  }

  Future<int> expensesBetween(DateTime start, DateTime end) async {
    final rows = await (select(expenses)
          ..where((t) =>
              t.incurredAt.isBiggerOrEqualValue(start) &
              t.incurredAt.isSmallerThanValue(end)))
        .get();
    return rows.fold<int>(0, (sum, row) => sum + row.amountMinor);
  }

  Future<void> checkout({
    required String invoiceId,
    required String invoiceNumber,
    required List<CartLine> cart,
    String? customerId,
    required int discountMinor,
    required String paymentMethod,
    GstSupplyType gstSupplyType = GstSupplyType.intraState,
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
        final cartItem = cart.firstWhere((line) => line.item.id == entry.key).item;
        if (current.priceMinor != cartItem.priceMinor ||
            current.taxRate != cartItem.taxRate) {
          throw StateError(
            'Price or GST changed for ${current.name}. Refresh the cart before checkout.',
          );
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
      final gstTotals = const IndianGstCalculator().calculateInvoice(
        lines: effectiveLines.map((line) => GstLine(
          unitPriceMinor: line.unitPriceMinor,
          quantity: line.quantity,
          rateBps: line.taxRateBps,
        )).toList(),
        supplyType: gstSupplyType,
        discountMinor: discountMinor,
      );
      final totals = BillingTotals(
        subtotalMinor: gstTotals.subtotalMinor,
        taxMinor: gstTotals.taxMinor,
        discountMinor: gstTotals.discountMinor,
        totalMinor: gstTotals.totalMinor,
      );

      if (customerId != null) {
        final customer = await customerById(customerId);
        if (customer == null) throw StateError('The selected customer no longer exists.');
      }
      await into(invoices).insert(InvoicesCompanion.insert(
        id: invoiceId,
        invoiceNumber: invoiceNumber,
        customerId: Value(customerId),
        subtotalMinor: totals.subtotalMinor,
        discountMinor: Value(totals.discountMinor),
        taxMinor: Value(totals.taxMinor),
        cgstMinor: Value(gstTotals.cgstMinor),
        sgstMinor: Value(gstTotals.sgstMinor),
        igstMinor: Value(gstTotals.igstMinor),
        gstSupplyType: Value(gstSupplyType.name),
        totalMinor: totals.totalMinor,
        paidMinor: Value(paymentMethod.trim().toLowerCase() == 'credit' ? 0 : totals.totalMinor),
        paymentStatus: Value(paymentMethod.trim().toLowerCase() == 'credit' ? 'unpaid' : 'paid'),
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

        final gstLine = const IndianGstCalculator().calculateLine(
          line: GstLine(
            unitPriceMinor: current.priceMinor,
            quantity: line.quantity,
            rateBps: (current.taxRate * 100).round(),
          ),
          supplyType: gstSupplyType,
          discountMinor: lineDiscount,
        );
        final lineTax = gstLine.taxMinor;
        await into(invoiceItems).insert(InvoiceItemsCompanion.insert(
          id: line.id,
          invoiceId: invoiceId,
          itemId: current.id,
          itemNameSnapshot: current.name,
          skuSnapshot: Value(current.sku),
          hsnSacSnapshot: Value(current.hsnSac),
          quantity: line.quantity,
          unitPriceMinor: current.priceMinor,
          taxRate: current.taxRate,
          unitCostMinor: Value(current.costMinor),
          lineDiscountMinor: Value(lineDiscount),
          cgstMinor: Value(gstLine.cgstMinor),
          sgstMinor: Value(gstLine.sgstMinor),
          igstMinor: Value(gstLine.igstMinor),
          taxMinor: lineTax,
          lineTotalMinor: lineSubtotal - lineDiscount + lineTax,
        ));
      }

      if (customerId != null && paymentMethod.trim().toLowerCase() != 'credit') {
        final receiptId = const Uuid().v4();
        await into(customerPayments).insert(CustomerPaymentsCompanion.insert(
          id: receiptId,
          customerId: customerId,
          invoiceId: Value(invoiceId),
          amountMinor: totals.totalMinor,
          paymentMethod: paymentMethod.trim().toLowerCase(),
          receivedAt: now,
        ));
        await into(syncQueue).insert(SyncQueueCompanion.insert(
          entityType: 'customerPayment',
          entityId: receiptId,
          operation: 'upsert',
          createdAt: now,
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
        await _consumeStockBatches(entry.key, entry.value);
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
      final returned = await (select(salesReturns)
            ..where((t) => t.invoiceId.equals(row.id)))
          .get();
      final returnedMinor = returned.fold<int>(0, (sum, value) => sum + value.totalMinor);
      final effectivePaid = row.paymentStatus == 'paid' &&
              row.paidMinor == 0 &&
              row.paymentMethod.toLowerCase() != 'credit'
          ? row.totalMinor
          : row.paidMinor;
      final outstanding = row.totalMinor - effectivePaid - returnedMinor;
      if (row.status != 'cancelled' && outstanding > 0) {
        creditMinor += outstanding;
      }
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
    final supplierRows = await select(suppliers).get();
    final purchaseRows = await select(purchases).get();
    final purchaseItemRows = await select(purchaseItems).get();
    final expenseRows = await select(expenses).get();
    final adjustmentRows = await select(stockAdjustments).get();
    final batchRows = await select(stockBatches).get();
    final customerPaymentRows = await select(customerPayments).get();
    final supplierPaymentRows = await select(supplierPayments).get();
    final returnRows = await select(salesReturns).get();
    final returnItemRows = await select(salesReturnItems).get();
    return {
      'format': 'sbill-backup-v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'items': itemRows.map((x) => {
        'id': x.id, 'sku': x.sku, 'name': x.name, 'description': x.description,
        'priceMinor': x.priceMinor, 'costMinor': x.costMinor, 'taxRate': x.taxRate,
        'stockQuantity': x.stockQuantity, 'lowStockThreshold': x.lowStockThreshold,
        'category': x.category, 'barcode': x.barcode, 'hsnSac': x.hsnSac, 'isActive': x.isActive,
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
        'paidMinor': x.paidMinor, 'paymentStatus': x.paymentStatus,
        'taxMinor': x.taxMinor, 'cgstMinor': x.cgstMinor, 'sgstMinor': x.sgstMinor,
        'igstMinor': x.igstMinor, 'gstSupplyType': x.gstSupplyType,
        'totalMinor': x.totalMinor, 'paymentMethod': x.paymentMethod,
        'status': x.status, 'notes': x.notes,
        'createdAt': x.createdAt.toIso8601String(), 'updatedAt': x.updatedAt.toIso8601String(),
      }).toList(),
      'invoiceItems': invoiceItemRows.map((x) => {
        'id': x.id, 'invoiceId': x.invoiceId, 'itemId': x.itemId,
        'itemNameSnapshot': x.itemNameSnapshot, 'skuSnapshot': x.skuSnapshot, 'hsnSacSnapshot': x.hsnSacSnapshot,
        'quantity': x.quantity, 'unitPriceMinor': x.unitPriceMinor,
        'unitCostMinor': x.unitCostMinor, 'lineDiscountMinor': x.lineDiscountMinor,
        'cgstMinor': x.cgstMinor, 'sgstMinor': x.sgstMinor, 'igstMinor': x.igstMinor,
        'taxRate': x.taxRate, 'taxMinor': x.taxMinor, 'lineTotalMinor': x.lineTotalMinor,
      }).toList(),
      'suppliers': supplierRows.map((x) => {
        'id': x.id, 'name': x.name, 'phone': x.phone, 'email': x.email,
        'gstin': x.gstin, 'address': x.address,
        'createdAt': x.createdAt.toIso8601String(), 'updatedAt': x.updatedAt.toIso8601String(),
      }).toList(),
      'purchases': purchaseRows.map((x) => {
        'id': x.id, 'purchaseNumber': x.purchaseNumber, 'supplierId': x.supplierId,
        'subtotalMinor': x.subtotalMinor, 'discountMinor': x.discountMinor,
        'taxMinor': x.taxMinor, 'totalMinor': x.totalMinor, 'paidMinor': x.paidMinor,
        'paymentStatus': x.paymentStatus, 'notes': x.notes,
        'createdAt': x.createdAt.toIso8601String(),
      }).toList(),
      'purchaseItems': purchaseItemRows.map((x) => {
        'id': x.id, 'purchaseId': x.purchaseId, 'itemId': x.itemId,
        'itemNameSnapshot': x.itemNameSnapshot, 'quantity': x.quantity,
        'unitCostMinor': x.unitCostMinor, 'taxRate': x.taxRate,
        'taxMinor': x.taxMinor, 'lineTotalMinor': x.lineTotalMinor,
      }).toList(),
      'expenses': expenseRows.map((x) => {
        'id': x.id, 'category': x.category, 'description': x.description,
        'amountMinor': x.amountMinor, 'paymentMethod': x.paymentMethod,
        'incurredAt': x.incurredAt.toIso8601String(),
      }).toList(),
      'stockAdjustments': adjustmentRows.map((x) => {
        'id': x.id, 'itemId': x.itemId, 'quantityDelta': x.quantityDelta,
        'reason': x.reason, 'createdAt': x.createdAt.toIso8601String(),
      }).toList(),
      'stockBatches': batchRows.map((x) => {
        'id': x.id, 'itemId': x.itemId, 'purchaseItemId': x.purchaseItemId,
        'quantity': x.quantity, 'expiryDate': x.expiryDate?.toIso8601String(),
        'createdAt': x.createdAt.toIso8601String(),
      }).toList(),
      'customerPayments': customerPaymentRows.map((x) => {
        'id': x.id, 'customerId': x.customerId, 'invoiceId': x.invoiceId,
        'amountMinor': x.amountMinor, 'paymentMethod': x.paymentMethod,
        'reference': x.reference, 'notes': x.notes,
        'receivedAt': x.receivedAt.toIso8601String(),
      }).toList(),
      'supplierPayments': supplierPaymentRows.map((x) => {
        'id': x.id, 'supplierId': x.supplierId, 'purchaseId': x.purchaseId,
        'amountMinor': x.amountMinor, 'paymentMethod': x.paymentMethod,
        'reference': x.reference, 'notes': x.notes,
        'paidAt': x.paidAt.toIso8601String(),
      }).toList(),
      'salesReturns': returnRows.map((x) => {
        'id': x.id, 'returnNumber': x.returnNumber, 'invoiceId': x.invoiceId,
        'customerId': x.customerId, 'subtotalMinor': x.subtotalMinor,
        'taxMinor': x.taxMinor, 'totalMinor': x.totalMinor,
        'refundMethod': x.refundMethod, 'notes': x.notes,
        'createdAt': x.createdAt.toIso8601String(),
      }).toList(),
      'salesReturnItems': returnItemRows.map((x) => {
        'id': x.id, 'returnId': x.returnId, 'invoiceItemId': x.invoiceItemId,
        'itemId': x.itemId, 'itemNameSnapshot': x.itemNameSnapshot,
        'quantity': x.quantity, 'unitPriceMinor': x.unitPriceMinor,
        'taxRate': x.taxRate, 'taxMinor': x.taxMinor,
        'lineTotalMinor': x.lineTotalMinor,
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
        final hsnSac = _rowValue(row, const ['hsn_sac', 'hsn', 'sac']).trim();
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
          hsnSac: Value(hsnSac.isEmpty ? null : hsnSac),
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
            hsnSac: companion.hsnSac,
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

  static List<String> validateBackupSnapshot(Map<String, dynamic> snapshot) {
    final errors = <String>[];
    const collectionKeys = [
      'items',
      'customers',
      'invoices',
      'invoiceItems',
      'suppliers',
      'purchases',
      'purchaseItems',
      'expenses',
      'stockAdjustments',
      'stockBatches',
      'customerPayments',
      'supplierPayments',
      'salesReturns',
      'salesReturnItems',
    ];
    final collections = <String, List<Map>>{};

    for (final key in collectionKeys) {
      final value = snapshot[key];
      if (value == null) {
        collections[key] = <Map>[];
        continue;
      }
      if (value is! List) {
        errors.add('Backup section "$key" must be a list.');
        collections[key] = <Map>[];
        continue;
      }
      final rows = <Map>[];
      for (var index = 0; index < value.length; index++) {
        final row = value[index];
        if (row is! Map) {
          errors.add('Backup section "$key", row ${index + 1}, must be an object.');
        } else {
          rows.add(row);
        }
      }
      collections[key] = rows;
    }

    const requiredFields = <String, List<String>>{
      'items': ['id', 'name'],
      'customers': ['id', 'name'],
      'invoices': ['id', 'invoiceNumber', 'paymentMethod'],
      'invoiceItems': ['id', 'invoiceId', 'itemId', 'itemNameSnapshot'],
      'suppliers': ['id', 'name'],
      'purchases': ['id', 'purchaseNumber', 'supplierId'],
      'purchaseItems': ['id', 'purchaseId', 'itemId', 'itemNameSnapshot'],
      'expenses': ['id', 'category'],
      'stockAdjustments': ['id', 'itemId', 'reason'],
      'stockBatches': ['id', 'itemId'],
      'customerPayments': ['id', 'customerId', 'amountMinor', 'paymentMethod'],
      'supplierPayments': ['id', 'supplierId', 'amountMinor', 'paymentMethod'],
      'salesReturns': ['id', 'returnNumber', 'invoiceId', 'refundMethod'],
      'salesReturnItems': ['id', 'returnId', 'invoiceItemId', 'itemId', 'itemNameSnapshot'],
    };
    final idsByCollection = <String, Set<String>>{};

    for (final entry in collections.entries) {
      final key = entry.key;
      final rows = entry.value;
      final ids = <String>{};
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final rowNumber = index + 1;
        for (final field in requiredFields[key] ?? const <String>[]) {
          if ((row[field]?.toString().trim() ?? '').isEmpty) {
            errors.add('Backup $key row $rowNumber: required field "$field" is missing.');
          }
        }
        for (final amountField in const [
          'amountMinor', 'totalMinor', 'subtotalMinor', 'taxMinor',
          'paidMinor', 'unitPriceMinor', 'unitCostMinor', 'lineTotalMinor',
        ]) {
          final raw = row[amountField];
          if (raw == null) continue;
          final amount = int.tryParse(raw.toString());
          if (amount == null || amount < 0) {
            errors.add('Backup $key row $rowNumber: "$amountField" must be a non-negative integer.');
          }
        }
        final id = row['id']?.toString().trim() ?? '';
        if (id.isNotEmpty && !ids.add(id)) {
          errors.add('Backup $key contains duplicate ID "$id".');
        }
      }
      idsByCollection[key] = ids;
    }

    void validateReference(
      String childCollection,
      String childField,
      String parentCollection,
    ) {
      final parentIds = idsByCollection[parentCollection] ?? const <String>{};
      final rows = collections[childCollection] ?? const <Map>[];
      for (var index = 0; index < rows.length; index++) {
        final value = rows[index][childField];
        if (value == null || value.toString().trim().isEmpty) continue;
        if (!parentIds.contains(value.toString())) {
          errors.add(
            'Backup $childCollection row ${index + 1}: "$childField" '
            'does not match a record in "$parentCollection".',
          );
        }
      }
    }

    validateReference('invoiceItems', 'invoiceId', 'invoices');
    validateReference('invoices', 'customerId', 'customers');
    validateReference('purchases', 'supplierId', 'suppliers');
    validateReference('purchaseItems', 'purchaseId', 'purchases');
    validateReference('customerPayments', 'customerId', 'customers');
    validateReference('customerPayments', 'invoiceId', 'invoices');
    validateReference('supplierPayments', 'supplierId', 'suppliers');
    validateReference('supplierPayments', 'purchaseId', 'purchases');
    validateReference('salesReturns', 'invoiceId', 'invoices');
    validateReference('salesReturnItems', 'returnId', 'salesReturns');
    validateReference('salesReturnItems', 'invoiceItemId', 'invoiceItems');

    return errors;
  }

  Future<int> importSnapshot(Map<String, dynamic> snapshot) async {
    if (snapshot['format'] != 'sbill-backup-v1') {
      throw ArgumentError('Unsupported SBILL backup format.');
    }
    final validationErrors = validateBackupSnapshot(snapshot);
    if (validationErrors.isNotEmpty) {
      throw ArgumentError('Invalid SBILL backup: ${validationErrors.join(' ')}');
    }
    final itemRows = (snapshot['items'] as List?)?.whereType<Map>().toList() ?? const [];
    final customerRows = (snapshot['customers'] as List?)?.whereType<Map>().toList() ?? const [];
    final invoiceRows = (snapshot['invoices'] as List?)?.whereType<Map>().toList() ?? const [];
    final invoiceItemRows = (snapshot['invoiceItems'] as List?)?.whereType<Map>().toList() ?? const [];
    final supplierRows = (snapshot['suppliers'] as List?)?.whereType<Map>().toList() ?? const [];
    final purchaseRows = (snapshot['purchases'] as List?)?.whereType<Map>().toList() ?? const [];
    final purchaseItemRows = (snapshot['purchaseItems'] as List?)?.whereType<Map>().toList() ?? const [];
    final expenseRows = (snapshot['expenses'] as List?)?.whereType<Map>().toList() ?? const [];
    final adjustmentRows = (snapshot['stockAdjustments'] as List?)?.whereType<Map>().toList() ?? const [];
    final batchRows = (snapshot['stockBatches'] as List?)?.whereType<Map>().toList() ?? const [];
    final customerPaymentRows = (snapshot['customerPayments'] as List?)?.whereType<Map>().toList() ?? const [];
    final supplierPaymentRows = (snapshot['supplierPayments'] as List?)?.whereType<Map>().toList() ?? const [];
    final returnRows = (snapshot['salesReturns'] as List?)?.whereType<Map>().toList() ?? const [];
    final returnItemRows = (snapshot['salesReturnItems'] as List?)?.whereType<Map>().toList() ?? const [];

    var imported = 0;
    final importedItemIds = <String>[];
    final importedCustomerIds = <String>[];
    final importedInvoiceIds = <String>[];
    final importedSupplierIds = <String>[];
    final importedPurchaseIds = <String>[];
    final now = DateTime.now();

    await transaction(() async {
      final existingItemIds = (await select(items).get()).map((row) => row.id).toSet();
      final existingCustomerIds = (await select(customers).get()).map((row) => row.id).toSet();
      final existingInvoiceIds = (await select(invoices).get()).map((row) => row.id).toSet();
      final existingInvoiceItemIds = (await select(invoiceItems).get()).map((row) => row.id).toSet();
      final existingSupplierIds = (await select(suppliers).get()).map((row) => row.id).toSet();
      final existingPurchaseIds = (await select(purchases).get()).map((row) => row.id).toSet();
      final existingPurchaseItemIds = (await select(purchaseItems).get()).map((row) => row.id).toSet();
      final existingExpenseIds = (await select(expenses).get()).map((row) => row.id).toSet();
      final existingAdjustmentIds = (await select(stockAdjustments).get()).map((row) => row.id).toSet();
      final existingBatchIds = (await select(stockBatches).get()).map((row) => row.id).toSet();
      final existingCustomerPaymentIds = (await select(customerPayments).get()).map((row) => row.id).toSet();
      final existingSupplierPaymentIds = (await select(supplierPayments).get()).map((row) => row.id).toSet();
      final existingReturnIds = (await select(salesReturns).get()).map((row) => row.id).toSet();
      final existingReturnItemIds = (await select(salesReturnItems).get()).map((row) => row.id).toSet();
      final importedReturnIds = <String>[];

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
          hsnSac: Value(_nullable(row['hsnSac'])),
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
          cgstMinor: Value(_number(row['cgstMinor'])),
          sgstMinor: Value(_number(row['sgstMinor'])),
          igstMinor: Value(_number(row['igstMinor'])),
          gstSupplyType: Value(row['gstSupplyType']?.toString() ?? 'unknown'),
          totalMinor: Value(_number(row['totalMinor'])),
          paidMinor: Value(
            row.containsKey('paidMinor')
                ? _number(row['paidMinor'])
                : row['paymentMethod']?.toString().toLowerCase() == 'credit'
                    ? 0
                    : _number(row['totalMinor']),
          ),
          paymentStatus: Value(
            row['paymentStatus']?.toString() ??
                (row['paymentMethod']?.toString().toLowerCase() == 'credit'
                    ? 'unpaid'
                    : 'paid'),
          ),
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
        if (existingInvoiceItemIds.contains(id) ||
            !(existingInvoiceIds.contains(invoiceId) ||
              importedInvoiceIds.contains(invoiceId))) continue;
        await into(invoiceItems).insert(InvoiceItemsCompanion(
          id: Value(id),
          invoiceId: Value(invoiceId),
          itemId: Value(row['itemId'].toString()),
          itemNameSnapshot: Value(row['itemNameSnapshot'].toString()),
          skuSnapshot: Value(_nullable(row['skuSnapshot'])),
          hsnSacSnapshot: Value(_nullable(row['hsnSacSnapshot'])),
          quantity: Value(_number(row['quantity'])),
          unitPriceMinor: Value(_number(row['unitPriceMinor'])),
          unitCostMinor: Value(_number(row['unitCostMinor'])),
          lineDiscountMinor: Value(_number(row['lineDiscountMinor'])),
          cgstMinor: Value(_number(row['cgstMinor'])),
          sgstMinor: Value(_number(row['sgstMinor'])),
          igstMinor: Value(_number(row['igstMinor'])),
          taxRate: Value(_decimal(row['taxRate'])),
          taxMinor: Value(_number(row['taxMinor'])),
          lineTotalMinor: Value(_number(row['lineTotalMinor'])),
        ));
        imported++;
      }
      for (final row in supplierRows) {
        final id = row['id'].toString();
        if (existingSupplierIds.contains(id)) continue;
        final createdAt = _rowDate(row['createdAt']) ?? now;
        await into(suppliers).insert(SuppliersCompanion.insert(
          id: id,
          name: row['name'].toString(),
          phone: Value(_nullable(row['phone'])),
          email: Value(_nullable(row['email'])),
          gstin: Value(_nullable(row['gstin'])),
          address: Value(_nullable(row['address'])),
          createdAt: createdAt,
          updatedAt: _rowDate(row['updatedAt']) ?? createdAt,
        ));
        importedSupplierIds.add(id);
        imported++;
      }
      for (final row in purchaseRows) {
        final id = row['id'].toString();
        if (existingPurchaseIds.contains(id)) continue;
        final supplierId = row['supplierId'].toString();
        final supplierExists = existingSupplierIds.contains(supplierId) ||
            importedSupplierIds.contains(supplierId);
        if (!supplierExists) continue;
        await into(purchases).insert(PurchasesCompanion.insert(
          id: id,
          purchaseNumber: row['purchaseNumber'].toString(),
          supplierId: supplierId,
          subtotalMinor: _number(row['subtotalMinor']),
          discountMinor: Value(_number(row['discountMinor'])),
          taxMinor: Value(_number(row['taxMinor'])),
          totalMinor: _number(row['totalMinor']),
          paidMinor: Value(_number(row['paidMinor'])),
          paymentStatus: Value(row['paymentStatus']?.toString() ?? 'unpaid'),
          notes: Value(_nullable(row['notes'])),
          createdAt: _rowDate(row['createdAt']) ?? now,
        ));
        importedPurchaseIds.add(id);
        imported++;
      }
      for (final row in purchaseItemRows) {
        final id = row['id'].toString();
        final purchaseId = row['purchaseId'].toString();
        if (existingPurchaseItemIds.contains(id) ||
            !(existingPurchaseIds.contains(purchaseId) ||
              importedPurchaseIds.contains(purchaseId))) continue;
        await into(purchaseItems).insert(PurchaseItemsCompanion.insert(
          id: id,
          purchaseId: purchaseId,
          itemId: row['itemId'].toString(),
          itemNameSnapshot: row['itemNameSnapshot'].toString(),
          quantity: _number(row['quantity']),
          unitCostMinor: _number(row['unitCostMinor']),
          taxRate: _decimal(row['taxRate']),
          taxMinor: _number(row['taxMinor']),
          lineTotalMinor: _number(row['lineTotalMinor']),
        ));
        imported++;
      }
      for (final row in expenseRows) {
        final id = row['id'].toString();
        if (existingExpenseIds.contains(id)) continue;
        await into(expenses).insert(ExpensesCompanion.insert(
          id: id,
          category: row['category'].toString(),
          description: Value(_nullable(row['description'])),
          amountMinor: _number(row['amountMinor']),
          paymentMethod: Value(row['paymentMethod']?.toString() ?? 'cash'),
          incurredAt: _rowDate(row['incurredAt']) ?? now,
        ));
        imported++;
      }
      for (final row in adjustmentRows) {
        final id = row['id'].toString();
        if (existingAdjustmentIds.contains(id)) continue;
        await into(stockAdjustments).insert(StockAdjustmentsCompanion.insert(
          id: id,
          itemId: row['itemId'].toString(),
          quantityDelta: _number(row['quantityDelta']),
          reason: row['reason'].toString(),
          createdAt: _rowDate(row['createdAt']) ?? now,
        ));
        imported++;
      }
      for (final row in batchRows) {
        final id = row['id'].toString();
        if (existingBatchIds.contains(id)) continue;
        await into(stockBatches).insert(StockBatchesCompanion.insert(
          id: id,
          itemId: row['itemId'].toString(),
          purchaseItemId: Value(_nullable(row['purchaseItemId'])),
          quantity: _number(row['quantity']),
          expiryDate: Value(_rowDate(row['expiryDate'])),
          createdAt: _rowDate(row['createdAt']) ?? now,
        ));
        imported++;
      }

      for (final row in customerPaymentRows) {
        final id = row['id'].toString();
        final customerId = row['customerId'].toString();
        final invoiceId = _nullable(row['invoiceId']);
        if (existingCustomerPaymentIds.contains(id)) continue;
        if (!(existingCustomerIds.contains(customerId) || importedCustomerIds.contains(customerId))) continue;
        if (invoiceId != null && !(existingInvoiceIds.contains(invoiceId) || importedInvoiceIds.contains(invoiceId))) continue;
        await into(customerPayments).insert(CustomerPaymentsCompanion.insert(
          id: id,
          customerId: customerId,
          invoiceId: Value(invoiceId),
          amountMinor: _number(row['amountMinor']),
          paymentMethod: row['paymentMethod'].toString(),
          reference: Value(_nullable(row['reference'])),
          notes: Value(_nullable(row['notes'])),
          receivedAt: _rowDate(row['receivedAt']) ?? now,
        ));
        if (invoiceId != null && existingInvoiceIds.contains(invoiceId) &&
            !importedInvoiceIds.contains(invoiceId)) {
          final invoice = await invoiceById(invoiceId);
          if (invoice != null) {
            final receipts = await (select(customerPayments)
                  ..where((payment) => payment.invoiceId.equals(invoiceId)))
                .get();
            final ledgerPaid = receipts.fold<int>(0, (sum, payment) => sum + payment.amountMinor);
            final paid = ledgerPaid.clamp(invoice.paidMinor, invoice.totalMinor).toInt();
            await (update(invoices)..where((t) => t.id.equals(invoiceId))).write(
              InvoicesCompanion(
                paidMinor: Value(paid),
                paymentStatus: Value(paid >= invoice.totalMinor ? 'paid' : paid > 0 ? 'partial' : 'unpaid'),
              ),
            );
          }
        }
        imported++;
      }
      for (final row in supplierPaymentRows) {
        final id = row['id'].toString();
        final supplierId = row['supplierId'].toString();
        final purchaseId = _nullable(row['purchaseId']);
        if (existingSupplierPaymentIds.contains(id)) continue;
        if (!(existingSupplierIds.contains(supplierId) || importedSupplierIds.contains(supplierId))) continue;
        if (purchaseId != null && !(existingPurchaseIds.contains(purchaseId) || importedPurchaseIds.contains(purchaseId))) continue;
        await into(supplierPayments).insert(SupplierPaymentsCompanion.insert(
          id: id,
          supplierId: supplierId,
          purchaseId: Value(purchaseId),
          amountMinor: _number(row['amountMinor']),
          paymentMethod: row['paymentMethod'].toString(),
          reference: Value(_nullable(row['reference'])),
          notes: Value(_nullable(row['notes'])),
          paidAt: _rowDate(row['paidAt']) ?? now,
        ));
        if (purchaseId != null && existingPurchaseIds.contains(purchaseId) &&
            !importedPurchaseIds.contains(purchaseId)) {
          final purchase = await (select(purchases)
                ..where((t) => t.id.equals(purchaseId)))
              .getSingleOrNull();
          if (purchase != null) {
            final payments = await (select(supplierPayments)
                  ..where((payment) => payment.purchaseId.equals(purchaseId)))
                .get();
            final ledgerPaid = payments.fold<int>(0, (sum, payment) => sum + payment.amountMinor);
            final paid = ledgerPaid.clamp(purchase.paidMinor, purchase.totalMinor).toInt();
            await (update(purchases)..where((t) => t.id.equals(purchaseId))).write(
              PurchasesCompanion(
                paidMinor: Value(paid),
                paymentStatus: Value(paid >= purchase.totalMinor ? 'paid' : paid > 0 ? 'partial' : 'unpaid'),
              ),
            );
          }
        }
        imported++;
      }
      for (final row in returnRows) {
        final id = row['id'].toString();
        final invoiceId = row['invoiceId'].toString();
        if (existingReturnIds.contains(id)) continue;
        if (!(existingInvoiceIds.contains(invoiceId) || importedInvoiceIds.contains(invoiceId))) continue;
        await into(salesReturns).insert(SalesReturnsCompanion.insert(
          id: id,
          returnNumber: row['returnNumber'].toString(),
          invoiceId: invoiceId,
          customerId: Value(_nullable(row['customerId'])),
          subtotalMinor: _number(row['subtotalMinor']),
          taxMinor: _number(row['taxMinor']),
          totalMinor: _number(row['totalMinor']),
          refundMethod: row['refundMethod'].toString(),
          notes: Value(_nullable(row['notes'])),
          createdAt: _rowDate(row['createdAt']) ?? now,
        ));
        importedReturnIds.add(id);
        imported++;
      }
      for (final invoiceId in {
        ...returnRows.map((row) => row['invoiceId'].toString()),
        ...customerPaymentRows.map((row) => _nullable(row['invoiceId'])).whereType<String>(),
      }) {
        final invoice = await invoiceById(invoiceId);
        if (invoice == null) continue;
        final returns = await (select(salesReturns)
              ..where((t) => t.invoiceId.equals(invoiceId)))
            .get();
        final returned = returns.fold<int>(0, (sum, row) => sum + row.totalMinor);
        final paidAndReturned = invoice.paidMinor + returned;
        await (update(invoices)..where((t) => t.id.equals(invoiceId))).write(
          InvoicesCompanion(
            paymentStatus: Value(
              paidAndReturned >= invoice.totalMinor
                  ? 'paid'
                  : paidAndReturned > 0
                      ? 'partial'
                      : 'unpaid',
            ),
          ),
        );
      }
      for (final row in returnItemRows) {
        final id = row['id'].toString();
        final returnId = row['returnId'].toString();
        if (existingReturnItemIds.contains(id)) continue;
        if (!(existingReturnIds.contains(returnId) || importedReturnIds.contains(returnId))) continue;
        await into(salesReturnItems).insert(SalesReturnItemsCompanion.insert(
          id: id,
          returnId: returnId,
          invoiceItemId: row['invoiceItemId'].toString(),
          itemId: row['itemId'].toString(),
          itemNameSnapshot: row['itemNameSnapshot'].toString(),
          quantity: _number(row['quantity']),
          unitPriceMinor: _number(row['unitPriceMinor']),
          taxRate: _decimal(row['taxRate']),
          taxMinor: _number(row['taxMinor']),
          lineTotalMinor: _number(row['lineTotalMinor']),
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
      await delete(salesReturnItems).go();
      await delete(salesReturns).go();
      await delete(customerPayments).go();
      await delete(supplierPayments).go();
      await delete(purchaseItems).go();
      await delete(stockBatches).go();
      await delete(purchases).go();
      await delete(suppliers).go();
      await delete(expenses).go();
      await delete(stockAdjustments).go();
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

class SalesReturnLine {
  const SalesReturnLine({
    required this.invoiceItemId,
    required this.quantity,
  });

  final String invoiceItemId;
  final int quantity;
}

class PurchaseLine {
  const PurchaseLine({
    required this.id,
    required this.itemId,
    required this.quantity,
    required this.unitCostMinor,
    required this.taxRateBps,
    this.expiryDate,
  });

  final String id;
  final String itemId;
  final int quantity;
  final int unitCostMinor;
  final int taxRateBps;
  final DateTime? expiryDate;
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


class GstSummary {
  const GstSummary({
    required this.cgstMinor,
    required this.sgstMinor,
    required this.igstMinor,
  });

  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  int get totalMinor => cgstMinor + sgstMinor + igstMinor;
}

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
