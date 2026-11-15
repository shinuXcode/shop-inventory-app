# SBILL Architecture

## Current architecture

- Flutter/Dart with Material 3 and Riverpod.
- Adaptive navigation for Dashboard, Billing, Inventory, Customers, Invoices, Purchases and Settings.
- Drift/SQLite is the local source of truth.
- Database schema version 6; versioned migrations add invoice payment state and auditable payment/return ledgers without dropping existing records.
- Local tables: Items, Customers, Invoices, InvoiceItems, SyncQueue, Suppliers, Purchases, PurchaseItems, Expenses, StockAdjustments, StockBatches, CustomerPayments, SupplierPayments, SalesReturns and SalesReturnItems.
- Billing uses integer minor units, per-invoice intra-state CGST/SGST or inter-state IGST selection, and a transactional stock update. The supply type is currently selected manually; automatic place-of-supply determination from GSTIN/state codes remains future work.
- Invoice lines retain historical item name, SKU, selling price, cost, discount, tax and line total snapshots.
- PDF generation supports multi-page A4 and 80 mm thermal layouts, print/share/save, configurable heading/terms/footer/logo/SKU.
- Optional Supabase Auth + PostgreSQL/RLS supports business, item, customer, invoice, supplier, purchase, expense, stock adjustment, expiry batch, payment ledger and sales return entities. Apply the updated supabase/schema.sql to the target Supabase project before enabling the extended sync paths.
- SQLite remains authoritative for offline checkout; sync is still best-effort and requires staging validation with two real devices and separate tenant accounts.

## Retail domain workflows

### Checkout

1. Aggregate cart quantities by item ID.
2. Re-read active items and current stock inside the SQLite transaction.
3. Calculate deterministic paise totals and discount allocation.
4. Insert invoice and historical line snapshots.
5. Conditionally decrement stock; abort the transaction if stock changed or is insufficient.
6. Consume tracked expiry batches in earliest-expiry order.
7. Enqueue item and invoice upserts.

### Payments and sales returns

- Invoice paid amount and payment status are stored separately from the original payment method.
- Customer receipts are ledger rows tied to a customer and optionally an invoice; recording a receipt rejects overpayment and updates the invoice balance in one transaction.
- Supplier payments are separate ledger rows tied to suppliers and optionally purchases; they update the purchase's paid amount and outstanding balance transactionally.
- Return headers and return lines point back to original invoice lines. Returned quantities cannot exceed the original sold quantity minus earlier returns.
- A return can restore quantity to stock inside the same transaction. Restocked goods are added as a fresh batch with no expiry date; staff must re-enter expiry information when it applies.
- Returns reduce accounts-receivable balances. Refund method and value remain visible in the return ledger.

### Purchasing and inventory

- Supplier records and purchase headers/lines are stored locally.
- Recording a purchase updates item cost and stock in the same transaction.
- Purchase batches may carry an expiry date.
- Stock adjustments require a reason and cannot create negative stock.
- Sales and negative adjustments consume tracked batches.
- Expenses are stored separately from sales.

### Reporting

- Daily sales and invoice counts use invoice records.
- Gross profit uses line-level historical cost and discount snapshots; older invoices created before the migration have a zero cost snapshot and must be treated as incomplete for historical margin analysis.
- Daily expenses are shown separately; do not interpret gross profit as net profit.

## PDF and character handling

- Currency in PDF output uses a printable currency code such as `INR`, avoiding the missing rupee glyph in built-in PDF fonts.
- A4 output uses a paginating MultiPage layout.
- Thermal output uses an 80 mm page format and paginates long receipts.
- Full Devanagari and other complex-script font embedding remains unverified and must be completed before claiming full multilingual invoice support.

## Important components

- `lib/core/database/app_database.dart`
- `lib/core/billing/billing_calculator.dart`
- `lib/core/billing/indian_gst.dart`
- `lib/core/pdf/invoice_pdf_service.dart`
- `lib/core/sync/sync_service.dart`
- `lib/features/purchases/purchases.dart`

## Migration and release rules

1. Never destructively reset an existing shop database.
2. Add every schema change through a versioned Drift migration.
3. Keep SQLite authoritative for offline checkout.
4. Never recompute historical invoice values from today's product price/cost.
5. Preserve invoice item snapshots when products are renamed or archived.
6. Validate migrations, transactions, backups, sync and all supported platform builds before release.
7. Treat Supabase staging multi-device tests as a mandatory release gate.
