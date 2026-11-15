import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sbill/core/database/app_database.dart';

void main() {
  group('SBILL accounting ledgers', () {
    test('customer receipts update invoice balance and reject overpayment', () async {
      final db = AppDatabase.forTesting();
      addTearDown(db.close);
      final now = DateTime(2026, 11, 15);

      await db.saveCustomer(CustomersCompanion.insert(
        id: 'customer-ledger',
        name: 'Ledger Customer',
        createdAt: now,
        updatedAt: now,
      ));
      await db.into(db.invoices).insert(InvoicesCompanion.insert(
        id: 'invoice-ledger',
        invoiceNumber: 'INV-LEDGER',
        customerId: const Value('customer-ledger'),
        subtotalMinor: 10000,
        totalMinor: 10000,
        paidMinor: const Value(0),
        paymentStatus: const Value('unpaid'),
        paymentMethod: 'credit',
        createdAt: now,
        updatedAt: now,
      ));

      final balance = await db.recordCustomerPayment(
        id: 'customer-payment-1',
        invoiceId: 'invoice-ledger',
        amountMinor: 4000,
        paymentMethod: 'upi',
        reference: 'UPI-REF-1',
      );

      expect(balance, 6000);
      final invoice = await db.invoiceById('invoice-ledger');
      expect(invoice?.paidMinor, 4000);
      expect(invoice?.paymentStatus, 'partial');
      expect(await db.customerPaymentsFor('customer-ledger'), hasLength(1));
      expect((await db.customerStats('customer-ledger')).creditMinor, 6000);

      await expectLater(
        db.recordCustomerPayment(
          id: 'customer-payment-over',
          invoiceId: 'invoice-ledger',
          amountMinor: 6001,
          paymentMethod: 'cash',
        ),
        throwsArgumentError,
      );
      expect((await db.customerPaymentsFor('customer-ledger')), hasLength(1));
    });

    test('supplier payment ledger updates purchase outstanding', () async {
      final db = AppDatabase.forTesting();
      addTearDown(db.close);
      final now = DateTime(2026, 11, 15);

      await db.saveSupplier(SuppliersCompanion.insert(
        id: 'supplier-ledger',
        name: 'Ledger Supplier',
        createdAt: now,
        updatedAt: now,
      ));
      await db.into(db.purchases).insert(PurchasesCompanion.insert(
        id: 'purchase-ledger',
        purchaseNumber: 'PUR-LEDGER',
        supplierId: 'supplier-ledger',
        subtotalMinor: 10000,
        totalMinor: 10000,
        paidMinor: const Value(2000),
        paymentStatus: const Value('partial'),
        createdAt: now,
      ));

      await db.recordSupplierPayment(
        id: 'supplier-payment-1',
        purchaseId: 'purchase-ledger',
        amountMinor: 3000,
        paymentMethod: 'bank',
        reference: 'BANK-REF-1',
      );

      final purchase = await (db.select(db.purchases)
            ..where((row) => row.id.equals('purchase-ledger')))
          .getSingle();
      expect(purchase.paidMinor, 5000);
      expect(purchase.paymentStatus, 'partial');
      expect(await db.supplierOutstandingMinor('supplier-ledger'), 5000);
      expect(await db.supplierPaymentsFor('supplier-ledger'), hasLength(1));

      await expectLater(
        db.recordSupplierPayment(
          id: 'supplier-payment-over',
          purchaseId: 'purchase-ledger',
          amountMinor: 5001,
          paymentMethod: 'cash',
        ),
        throwsArgumentError,
      );
    });

    test('partial sales return is capped and restores stock transactionally', () async {
      final db = AppDatabase.forTesting();
      addTearDown(db.close);
      final now = DateTime(2026, 11, 15);

      await db.into(db.items).insert(ItemsCompanion.insert(
        id: 'return-item',
        name: 'Return Item',
        priceMinor: 1500,
        stockQuantity: const Value(0),
        createdAt: now,
        updatedAt: now,
      ));
      await db.into(db.invoices).insert(InvoicesCompanion.insert(
        id: 'return-invoice',
        invoiceNumber: 'INV-RETURN',
        subtotalMinor: 3000,
        totalMinor: 3000,
        paidMinor: const Value(3000),
        paymentStatus: const Value('paid'),
        paymentMethod: 'cash',
        createdAt: now,
        updatedAt: now,
      ));
      await db.into(db.invoiceItems).insert(InvoiceItemsCompanion.insert(
        id: 'return-line',
        invoiceId: 'return-invoice',
        itemId: 'return-item',
        itemNameSnapshot: 'Return Item',
        quantity: 2,
        unitPriceMinor: 1500,
        taxRate: 0,
        taxMinor: 0,
        lineTotalMinor: 3000,
      ));

      await db.recordSalesReturn(
        id: 'return-1',
        returnNumber: 'RET-1',
        invoiceId: 'return-invoice',
        lines: const [SalesReturnLine(invoiceItemId: 'return-line', quantity: 1)],
        refundMethod: 'cash',
      );

      expect((await db.select(db.items).getSingle()).stockQuantity, 1);
      expect(await db.salesReturnsForInvoice('return-invoice'), hasLength(1));
      expect((await db.select(db.salesReturnItems).getSingle()).quantity, 1);

      await expectLater(
        db.recordSalesReturn(
          id: 'return-2',
          returnNumber: 'RET-2',
          invoiceId: 'return-invoice',
          lines: const [SalesReturnLine(invoiceItemId: 'return-line', quantity: 2)],
          refundMethod: 'cash',
        ),
        throwsArgumentError,
      );
      expect((await db.select(db.items).getSingle()).stockQuantity, 1);
      expect(await db.salesReturnsForInvoice('return-invoice'), hasLength(1));
    });

    test('payment and sales return ledgers survive a JSON backup restore', () async {
      final source = AppDatabase.forTesting();
      final target = AppDatabase.forTesting();
      addTearDown(source.close);
      addTearDown(target.close);
      final now = DateTime(2026, 11, 15);

      await source.saveCustomer(CustomersCompanion.insert(
        id: 'backup-customer',
        name: 'Backup Customer',
        createdAt: now,
        updatedAt: now,
      ));
      await source.into(source.items).insert(ItemsCompanion.insert(
        id: 'backup-item',
        name: 'Backup Item',
        priceMinor: 3000,
        stockQuantity: const Value(0),
        createdAt: now,
        updatedAt: now,
      ));
      await source.into(source.invoices).insert(InvoicesCompanion.insert(
        id: 'backup-invoice',
        invoiceNumber: 'INV-BACKUP',
        customerId: const Value('backup-customer'),
        subtotalMinor: 6000,
        totalMinor: 6000,
        paidMinor: const Value(2000),
        paymentStatus: const Value('partial'),
        paymentMethod: 'credit',
        createdAt: now,
        updatedAt: now,
      ));
      await source.into(source.invoiceItems).insert(InvoiceItemsCompanion.insert(
        id: 'backup-line',
        invoiceId: 'backup-invoice',
        itemId: 'backup-item',
        itemNameSnapshot: 'Backup Item',
        quantity: 2,
        unitPriceMinor: 3000,
        taxRate: 0,
        taxMinor: 0,
        lineTotalMinor: 6000,
      ));
      await source.into(source.customerPayments).insert(CustomerPaymentsCompanion.insert(
        id: 'backup-receipt',
        customerId: 'backup-customer',
        invoiceId: const Value('backup-invoice'),
        amountMinor: 2000,
        paymentMethod: 'cash',
        receivedAt: now,
      ));
      await source.recordSalesReturn(
        id: 'backup-return',
        returnNumber: 'RET-BACKUP',
        invoiceId: 'backup-invoice',
        lines: const [SalesReturnLine(invoiceItemId: 'backup-line', quantity: 1)],
        refundMethod: 'cash',
      );

      final snapshot = await source.exportSnapshot();
      expect(snapshot['customerPayments'], hasLength(1));
      expect(snapshot['salesReturns'], hasLength(1));
      expect(snapshot['salesReturnItems'], hasLength(1));

      await target.importSnapshot(snapshot);

      expect(await target.customerPaymentsFor('backup-customer'), hasLength(1));
      expect(await target.salesReturnsForInvoice('backup-invoice'), hasLength(1));
      expect(await target.select(target.salesReturnItems).get(), hasLength(1));
      expect((await target.invoiceById('backup-invoice'))?.paidMinor, 2000);
      expect((await target.select(target.items).getSingle()).stockQuantity, 1);
    });
  });
}
