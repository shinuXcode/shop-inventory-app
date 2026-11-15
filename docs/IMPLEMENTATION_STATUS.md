# SBILL Implementation Status

**Updated:** 2026-11-15  
**Integrated branch:** feat/sbill-one-phase-complete-system  
**Base:** main after merge of PR #5  
**Target version:** 1.3.0+4

## Integrated implementation

This branch consolidates the outstanding source-code work into one coordinated change set. It does not split the product into staged implementation phases.

| Area | Code status | Verification status |
|---|---|---|
| Backup/restore validation and merge correctness | Implemented in PR #5 | Earlier CI run passed |
| Invoice payment state and customer receipt ledger | Implemented in this branch | New tests added; pending CI |
| Supplier payment ledger | Implemented in this branch | New tests added; pending CI |
| Sales returns and stock restoration | Implemented in this branch | New tests added; pending CI |
| Schema migration | Drift schema v6 migration added | Historical database fixtures still required |
| Backup/restore for payment and return records | Export, validation and import paths added | Round-trip regression test added; pending CI |
| Supabase schema/RLS | New business-scoped tables and policies added | Must be applied and tested in staging |
| Supabase sync | Push/pull handlers added for retail records, payments and returns | Two-device staging verification pending |
| Invoice / purchase UI | Receipt, return and supplier payment actions added | Manual usability test pending |
| Android production release | Manual fail-closed workflow added; requires identity, keystore and certificate inputs | Not run; no production key provided |
| About > Check for updates | Opens GitHub Releases | Not an in-app downloader or installer |
| Hardware, automatic GST, multilingual PDF | Existing documented limitations remain | Not implemented in this change |

## Data and accounting rules

- All monetary values remain integer minor units (paise).
- Invoice paid amount and payment status are stored separately from the initial payment method.
- Non-credit invoices from existing schema versions are migrated as paid; credit invoices are migrated as unpaid.
- New customer receipts cannot exceed the invoice balance after recorded returns.
- Supplier payments cannot exceed the purchase's remaining balance.
- Return quantities cannot exceed the original invoice-line quantity less previously returned quantities.
- Return header, return lines, and optional stock restoration execute in one SQLite transaction.
- Returned goods are introduced as a fresh non-expiry stock batch. Expiry must be checked/re-entered when relevant.
- JSON backups include customer receipts, supplier payments, sales returns and return lines; the validator checks their parent references before writing.

## Cloud sync

The updated Supabase schema adds business-scoped suppliers, purchases, purchase lines, expenses, stock adjustments, stock batches, customer payments, supplier payments, sales returns and return lines. RLS policies require business membership. Apply the complete updated supabase/schema.sql to a staging project before enabling these paths in production. SQLite remains the local source of truth.

## Android release safety

The manual workflow requires:
1. A verified full Android application ID from the existing app identity or a deliberate first production release decision.
2. ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS and ANDROID_KEY_PASSWORD configured as GitHub Actions secrets.
3. The expected signing-certificate SHA-256 fingerprint supplied at workflow dispatch.
4. A version/build number greater than the previous tagged release.

The workflow generates Android project files from the supplied application ID, builds the APK, signs it, checks the application ID and exact certificate fingerprint, computes SHA-256, and publishes sbill.apk plus latest.json. It does not invent or generate a signing key. No production APK has been published from this branch.

## Remaining real-world gates

- CI run for the integrated branch must pass; no claims of green tests/analyze/build are made until that run completes.
- Apply and validate the Supabase SQL in staging; run cross-tenant RLS and two-device sync tests.
- Verify old database migration with real fixtures from schema versions 1–5.
- Test signed APK over-install and data preservation on a physical Android device.
- Add an actual in-app download/checksum/install experience if automatic updates are required.
- Implement camera scanning, direct ESC/POS printing, Devanagari font embedding and GST place-of-supply automation.
- Perform operator testing for returns, payments, refunds, statements and reconciliation.

**Release decision:** NO-GO for a production rollout until the integrated CI run, signing identity, migration fixtures, Supabase staging and physical-device upgrade tests are verified.