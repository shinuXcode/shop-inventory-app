import 'package:flutter_test/flutter_test.dart';
import 'package:sbill/core/database/app_database.dart';
import 'package:sbill/core/pdf/invoice_pdf_service.dart';

void main() {
  final service = InvoicePdfService();

  Invoice invoice() => Invoice(
    id: 'invoice-pdf',
    invoiceNumber: 'INV-100',
    customerId: null,
    subtotalMinor: 10000,
    discountMinor: 500,
    taxMinor: 1710,
    totalMinor: 11210,
    paymentMethod: 'upi',
    status: 'completed',
    notes: null,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    syncStatus: 'pending',
    lastSyncedAt: null,
  );

  InvoiceItem item() => InvoiceItem(
    id: 'line-pdf',
    invoiceId: 'invoice-pdf',
    itemId: 'item-pdf',
    itemNameSnapshot: 'USB Cable',
    skuSnapshot: 'USB001',
    quantity: 1,
    unitPriceMinor: 10000,
    taxRate: 18,
    taxMinor: 1710,
    lineTotalMinor: 11210,
  );

  test('A4 invoice PDF is generated', () async {
    final bytes = await service.buildA4(
      invoice: invoice(),
      items: [item()],
      shopName: 'SBILL Shop',
      phone: '9999999999',
    );
    expect(bytes.length, greaterThan(100));
  });

  test('thermal invoice PDF is generated', () async {
    final bytes = await service.buildThermal(
      invoice: invoice(),
      items: [item()],
      shopName: 'SBILL Shop',
    );
    expect(bytes.length, greaterThan(100));
  });

  test('long A4 invoices paginate and export a valid PDF', () async {
    final manyItems = List.generate(120, (index) => InvoiceItem(
      id: 'line-$index',
      invoiceId: 'invoice-pdf',
      itemId: 'item-$index',
      itemNameSnapshot: 'Product $index',
      skuSnapshot: 'SKU-$index',
      quantity: 1,
      unitPriceMinor: 10000,
      taxRate: 18,
      taxMinor: 1800,
      lineTotalMinor: 11800,
    ));
    final bytes = await service.buildA4(
      invoice: invoice(),
      items: manyItems,
      shopName: 'SBILL Shop',
      footerText: 'Thank you - visit again.',
    );
    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(8)), startsWith('%PDF'));
  });

  test('unsupported complex-script text fails clearly instead of rendering corrupt glyphs', () async {
    await expectLater(
      service.buildA4(
        invoice: invoice(),
        items: [item()],
        shopName: 'दुकान',
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
