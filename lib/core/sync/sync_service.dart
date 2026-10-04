import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  }

  final AppDatabase db;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
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
      for (final event in queue) {
        try {
          await _push(event, businessId, client);
          await db.deleteSyncQueueEntry(event.id);
        } catch (e) {
          await db.failSyncQueueEntry(event.id, event.attempts, e.toString());
          lastError = e.toString();
          if (event.attempts >= 4) {
            continue;
          }
          break;
        }
      }
    } catch (e) {
      lastError = e.toString();
    } finally {
      syncing = false;
    }
  }

  Future<void> _push(SyncQueueData event, String businessId, SupabaseClient client) async {
    switch (event.entityType) {
      case 'item':
        final item = await (db.select(db.items)..where((t) => t.id.equals(event.entityId))).getSingleOrNull();
        if (item == null) return;
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

  void dispose() => _subscription.cancel();
}
