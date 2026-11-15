# SBILL Release Checklist

## Implemented in the integrated SBILL system change (CI still required on this commit)

- [x] Local-first supplier directory and purchase records
- [x] Purchase stock-in and item-cost updates in one transaction
- [x] Supplier outstanding balance tracking
- [x] Transaction-level supplier payment ledger with overpayment protection
- [x] Transaction-level customer receipt ledger with partial payment support
- [x] Invoice paid amount, payment status and remaining balance
- [x] Sales return headers and original-invoice-line return details
- [x] Partial return quantity validation and prevention of duplicate over-return
- [x] Stock restoration for returned quantities in the same SQLite transaction
- [x] Expense entry and date-range totals
- [x] Stock adjustment audit records with negative-stock protection
- [x] Expiry batches and expiry review
- [x] Batch consumption on checkout and negative stock adjustments
- [x] Invoice line cost, discount and HSN/SAC snapshots for historical records
- [x] HSN/SAC product editor, CSV import/export and A4 invoice display
- [x] USB/Bluetooth HID keyboard-wedge barcode scanner workflow documented
- [x] Configurable invoice heading, terms, footer, logo and SKU visibility
- [x] Multi-page A4 and 80 mm thermal PDF layouts
- [x] Currency-code rendering in PDFs to avoid missing rupee glyphs
- [x] Checkout re-reads stock in-transaction and conditionally decrements stock
- [x] Deterministic integer-paise billing and discount allocation
- [x] GST calculator and invoice checkout tests for CGST, SGST and IGST
- [x] Daily CGST/SGST/IGST totals on the dashboard
- [x] Backup export/restore for customer and supplier payment ledgers and sales returns
- [x] Backup validation for new ledger and return parent references
- [x] Sync queue handlers and Supabase schema/RLS additions for suppliers, purchases, expenses, stock adjustments, expiry batches, payment ledgers and returns
- [x] Manual production Android release workflow with application ID, signing fingerprint, APK signature, package ID and SHA-256 verification gates
- [x] Invoice payment/return actions and purchase payment action in the UI
- [x] Sync queue retry diagnostics and paginated cloud pulls

## Mandatory automated checks for the integrated change

- [ ] flutter pub get
- [ ] dart run build_runner build --delete-conflicting-outputs
- [ ] dart format --output=none --set-exit-if-changed .
- [ ] flutter analyze
- [ ] flutter test
- [ ] flutter build apk --release
- [ ] flutter build windows --release
- [ ] flutter build macos --release
- [ ] flutter build ios --no-codesign

## External production gates that cannot be proven from source code

- [ ] Verify application ID against an APK already installed by real users, if one exists.
- [ ] Supply the existing production keystore through GitHub Actions secrets; never commit it.
- [ ] Verify the expected signing-certificate SHA-256 fingerprint using the APK and the release workflow.
- [ ] Apply the updated supabase/schema.sql to a staging project and validate RLS with two separate businesses.
- [ ] Run two-device offline/online sync conflict and recovery scenarios.
- [ ] Test database migration from real historical database files, including schema versions 1–5.
- [ ] Test a signed APK over-install on a physical device and verify invoices, inventory, customers and ledgers remain intact.
- [ ] Test receipt/return/refund and supplier payment flows with shop operators and real hardware.

## Remaining product limitations

- [ ] Automatic GST place-of-supply determination from seller/customer state codes and GSTIN.
- [ ] Embed and verify Devanagari/Unicode PDF fonts for Hindi and other scripts.
- [ ] Direct ESC/POS Bluetooth thermal printing and cash-drawer support.
- [ ] Camera-based barcode scanning and device-specific scanner testing.
- [ ] In-app APK download, checksum validation and Android package-installer handoff. The About screen currently opens the GitHub releases page; it is not an automatic installer.
- [ ] Full accounting statements and reports across customers, suppliers, credit notes and refunds.
- [ ] Real-world testing of cross-platform printing, expiry batch reconciliation and cloud conflict handling.

Passing unit tests and CI does not prove production signing continuity or physical-device safety. No production release should be published before the external gates above are satisfied.