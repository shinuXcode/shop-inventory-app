import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app.dart';
import '../cloud/cloud_config.dart';
import '../database/app_database.dart';
import '../settings/app_settings.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.watch(databaseProvider));
  ref.onDispose(service.dispose);
  return service;
});

class SyncService {
  SyncService(this.db) {
    _subscription = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    if (CloudConfig.configured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        unawaited(syncNow());
      });
    }
    if (CloudConfig.configured) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(syncNow()));
    }
  }

  final AppDatabase db;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _timer;
  bool syncing = false;
  String? lastError;

  Future<void> _onConnectivity(List<ConnectivityResult> result) async {
    if (result.any((x) => x != ConnectivityResult.none)) await syncNow();
  }

  Future<void> syncNow() async {
    if (syncing || !CloudConfig.configured) return;
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    final businessId = settings.businessId;
    if (businessId == null || businessId.isEmpty) return;

    syncing = true;
    lastError = null;
    try {
      final queue = await db.pendingSyncQueue(limit: 100);
      try {
        await _pushBusiness(settings, businessId, client);
      } catch (e) {
        lastError = 'Business settings sync: ' + e.toString();
      }
      for (final event in queue) {
        try {
          if (event.attempts > 0) {
            final retry = event.attempts.clamp(1, 3).toInt();
            final seconds = 1 << (retry - 1);
            await Future<void>.delayed(Duration(seconds: seconds));
          }
          await _push(event, businessId, client);
          await db.deleteSyncQueueEntry(event.id);
        } catch (e) {
          await db.failSyncQueueEntry(event.id, event.attempts, e.toString());
          lastError = e.toString();
          if (event.attempts < 4) break;
        }
      }

      if ((await db.pendingSyncCount()) == 0) {
        await _pullLatest(businessId, client);
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      if (lastError == null) {
        await prefs.setString('lastSyncAt', DateTime.now().toUtc().toIso8601String());
      }
      syncing = false;
    }
  }

  Future<bool> _remoteIsNewer(
    SupabaseClient client,
    String table,
    String id,
    DateTime localUpdatedAt,
    String businessId,
  ) async {
    final row = await client
        .from(table)
        .select('updated_at')
        .eq('id', id)
        .eq('business_id', businessId)
        .maybeSingle();
    if (row == null) return false;
    final value = row['updated_at'];
    final remote = DateTime.tryParse(value?.toString() ?? '');
    return remote != null && remote.toUtc().isAfter(localUpdatedAt.toUtc());
  }

  Future<void> _pushBusiness(
    AppSettings settings,
    String businessId,
    SupabaseClient client,
  ) async {
    await client.from('businesses').update({
      'name': settings.businessName,
      'phone': settings.businessPhone.isEmpty ? null : settings.businessPhone,
      'email': settings.businessEmail.isEmpty ? null : settings.businessEmail,
      'address': settings.businessAddress.isEmpty ? null : settings.businessAddress,
      'gst_number': settings.gstNumber.isEmpty ? null : settings.gstNumber,
      'currency': settings.currency,
      'invoice_prefix': settings.invoicePrefix,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', businessId);
  }

  Future<void> _push(SyncQueueData event, String businessId, SupabaseClient client) async {
    if (event.operation != 'upsert') {
      throw StateError('Unsupported sync operation: ${event.operation}');
    }
    switch (event.entityType) {
      case 'item':
        final item = await (db.select(db.items)..where((t) => t.id.equals(event.entityId))).getSingleOrNull();
        if (item == null) return;
        if (await _remoteIsNewer(client, 'items', item.id, item.updatedAt, businessId)) {
          await _pullItem(item.id, businessId, client);
          return;
        }
        await client.from('items').upsert({
          'id': item.id,
          'business_id': businessId,
          'sku': item.sku ?? item.id,
          'name': item.name,
          'description': item.description,
          'barcode': item.barcode,
          'hsn_sac': item.hsnSac,
          'price_minor': item.priceMinor,
          'cost_minor': item.costMinor,
          'tax_rate': item.taxRate,
          'stock_quantity': item.stockQuantity,
          'low_stock_threshold': item.lowStockThreshold,
          'category': item.category,
          'is_active': item.isActive,
          'created_at': item.createdAt.toUtc().toIso8601String(),
          'updated_at': item.updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'customer':
        final customer = await db.customerById(event.entityId);
        if (customer == null) return;
        if (await _remoteIsNewer(client, 'customers', customer.id, customer.updatedAt, businessId)) {
          await _pullCustomer(customer.id, businessId, client);
          return;
        }
        await client.from('customers').upsert({
          'id': customer.id,
          'business_id': businessId,
          'name': customer.name,
          'phone': customer.phone,
          'email': customer.email,
          'address': customer.address,
          'notes': customer.notes,
          'created_at': customer.createdAt.toUtc().toIso8601String(),
          'updated_at': customer.updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'invoice':
        final invoice = await db.invoiceById(event.entityId);
        if (invoice == null) return;
        if (await _remoteIsNewer(client, 'invoices', invoice.id, invoice.updatedAt, businessId)) {
          await _pullInvoice(invoice.id, businessId, client);
          return;
        }
        await client.from('invoices').upsert({
          'id': invoice.id,
          'business_id': businessId,
          'invoice_number': invoice.invoiceNumber,
          'customer_id': invoice.customerId,
          'subtotal_minor': invoice.subtotalMinor,
          'discount_minor': invoice.discountMinor,
          'tax_minor': invoice.taxMinor,
          'cgst_minor': invoice.cgstMinor,
          'sgst_minor': invoice.sgstMinor,
          'igst_minor': invoice.igstMinor,
          'gst_supply_type': invoice.gstSupplyType,
          'total_minor': invoice.totalMinor,
          'paid_minor': invoice.paidMinor,
          'payment_status': invoice.paymentStatus,
          'payment_method': invoice.paymentMethod,
          'status': invoice.status,
          'notes': invoice.notes,
          'created_at': invoice.createdAt.toUtc().toIso8601String(),
          'updated_at': invoice.updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');

        final items = await db.invoiceItemsFor(invoice.id);
        for (final item in items) {
          await client.from('invoice_items').upsert({
            'id': item.id,
            'business_id': businessId,
            'invoice_id': item.invoiceId,
            'item_id': item.itemId,
            'item_name_snapshot': item.itemNameSnapshot,
            'sku_snapshot': item.skuSnapshot ?? '',
            'hsn_sac_snapshot': item.hsnSacSnapshot,
            'quantity': item.quantity,
            'unit_price_minor': item.unitPriceMinor,
            'unit_cost_minor': item.unitCostMinor,
            'line_discount_minor': item.lineDiscountMinor,
            'cgst_minor': item.cgstMinor,
            'sgst_minor': item.sgstMinor,
            'igst_minor': item.igstMinor,
            'tax_rate': item.taxRate,
            'tax_minor': item.taxMinor,
            'line_total_minor': item.lineTotalMinor,
          }, onConflict: 'id');
        }
        break;

      case 'supplier':
        final supplier = await (db.select(db.suppliers)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (supplier == null) return;
        await client.from('suppliers').upsert({
          'id': supplier.id,
          'business_id': businessId,
          'name': supplier.name,
          'phone': supplier.phone,
          'email': supplier.email,
          'gstin': supplier.gstin,
          'address': supplier.address,
          'created_at': supplier.createdAt.toUtc().toIso8601String(),
          'updated_at': supplier.updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'purchase':
        final purchase = await (db.select(db.purchases)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (purchase == null) return;
        final supplier = await (db.select(db.suppliers)
              ..where((t) => t.id.equals(purchase.supplierId)))
            .getSingleOrNull();
        if (supplier == null) throw StateError('Purchase supplier is missing locally.');
        await client.from('suppliers').upsert({
          'id': supplier.id,
          'business_id': businessId,
          'name': supplier.name,
          'phone': supplier.phone,
          'email': supplier.email,
          'gstin': supplier.gstin,
          'address': supplier.address,
          'created_at': supplier.createdAt.toUtc().toIso8601String(),
          'updated_at': supplier.updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        await client.from('purchases').upsert({
          'id': purchase.id,
          'business_id': businessId,
          'purchase_number': purchase.purchaseNumber,
          'supplier_id': purchase.supplierId,
          'subtotal_minor': purchase.subtotalMinor,
          'discount_minor': purchase.discountMinor,
          'tax_minor': purchase.taxMinor,
          'total_minor': purchase.totalMinor,
          'paid_minor': purchase.paidMinor,
          'payment_status': purchase.paymentStatus,
          'notes': purchase.notes,
          'created_at': purchase.createdAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        final purchaseLines = await (db.select(db.purchaseItems)
              ..where((t) => t.purchaseId.equals(purchase.id)))
            .get();
        for (final line in purchaseLines) {
          await client.from('purchase_items').upsert({
            'id': line.id,
            'business_id': businessId,
            'purchase_id': line.purchaseId,
            'item_id': line.itemId,
            'item_name_snapshot': line.itemNameSnapshot,
            'quantity': line.quantity,
            'unit_cost_minor': line.unitCostMinor,
            'tax_rate': line.taxRate,
            'tax_minor': line.taxMinor,
            'line_total_minor': line.lineTotalMinor,
          }, onConflict: 'id');
        }
        final batches = await (db.select(db.stockBatches)
              ..where((t) => t.purchaseItemId.isIn(purchaseLines.map((x) => x.id).toList())))
            .get();
        for (final batch in batches) {
          await client.from('stock_batches').upsert({
            'id': batch.id,
            'business_id': businessId,
            'item_id': batch.itemId,
            'purchase_item_id': batch.purchaseItemId,
            'quantity': batch.quantity,
            'expiry_date': batch.expiryDate?.toUtc().toIso8601String(),
            'created_at': batch.createdAt.toUtc().toIso8601String(),
          }, onConflict: 'id');
        }
        break;

      case 'stockBatch':
        final batch = await (db.select(db.stockBatches)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (batch == null) return;
        await client.from('stock_batches').upsert({
          'id': batch.id,
          'business_id': businessId,
          'item_id': batch.itemId,
          'purchase_item_id': batch.purchaseItemId,
          'quantity': batch.quantity,
          'expiry_date': batch.expiryDate?.toUtc().toIso8601String(),
          'created_at': batch.createdAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'expense':
        final expense = await (db.select(db.expenses)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (expense == null) return;
        await client.from('expenses').upsert({
          'id': expense.id,
          'business_id': businessId,
          'category': expense.category,
          'description': expense.description,
          'amount_minor': expense.amountMinor,
          'payment_method': expense.paymentMethod,
          'incurred_at': expense.incurredAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'stockAdjustment':
        final adjustment = await (db.select(db.stockAdjustments)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (adjustment == null) return;
        await client.from('stock_adjustments').upsert({
          'id': adjustment.id,
          'business_id': businessId,
          'item_id': adjustment.itemId,
          'quantity_delta': adjustment.quantityDelta,
          'reason': adjustment.reason,
          'created_at': adjustment.createdAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'customerPayment':
        final payment = await (db.select(db.customerPayments)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (payment == null) return;
        final customer = await db.customerById(payment.customerId);
        if (customer == null) throw StateError('Payment customer is missing locally.');
        await client.from('customers').upsert({
          'id': customer.id, 'business_id': businessId, 'name': customer.name,
          'phone': customer.phone, 'email': customer.email, 'address': customer.address,
          'notes': customer.notes, 'created_at': customer.createdAt.toUtc().toIso8601String(),
          'updated_at': customer.updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        if (payment.invoiceId != null) {
          final invoice = await db.invoiceById(payment.invoiceId!);
          if (invoice == null) throw StateError('Payment invoice is missing locally.');
          await client.from('invoices').upsert({
            'id': invoice.id, 'business_id': businessId, 'invoice_number': invoice.invoiceNumber,
            'customer_id': invoice.customerId, 'subtotal_minor': invoice.subtotalMinor,
            'discount_minor': invoice.discountMinor, 'tax_minor': invoice.taxMinor,
            'cgst_minor': invoice.cgstMinor, 'sgst_minor': invoice.sgstMinor,
            'igst_minor': invoice.igstMinor, 'gst_supply_type': invoice.gstSupplyType,
            'total_minor': invoice.totalMinor, 'paid_minor': invoice.paidMinor,
            'payment_status': invoice.paymentStatus, 'payment_method': invoice.paymentMethod,
            'status': invoice.status, 'notes': invoice.notes,
            'created_at': invoice.createdAt.toUtc().toIso8601String(),
            'updated_at': invoice.updatedAt.toUtc().toIso8601String(),
          }, onConflict: 'id');
        }
        await client.from('customer_payments').upsert({
          'id': payment.id, 'business_id': businessId, 'customer_id': payment.customerId,
          'invoice_id': payment.invoiceId, 'amount_minor': payment.amountMinor,
          'payment_method': payment.paymentMethod, 'reference': payment.reference,
          'notes': payment.notes, 'received_at': payment.receivedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'supplierPayment':
        final payment = await (db.select(db.supplierPayments)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (payment == null) return;
        final supplier = await (db.select(db.suppliers)
              ..where((t) => t.id.equals(payment.supplierId)))
            .getSingleOrNull();
        if (supplier == null) throw StateError('Payment supplier is missing locally.');
        await client.from('suppliers').upsert({
          'id': supplier.id, 'business_id': businessId, 'name': supplier.name,
          'phone': supplier.phone, 'email': supplier.email, 'gstin': supplier.gstin,
          'address': supplier.address, 'created_at': supplier.createdAt.toUtc().toIso8601String(),
          'updated_at': supplier.updatedAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        if (payment.purchaseId != null) {
          final purchase = await (db.select(db.purchases)
                ..where((t) => t.id.equals(payment.purchaseId!)))
              .getSingleOrNull();
          if (purchase != null) {
            await client.from('purchases').upsert({
              'id': purchase.id, 'business_id': businessId,
              'purchase_number': purchase.purchaseNumber, 'supplier_id': purchase.supplierId,
              'subtotal_minor': purchase.subtotalMinor, 'discount_minor': purchase.discountMinor,
              'tax_minor': purchase.taxMinor, 'total_minor': purchase.totalMinor,
              'paid_minor': purchase.paidMinor, 'payment_status': purchase.paymentStatus,
              'notes': purchase.notes, 'created_at': purchase.createdAt.toUtc().toIso8601String(),
            }, onConflict: 'id');
          }
        }
        await client.from('supplier_payments').upsert({
          'id': payment.id, 'business_id': businessId, 'supplier_id': payment.supplierId,
          'purchase_id': payment.purchaseId, 'amount_minor': payment.amountMinor,
          'payment_method': payment.paymentMethod, 'reference': payment.reference,
          'notes': payment.notes, 'paid_at': payment.paidAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        break;

      case 'salesReturn':
        final returned = await (db.select(db.salesReturns)
              ..where((t) => t.id.equals(event.entityId)))
            .getSingleOrNull();
        if (returned == null) return;
        await client.from('sales_returns').upsert({
          'id': returned.id, 'business_id': businessId, 'return_number': returned.returnNumber,
          'invoice_id': returned.invoiceId, 'customer_id': returned.customerId,
          'subtotal_minor': returned.subtotalMinor, 'tax_minor': returned.taxMinor,
          'total_minor': returned.totalMinor, 'refund_method': returned.refundMethod,
          'notes': returned.notes, 'created_at': returned.createdAt.toUtc().toIso8601String(),
        }, onConflict: 'id');
        final returnLines = await (db.select(db.salesReturnItems)
              ..where((t) => t.returnId.equals(returned.id)))
            .get();
        for (final line in returnLines) {
          await client.from('sales_return_items').upsert({
            'id': line.id, 'business_id': businessId, 'return_id': line.returnId,
            'invoice_item_id': line.invoiceItemId, 'item_id': line.itemId,
            'item_name_snapshot': line.itemNameSnapshot, 'quantity': line.quantity,
            'unit_price_minor': line.unitPriceMinor, 'tax_rate': line.taxRate,
            'tax_minor': line.taxMinor, 'line_total_minor': line.lineTotalMinor,
          }, onConflict: 'id');
        }
        break;

      default:
        // Never acknowledge an event that this client does not understand.
        throw StateError('Unsupported sync entity type: ${event.entityType}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllBusinessRows(
    SupabaseClient client,
    String table,
    String businessId,
  ) async {
    const pageSize = 500;
    var offset = 0;
    final rows = <Map<String, dynamic>>[];
    while (true) {
      final page = await client
          .from(table)
          .select()
          .eq('business_id', businessId)
          .order('id')
          .range(offset, offset + pageSize - 1);
      final batch = List<Map<String, dynamic>>.from(page);
      rows.addAll(batch);
      if (batch.length < pageSize) break;
      offset += pageSize;
    }
    return rows;
  }

  Future<void> _pullLatest(String businessId, SupabaseClient client) async {
    final itemRows = await _fetchAllBusinessRows(client, 'items', businessId);
    for (final row in itemRows) {
      await _applyRemoteItem(row);
    }

    final customerRows = await _fetchAllBusinessRows(client, 'customers', businessId);
    for (final row in customerRows) {
      await _applyRemoteCustomer(row);
    }

    final invoiceRows = await _fetchAllBusinessRows(client, 'invoices', businessId);
    for (final row in invoiceRows) {
      await _applyRemoteInvoice(row);
    }

    final invoiceItemRows = await _fetchAllBusinessRows(client, 'invoice_items', businessId);
    for (final row in invoiceItemRows) {
      await _applyRemoteInvoiceItem(row);
    }

    for (final row in await _fetchAllBusinessRows(client, 'suppliers', businessId)) {
      await _applyRemoteSupplier(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'purchases', businessId)) {
      await _applyRemotePurchase(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'purchase_items', businessId)) {
      await _applyRemotePurchaseItem(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'expenses', businessId)) {
      await _applyRemoteExpense(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'stock_adjustments', businessId)) {
      await _applyRemoteStockAdjustment(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'stock_batches', businessId)) {
      await _applyRemoteStockBatch(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'customer_payments', businessId)) {
      await _applyRemoteCustomerPayment(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'supplier_payments', businessId)) {
      await _applyRemoteSupplierPayment(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'sales_returns', businessId)) {
      await _applyRemoteSalesReturn(row);
    }
    for (final row in await _fetchAllBusinessRows(client, 'sales_return_items', businessId)) {
      await _applyRemoteSalesReturnItem(row);
    }
  }

  Future<void> _pullItem(String id, String businessId, SupabaseClient client) async {
    final row = await client.from('items').select().eq('id', id).eq('business_id', businessId).maybeSingle();
    if (row != null) await _applyRemoteItem(row);
  }

  Future<void> _pullCustomer(String id, String businessId, SupabaseClient client) async {
    final row = await client.from('customers').select().eq('id', id).eq('business_id', businessId).maybeSingle();
    if (row != null) await _applyRemoteCustomer(row);
  }

  Future<void> _pullInvoice(String id, String businessId, SupabaseClient client) async {
    final row = await client.from('invoices').select().eq('id', id).eq('business_id', businessId).maybeSingle();
    if (row != null) await _applyRemoteInvoice(row);
    final itemRows = await client.from('invoice_items').select().eq('invoice_id', id).eq('business_id', businessId);
    for (final item in itemRows) {
      await _applyRemoteInvoiceItem(item);
    }
  }

  DateTime _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();

  Future<void> _applyRemoteItem(Map<String, dynamic> row) async {
    await db.into(db.items).insertOnConflictUpdate(ItemsCompanion(
      id: Value(row['id'].toString()),
      sku: Value(row['sku']?.toString()),
      name: Value(row['name'].toString()),
      description: Value(row['description']?.toString()),
      barcode: Value(row['barcode']?.toString()),
      hsnSac: Value(row['hsn_sac']?.toString()),
      priceMinor: Value((row['price_minor'] as num?)?.toInt() ?? 0),
      costMinor: Value((row['cost_minor'] as num?)?.toInt() ?? 0),
      taxRate: Value((row['tax_rate'] as num?)?.toDouble() ?? 0),
      stockQuantity: Value((row['stock_quantity'] as num?)?.toInt() ?? 0),
      lowStockThreshold: Value((row['low_stock_threshold'] as num?)?.toInt() ?? 0),
      category: Value(row['category']?.toString()),
      isActive: Value(row['is_active'] == true),
      createdAt: Value(_date(row['created_at'])),
      updatedAt: Value(_date(row['updated_at'])),
      syncStatus: const Value('synced'),
      lastSyncedAt: Value(DateTime.now()),
    ));
  }

  Future<void> _applyRemoteCustomer(Map<String, dynamic> row) async {
    await db.into(db.customers).insertOnConflictUpdate(CustomersCompanion(
      id: Value(row['id'].toString()),
      name: Value(row['name'].toString()),
      phone: Value(row['phone']?.toString()),
      email: Value(row['email']?.toString()),
      address: Value(row['address']?.toString()),
      notes: Value(row['notes']?.toString()),
      createdAt: Value(_date(row['created_at'])),
      updatedAt: Value(_date(row['updated_at'])),
      syncStatus: const Value('synced'),
      lastSyncedAt: Value(DateTime.now()),
    ));
  }

  Future<void> _applyRemoteInvoice(Map<String, dynamic> row) async {
    await db.into(db.invoices).insertOnConflictUpdate(InvoicesCompanion(
      id: Value(row['id'].toString()),
      invoiceNumber: Value(row['invoice_number'].toString()),
      customerId: Value(row['customer_id']?.toString()),
      subtotalMinor: Value((row['subtotal_minor'] as num?)?.toInt() ?? 0),
      discountMinor: Value((row['discount_minor'] as num?)?.toInt() ?? 0),
      taxMinor: Value((row['tax_minor'] as num?)?.toInt() ?? 0),
      cgstMinor: Value((row['cgst_minor'] as num?)?.toInt() ?? 0),
      sgstMinor: Value((row['sgst_minor'] as num?)?.toInt() ?? 0),
      igstMinor: Value((row['igst_minor'] as num?)?.toInt() ?? 0),
      gstSupplyType: Value(row['gst_supply_type']?.toString() ?? 'unknown'),
      totalMinor: Value((row['total_minor'] as num?)?.toInt() ?? 0),
      paidMinor: Value((row['paid_minor'] as num?)?.toInt() ?? 0),
      paymentStatus: Value(row['payment_status']?.toString() ?? 'paid'),
      paymentMethod: Value(row['payment_method'].toString()),
      status: Value(row['status']?.toString() ?? 'completed'),
      notes: Value(row['notes']?.toString()),
      createdAt: Value(_date(row['created_at'])),
      updatedAt: Value(_date(row['updated_at'])),
      syncStatus: const Value('synced'),
      lastSyncedAt: Value(DateTime.now()),
    ));
  }

  Future<void> _applyRemoteInvoiceItem(Map<String, dynamic> row) async {
    await db.into(db.invoiceItems).insertOnConflictUpdate(InvoiceItemsCompanion(
      id: Value(row['id'].toString()),
      invoiceId: Value(row['invoice_id'].toString()),
      itemId: Value(row['item_id'].toString()),
      itemNameSnapshot: Value(row['item_name_snapshot'].toString()),
      skuSnapshot: Value(row['sku_snapshot']?.toString()),
      hsnSacSnapshot: Value(row['hsn_sac_snapshot']?.toString()),
      quantity: Value((row['quantity'] as num?)?.toInt() ?? 0),
      unitPriceMinor: Value((row['unit_price_minor'] as num?)?.toInt() ?? 0),
      unitCostMinor: Value((row['unit_cost_minor'] as num?)?.toInt() ?? 0),
      lineDiscountMinor: Value((row['line_discount_minor'] as num?)?.toInt() ?? 0),
      cgstMinor: Value((row['cgst_minor'] as num?)?.toInt() ?? 0),
      sgstMinor: Value((row['sgst_minor'] as num?)?.toInt() ?? 0),
      igstMinor: Value((row['igst_minor'] as num?)?.toInt() ?? 0),
      taxRate: Value((row['tax_rate'] as num?)?.toDouble() ?? 0),
      taxMinor: Value((row['tax_minor'] as num?)?.toInt() ?? 0),
      lineTotalMinor: Value((row['line_total_minor'] as num?)?.toInt() ?? 0),
    ));
  }

  Future<void> _applyRemoteSupplier(Map<String, dynamic> row) async {
    await db.into(db.suppliers).insertOnConflictUpdate(SuppliersCompanion(
      id: Value(row['id'].toString()),
      name: Value(row['name'].toString()),
      phone: Value(row['phone']?.toString()),
      email: Value(row['email']?.toString()),
      gstin: Value(row['gstin']?.toString()),
      address: Value(row['address']?.toString()),
      createdAt: Value(_date(row['created_at'])),
      updatedAt: Value(_date(row['updated_at'])),
    ));
  }

  Future<void> _applyRemotePurchase(Map<String, dynamic> row) async {
    await db.into(db.purchases).insertOnConflictUpdate(PurchasesCompanion(
      id: Value(row['id'].toString()),
      purchaseNumber: Value(row['purchase_number'].toString()),
      supplierId: Value(row['supplier_id'].toString()),
      subtotalMinor: Value((row['subtotal_minor'] as num?)?.toInt() ?? 0),
      discountMinor: Value((row['discount_minor'] as num?)?.toInt() ?? 0),
      taxMinor: Value((row['tax_minor'] as num?)?.toInt() ?? 0),
      totalMinor: Value((row['total_minor'] as num?)?.toInt() ?? 0),
      paidMinor: Value((row['paid_minor'] as num?)?.toInt() ?? 0),
      paymentStatus: Value(row['payment_status']?.toString() ?? 'unpaid'),
      notes: Value(row['notes']?.toString()),
      createdAt: Value(_date(row['created_at'])),
    ));
  }

  Future<void> _applyRemotePurchaseItem(Map<String, dynamic> row) async {
    await db.into(db.purchaseItems).insertOnConflictUpdate(PurchaseItemsCompanion(
      id: Value(row['id'].toString()),
      purchaseId: Value(row['purchase_id'].toString()),
      itemId: Value(row['item_id'].toString()),
      itemNameSnapshot: Value(row['item_name_snapshot'].toString()),
      quantity: Value((row['quantity'] as num?)?.toInt() ?? 0),
      unitCostMinor: Value((row['unit_cost_minor'] as num?)?.toInt() ?? 0),
      taxRate: Value((row['tax_rate'] as num?)?.toDouble() ?? 0),
      taxMinor: Value((row['tax_minor'] as num?)?.toInt() ?? 0),
      lineTotalMinor: Value((row['line_total_minor'] as num?)?.toInt() ?? 0),
    ));
  }

  Future<void> _applyRemoteExpense(Map<String, dynamic> row) async {
    await db.into(db.expenses).insertOnConflictUpdate(ExpensesCompanion(
      id: Value(row['id'].toString()),
      category: Value(row['category'].toString()),
      description: Value(row['description']?.toString()),
      amountMinor: Value((row['amount_minor'] as num?)?.toInt() ?? 0),
      paymentMethod: Value(row['payment_method']?.toString() ?? 'cash'),
      incurredAt: Value(_date(row['incurred_at'])),
    ));
  }

  Future<void> _applyRemoteStockAdjustment(Map<String, dynamic> row) async {
    await db.into(db.stockAdjustments).insertOnConflictUpdate(StockAdjustmentsCompanion(
      id: Value(row['id'].toString()),
      itemId: Value(row['item_id'].toString()),
      quantityDelta: Value((row['quantity_delta'] as num?)?.toInt() ?? 0),
      reason: Value(row['reason'].toString()),
      createdAt: Value(_date(row['created_at'])),
    ));
  }

  Future<void> _applyRemoteStockBatch(Map<String, dynamic> row) async {
    await db.into(db.stockBatches).insertOnConflictUpdate(StockBatchesCompanion(
      id: Value(row['id'].toString()),
      itemId: Value(row['item_id'].toString()),
      purchaseItemId: Value(row['purchase_item_id']?.toString()),
      quantity: Value((row['quantity'] as num?)?.toInt() ?? 0),
      expiryDate: Value(DateTime.tryParse(row['expiry_date']?.toString() ?? '')?.toLocal()),
      createdAt: Value(_date(row['created_at'])),
    ));
  }

  Future<void> _applyRemoteCustomerPayment(Map<String, dynamic> row) async {
    await db.into(db.customerPayments).insertOnConflictUpdate(CustomerPaymentsCompanion(
      id: Value(row['id'].toString()),
      customerId: Value(row['customer_id'].toString()),
      invoiceId: Value(row['invoice_id']?.toString()),
      amountMinor: Value((row['amount_minor'] as num?)?.toInt() ?? 0),
      paymentMethod: Value(row['payment_method'].toString()),
      reference: Value(row['reference']?.toString()),
      notes: Value(row['notes']?.toString()),
      receivedAt: Value(_date(row['received_at'])),
    ));
  }

  Future<void> _applyRemoteSupplierPayment(Map<String, dynamic> row) async {
    await db.into(db.supplierPayments).insertOnConflictUpdate(SupplierPaymentsCompanion(
      id: Value(row['id'].toString()),
      supplierId: Value(row['supplier_id'].toString()),
      purchaseId: Value(row['purchase_id']?.toString()),
      amountMinor: Value((row['amount_minor'] as num?)?.toInt() ?? 0),
      paymentMethod: Value(row['payment_method'].toString()),
      reference: Value(row['reference']?.toString()),
      notes: Value(row['notes']?.toString()),
      paidAt: Value(_date(row['paid_at'])),
    ));
  }

  Future<void> _applyRemoteSalesReturn(Map<String, dynamic> row) async {
    await db.into(db.salesReturns).insertOnConflictUpdate(SalesReturnsCompanion(
      id: Value(row['id'].toString()),
      returnNumber: Value(row['return_number'].toString()),
      invoiceId: Value(row['invoice_id'].toString()),
      customerId: Value(row['customer_id']?.toString()),
      subtotalMinor: Value((row['subtotal_minor'] as num?)?.toInt() ?? 0),
      taxMinor: Value((row['tax_minor'] as num?)?.toInt() ?? 0),
      totalMinor: Value((row['total_minor'] as num?)?.toInt() ?? 0),
      refundMethod: Value(row['refund_method'].toString()),
      notes: Value(row['notes']?.toString()),
      createdAt: Value(_date(row['created_at'])),
    ));
  }

  Future<void> _applyRemoteSalesReturnItem(Map<String, dynamic> row) async {
    await db.into(db.salesReturnItems).insertOnConflictUpdate(SalesReturnItemsCompanion(
      id: Value(row['id'].toString()),
      returnId: Value(row['return_id'].toString()),
      invoiceItemId: Value(row['invoice_item_id'].toString()),
      itemId: Value(row['item_id'].toString()),
      itemNameSnapshot: Value(row['item_name_snapshot'].toString()),
      quantity: Value((row['quantity'] as num?)?.toInt() ?? 0),
      unitPriceMinor: Value((row['unit_price_minor'] as num?)?.toInt() ?? 0),
      taxRate: Value((row['tax_rate'] as num?)?.toDouble() ?? 0),
      taxMinor: Value((row['tax_minor'] as num?)?.toInt() ?? 0),
      lineTotalMinor: Value((row['line_total_minor'] as num?)?.toInt() ?? 0),
    ));
  }

  void dispose() {
    _subscription.cancel();
    _authSubscription?.cancel();
    _timer?.cancel();
  }
}
