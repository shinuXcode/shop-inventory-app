# SBILL Release Checklist

## Implemented in the retail-suite branch (pending CI verification)

- [x] Local-first supplier directory and purchase records
- [x] Purchase stock-in and item-cost updates in one transaction
- [x] Supplier outstanding balance tracking
- [x] Expense entry and date-range totals
- [x] Stock adjustment audit records with negative-stock protection
- [x] Expiry batches and expiry review
- [x] Batch consumption on checkout and negative stock adjustments
- [x] Invoice line cost and discount snapshots for historical gross-profit calculation
- [x] Configurable invoice heading, terms, footer, logo and SKU visibility
- [x] Multi-page A4 and 80 mm thermal PDF layouts
- [x] Currency-code rendering in PDFs to avoid missing rupee glyphs
- [x] Checkout re-reads stock in-transaction and conditionally decrements stock
- [x] Deterministic integer-paise billing and discount allocation
- [x] GST calculator unit tests for CGST, SGST and IGST
- [x] Backup export/restore for new supplier, purchase, expense and expiry data
- [x] Sync queue retry diagnostics and paginated cloud pulls
- [x] Regression tests for stale carts, concurrent checkout, billing, PDF pagination, backup restore, purchases, expenses and stock adjustments

## Mandatory automated checks

- [ ] `flutter pub get`
- [ ] `dart run build_runner build --delete-conflicting-outputs`
- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build apk --release`
- [ ] `flutter build windows --release`
- [ ] `flutter build macos --release`
- [ ] `flutter build ios --no-codesign`

## Still required before production

- [ ] Wire CGST/SGST/IGST selection and tax split into invoice checkout/storage/PDF (the calculator exists, but the full invoice flow is not yet integrated)
- [ ] Embed and verify Devanagari/Unicode PDF fonts for Hindi and other scripts
- [ ] Add direct ESC/POS thermal printing and cash-drawer support, or explicitly ship with OS print-dialog-only support
- [ ] Add Supabase tables/RLS and sync queue handlers for suppliers, purchases, expenses, stock adjustments and expiry batches
- [ ] Run the two-device Supabase staging scenarios in `docs/SYNC_INTEGRATION_TEST_PLAN.md`
- [ ] Validate migration from schema versions 1 and 2 using real fixture databases
- [ ] Verify generated Android, Windows and macOS release artifacts on the latest PR commit

The presence of a feature or a unit test does not mean the production release gate has passed.
