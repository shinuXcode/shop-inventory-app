import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:sbill/core/data/data_transfer_service.dart';
import 'package:sbill/core/database/app_database.dart';

void main() {
  group('SBILL data transfer', () {
    test('parses quoted CSV and infers products', () {
      const csv = '"name","price","stock"\n"Tea, Mint","12.50","3"\n';
      final preview = DataTransferService.parseFile(
        'products.csv',
        utf8.encode(csv),
      );

      expect(preview.isValid, isTrue);
      expect(preview.kind, 'products');
      expect(preview.rows, hasLength(1));
      expect(preview.rows.single['name'], 'Tea, Mint');
      expect(preview.rows.single['price'], '12.50');
      expect(preview.rows.single['stock'], '3');
    });

    test('imports products and deduplicates by SKU', () async {
      final db = AppDatabase.forTesting();
      addTearDown(db.close);

      final first = await db.importProductRows([
        {
          'name': 'Cable',
          'sku': 'CB-01',
          'price': '99',
          'tax': '18',
          'stock': '10',
        },
      ]);
      final second = await db.importProductRows([
        {
          'name': 'Cable Updated',
          'sku': 'CB-01',
          'price': '109',
          'tax': '18',
          'stock': '12',
        },
      ]);

      expect(first, 1);
      expect(second, 1);
      final rows = await db.searchItems('CB-01');
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Cable Updated');
      expect(rows.single.priceMinor, 10900);
      expect(rows.single.stockQuantity, 12);
    });

    test('customer stats include purchases and credit invoices', () async {
      final db = AppDatabase.forTesting();
      addTearDown(db.close);
      final now = DateTime.now();

      await db.saveCustomer(CustomersCompanion.insert(
        id: 'customer-1',
        name: 'Test Customer',
        createdAt: now,
        updatedAt: now,
      ));

      await db.into(db.invoices).insert(InvoicesCompanion.insert(
        id: 'invoice-1',
        invoiceNumber: 'INV-1',
        customerId: const Value('customer-1'),
        subtotalMinor: 10000,
        totalMinor: 10000,
        paymentMethod: 'cash',
        createdAt: now,
        updatedAt: now,
      ));
      await db.into(db.invoices).insert(InvoicesCompanion.insert(
        id: 'invoice-2',
        invoiceNumber: 'INV-2',
        customerId: const Value('customer-1'),
        subtotalMinor: 5000,
        totalMinor: 5000,
        paymentMethod: 'credit',
        createdAt: now,
        updatedAt: now,
      ));

      final stats = await db.customerStats('customer-1');
      expect(stats.invoiceCount, 2);
      expect(stats.totalMinor, 15000);
      expect(stats.creditMinor, 5000);
    });

    test('backup snapshot is portable JSON data', () async {
      final db = AppDatabase.forTesting();
      addTearDown(db.close);

      final snapshot = await db.exportSnapshot();
      expect(snapshot['format'], 'sbill-backup-v1');
      expect(snapshot['items'], isList);
      expect(snapshot['customers'], isList);
      expect(snapshot['invoices'], isList);
      expect(jsonEncode(snapshot), isNotEmpty);
    });
  });
}
