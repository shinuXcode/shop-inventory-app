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
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
  }

  final AppDatabase db;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  late final Timer _timer;
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
          'total_minor': invoice.totalMinor,
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
            'quantity': item.quantity,
            'unit_price_minor': item.unitPriceMinor,
            'tax_rate': item.taxRate,
            'tax_minor': item.taxMinor,
            'line_total_minor': item.lineTotalMinor,
          }, onConflict: 'id');
        }
        break;

      default:
        break;
    }
  }

  Future<void> _pullLatest(String businessId, SupabaseClient client) async {
    final itemRows = await client.from('items').select().eq('business_id', businessId);
    for (final row in itemRows) {
      await _applyRemoteItem(row);
    }

    final customerRows = await client.from('customers').select().eq('business_id', businessId);
    for (final row in customerRows) {
      await _applyRemoteCustomer(row);
    }

    final invoiceRows = await client.from('invoices').select().eq('business_id', businessId);
    for (final row in invoiceRows) {
      await _applyRemoteInvoice(row);
    }

    final invoiceItemRows = await client.from('invoice_items').select().eq('business_id', businessId);
    for (final row in invoiceItemRows) {
      await _applyRemoteInvoiceItem(row);
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
      totalMinor: Value((row['total_minor'] as num?)?.toInt() ?? 0),
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
      quantity: Value((row['quantity'] as num?)?.toInt() ?? 0),
      unitPriceMinor: Value((row['unit_price_minor'] as num?)?.toInt() ?? 0),
      taxRate: Value((row['tax_rate'] as num?)?.toDouble() ?? 0),
      taxMinor: Value((row['tax_minor'] as num?)?.toInt() ?? 0),
      lineTotalMinor: Value((row['line_total_minor'] as num?)?.toInt() ?? 0),
    ));
  }

  void dispose() {
    _subscription.cancel();
    _timer.cancel();
  }
}
