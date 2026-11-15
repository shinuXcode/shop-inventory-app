# SBILL

**Simple Billing. Smarter Business.**

Offline-first billing and shop management for Indian retail businesses on Android, Windows and macOS.

## Stack

Flutter, Dart, Material 3, Riverpod, Drift/SQLite, Supabase, PDF/printing.

## Current retail workflows

- POS checkout with exact barcode/SKU entry for USB/Bluetooth HID keyboard-wedge scanners.
- Integer-paise billing, discounts, HSN/SAC product codes, CGST/SGST or IGST calculation selected per invoice, and transactional stock deduction.
- Inventory, customer history and invoice management.
- Supplier directory, purchase entry, supplier outstanding balances and purchase history.
- Stock adjustments with an audit trail, expiry batches and expiry review.
- Expense entry, tracked gross-profit reporting for invoices with cost snapshots, and daily expense totals.
- Editable invoice heading, terms, footer, logo and SKU visibility.
- Multi-page A4 invoices and 80 mm thermal receipt PDFs.
- JSON backup/restore includes inventory, customers, invoices, suppliers, purchases, expenses, stock adjustments and expiry batches.

## Development

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
```

For a clean checkout, platform folders can be generated with:

```sh
flutter create --platforms=android,windows,macos .
```

Money is stored as integer minor units (paise). Checkout re-reads current inventory inside a SQLite transaction and uses conditional stock updates to prevent stale or concurrent carts from overselling. Historical invoice lines now retain cost and discount snapshots for more reliable profit reporting.

Apply `supabase/schema.sql` to configure the multi-tenant cloud schema, RLS and the authenticated `create_business` bootstrap RPC. Build with `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_PUBLISHABLE_KEY=...` to enable cloud features. Never ship a service-role key in the client.

## Important limitations

- Supplier, purchase, expense, stock-adjustment and expiry-batch history is local-first and included in JSON backups. These new records are not yet mirrored to Supabase. Item stock changes still enqueue the existing item sync event.
- HID barcode scanners are supported through keyboard input and an Enter suffix. Camera scanning and vendor-specific serial/Bluetooth protocols are not implemented.
- Printing uses the operating system's print dialog. Direct ESC/POS Bluetooth printing and cash-drawer kick/status commands are not implemented.
- The PDF service avoids the missing rupee glyph by printing currency codes (for example, INR). Unsupported Devanagari/non-Latin text is rejected with a clear error until Unicode font embedding is completed.
- The sync worker is foreground/timer based; OS-killed background sync is not claimed.

The product website is under `website/`.

## Release status

Do not declare the retail suite production-ready until the new Drift migrations, analyzer, tests, Android/Windows/macOS builds and the two-device Supabase staging scenarios all pass. See `docs/ARCHITECTURE.md`, `docs/RELEASE_CHECKLIST.md`, `docs/HARDWARE_SUPPORT.md` and `docs/SYNC_INTEGRATION_TEST_PLAN.md`.


## Accounting, returns and recovery

SBILL keeps money in integer paise and records customer receipts and supplier payments as individual ledger entries. Invoice and purchase balances are updated in the same SQLite transaction as their payment record; overpayments are rejected. Sales returns are tied to original invoice lines, limited to the unreturned quantity, and can restore returned quantities to stock in the same SQLite transaction. Returned stock is reintroduced as a new non-expiry batch unless expiry is managed separately.

JSON backups include customer receipts, supplier payments, sales return headers and return lines. Backup validation checks the new parent references before any rows are written. Drift schema version 6 adds these ledgers and invoice payment state without dropping earlier data.

The updated `supabase/schema.sql` adds business-scoped tables and row-level security policies for suppliers, purchases, expenses, stock adjustments, expiry batches, payment ledgers and sales returns. Run the complete SQL file in the Supabase SQL editor before enabling these sync entities in an existing cloud workspace. Local SQLite remains the source of truth; test the migration in a staging project before production use.

## Android release safety

The Android production release workflow is manual and fail-closed. It requires the intended full application ID, an existing keystore and passwords supplied as GitHub Actions secrets, plus the expected signing-certificate SHA-256 fingerprint. It signs the APK, verifies the signature and package ID, generates `latest.json` with the APK checksum and publishes the APK and metadata as a GitHub Release.

The repository does not hard-code an application ID or generate a production signing key. Use the identity and keystore from an existing production installation if one exists. A default CI APK is not evidence of update compatibility. See `docs/IMPLEMENTATION_STATUS.md`.
