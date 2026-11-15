# SBILL Initial Repository Audit

**Audit date:** 2026-11-15  
**Audited ref:** `main` at `b81e427099ad2738b420a0102386f9ad0b8a4b93`  
**Audit type:** Static repository review through GitHub source and workflow metadata. No local Flutter execution or device validation has been performed.

## Executive summary

SBILL already contains a meaningful offline-first retail foundation: Drift/SQLite, integer-minor-unit billing, manual intra/inter-state GST calculation, transactional checkout stock updates, purchase records, supplier balances, expenses, stock adjustments, expiry batches, PDF invoices, JSON backup/restore, and optional Supabase integration.

It is **not ready for a trustworthy production Android update/release**. The repository currently has no committed Android project directory, no verifiable production application ID or signing certificate, no permanent release-signing workflow, no update metadata/release workflow, and no published GitHub Releases. CI generates platform scaffolding during jobs, so Android identity/configuration is not anchored in source control.

This report distinguishes source-confirmed gaps from risks that still require runtime reproduction.

## 1. Confirmed findings

### P0 — Android identity and update safety

1. **Android project configuration is not committed.** The recursive `main` tree contains no `android/` directory. CI runs `flutter create --platforms=android .` before building. The application ID, namespace, manifest configuration, Gradle settings and signing configuration therefore cannot be verified from the committed Android project.
2. **Production signing is not configured in the checked workflow.** The Android job does not read the required keystore secrets or configure a release keystore. There is no checked-in signing workflow/configuration that guarantees the same certificate across releases.
3. **No in-app update system or GitHub Release assets were found.** The repository Releases API returned an empty list at audit time. No metadata contract, APK hash verification, installer handoff or update UI was found in the source tree.
4. **Installed application identity is unverified.** Without an existing production APK/AAB or its package ID and signing-certificate fingerprint, an update-compatible release cannot safely be prepared. Do not generate or replace a production key based on assumptions.
5. **Version is currently `1.2.0+3`.** No monotonic build-number guard or release metadata generation was found in the checked workflow.

### P0 — Database and recovery

6. **Drift schema version is 5.** Migrations are declared for transitions below versions 2, 3, 4 and 5. The checked test tree has no dedicated migration fixture/test file proving upgrades from each supported historical schema.
7. **Relational constraints are not declared in the visible table definitions.** Tables carry related IDs (for example invoice/customer, invoice-line/invoice, purchase/supplier and batch/item), but the reviewed definitions do not declare Drift `.references(...)` constraints. Runtime integrity therefore relies substantially on application logic.
8. **Backup/restore is implemented, but recovery guarantees are not yet proven.** Existing tests cover data-transfer behavior, but the repository does not show dedicated old-version fixture coverage, interrupted-restore recovery, corrupt-file fuzzing or a complete pre-restore recovery-backup test matrix.
9. **Migration interruption and real old-installation preservation remain unverified.** In-memory tests against the current schema do not prove upgrade safety for real version-1/version-2 database files.

### P1 — Retail accounting workflows

10. **Customer credit has no payment-ledger table in the current schema.** Invoices store a payment method/status, but no customer payment transaction entity or invoice-level amount-paid field exists in the reviewed table set. A proper partial-payment history and statement cannot be represented as a ledger of individual receipts yet.
11. **Supplier payments are represented as aggregate purchase fields.** Purchases contain `paidMinor` and `paymentStatus`, but no supplier-payment transaction table is present. This limits auditable multiple-payment history and supplier statements.
12. **Sales returns/refunds are absent from the current data model.** No return, credit-note, refund or exchange entity appears in the reviewed schema or feature tree.
13. **GST supply type is selected manually.** The architecture document explicitly says automatic place-of-supply determination from seller/customer state codes and GSTIN remains future work.
14. **Camera barcode scanning is absent.** The documented workflow supports HID keyboard-wedge scanners only.
15. **Direct ESC/POS printing is absent.** The README documents OS print-dialog support; direct Bluetooth ESC/POS and cash-drawer control are not implemented.
16. **Full Devanagari/Unicode invoice font support is absent/unverified.** The README and architecture notes explicitly document this limitation.
17. **Cloud synchronization is incomplete.** Supplier, purchase, expense, stock-adjustment and expiry-batch entities are not mirrored to Supabase according to the README and architecture document. Two-device staging validation is still a release gate.

### P1 — CI and release quality

18. **CI regenerates platform project files during jobs.** This makes platform configuration dependent on the Flutter tool version and generator defaults rather than a reviewed, committed platform project.
19. **Formatting is applied, not checked.** The workflow uses `dart format .`, which mutates the CI checkout. A non-mutating format check should be used as a quality gate.
20. **Analyzer warnings and infos are explicitly non-fatal.** The workflow uses `flutter analyze --no-fatal-infos --no-fatal-warnings`; this can allow quality regressions to pass.
21. **The Android job builds debug and release APKs but does not establish production signing identity.** APK signature verification alone does not prove continuity with an existing installed production app.
22. **Recent retail-branch CI runs observed during the audit were cancelled.** They are not evidence of passing validation. The main branch includes a recent CI/iOS fix merge, but this audit did not execute the pipeline locally.

