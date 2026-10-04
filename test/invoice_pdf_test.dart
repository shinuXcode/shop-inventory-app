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
}