## 2. Existing strengths worth preserving

- Billing stores monetary values in integer minor units (paise) and has deterministic discount allocation tests.
- Checkout re-reads stock inside a SQLite transaction and uses conditional stock updates to prevent stale-cart overselling.
- Invoice lines retain historical name, SKU, HSN/SAC, price, cost, discount and tax snapshots.
- Purchases, supplier balances, expenses, stock adjustments and expiry batches are implemented locally.
- Expiry batch consumption is documented as earliest-expiry-first.
- JSON backup coverage includes core retail entities listed in the README.
- Supabase is described as optional; SQLite remains the local source of truth.
- Existing tests cover billing, GST, checkout concurrency/stale stock, data transfer, PDF pagination, retail management and sync queue behavior.

## 3. Potential risks requiring reproduction (not confirmed bugs)

- Restore behavior under process termination, low storage, malformed nested JSON and duplicate IDs.
- Migration behavior on real database files from every previously shipped schema.
- Whether the generated Android application ID matches any APK previously distributed outside GitHub.
- Whether any previously distributed APK uses a signing certificate unavailable to the current maintainers.
- Concurrent purchase, stock adjustment and checkout interactions under multiple database connections.
- Time-zone boundaries in daily sales, tax reports and expiry notifications.
- RLS isolation and conflict behavior under two real Supabase users/devices.
- Platform-specific behavior of file picking, sharing, printing and PDF generation.
- Lifecycle handling of asynchronous work when screens are disposed.

## 4. Missing features against the requested product brief

- Permanent Android signing and GitHub Releases update pipeline.
- In-app update checker with SHA-256 validation and Android installer handoff.
- Migration fixture suite for all supported old schema versions.
- Pre-restore recovery snapshot and stronger restore fault-injection tests.
- Customer payment ledger, partial receipts and statements.
- Supplier payment ledger and statements.
- Sales returns, refunds, exchanges and credit notes.
- Camera barcode scanning and duplicate-barcode enforcement at database level.
- Automatic GST place-of-supply support.
- Devanagari font embedding.
- Direct ESC/POS printing.
- Full Supabase sync coverage and two-device staging evidence.
- Version-code monotonicity guard and signed release provenance.

## 5. Recommended implementation order

1. **Freeze release identity:** obtain a previously distributed production APK (if one exists), inspect its package ID and signing certificate, and identify who controls the matching keystore. Do not generate a replacement until this is resolved.
2. **Commit deterministic Android project configuration:** only after package identity has been established. Preserve namespace/application ID and current manifest/Gradle behavior.
3. **Build the release pipeline:** secret-backed signing, monotonic version-code check, APK signature/package verification, SHA-256 metadata, GitHub Release publication and fail-closed CI.
4. **Build the update client:** metadata parsing, version comparison, cancellable download, hash and package identity checks, Android package-installer handoff, offline/error handling and safe optional/mandatory policy.
5. **Harden database recovery:** old-schema fixtures, migration tests, transactional restore, pre-restore recovery backup and failure injection.
6. **Add auditable payment ledgers and returns:** schema-first design, migrations, transactionally derived balances and immutable invoice/return history.
7. **Complete retail hardware, GST and reporting gaps.**
8. **Complete optional cloud sync only with RLS and two-device staging proof.**

## 6. External inputs/blockers

- A production APK previously installed by users, if any, so its package ID and signing certificate can be inspected.
- The existing production keystore and passwords, if one was already used. Transfer through GitHub Actions secrets or another secure secret manager; never commit it.
- A verified offline backup of the existing keystore.
- Android test device(s) for over-install/data-preservation and package-installer tests.
- Supabase staging project credentials and two test accounts only if full cloud sync is in scope.

## 7. Verification status

| Item | Status |
|---|---|
| Repository and main tree inspected | VERIFIED (static source inspection) |
| Android application ID | BLOCKED — Android project/APK not available in repository |
| Existing signing certificate | BLOCKED — no production APK/certificate supplied |
| GitHub Releases | VERIFIED — none published at audit time |
| Drift schema/migration declarations | REVIEWED — schema version 5 |
| Historical migration fixtures | NOT FOUND in reviewed test tree |
| Flutter analyze/test/build | NOT RUN in this environment |
| Device upgrade/data preservation | NOT RUN |
| Two-device Supabase sync | NOT RUN |
| Production APK | NOT BUILT or PUBLISHED |

**Release decision:** NO-GO for production update distribution until application identity and signing continuity are verified and the release/data-safety gates pass.
