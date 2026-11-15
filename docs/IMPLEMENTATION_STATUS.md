# SBILL Implementation Status

**Updated:** 2026-11-15  
**Working branch:** `feat/sbill-stability-update-foundation`  
**Pull request:** [#5 — SBILL stability foundation](https://github.com/shinuXcode/shop-inventory-app/pull/5)

## Delivery order

| Workstream | Status | Notes |
|---|---|---|
| Initial repository audit | IMPLEMENTED | Static source audit committed; see `INITIAL_PRODUCT_AUDIT_2026-11-15.md` |
| Backup merge correctness | IMPLEMENTED | Missing invoice/purchase child rows can be restored when the parent already exists |
| Backup preview validity | IMPLEMENTED | Validation errors now make a preview invalid and are surfaced before import |
| Backup structural validation | IMPLEMENTED | Checks backup sections, row objects, required identity fields, duplicate IDs and selected parent references before writing |
| GST backup fidelity | IMPLEMENTED | Invoice-level CGST/SGST/IGST and supply type are included in exported snapshots |
| Flutter tests / analyze | BLOCKED | GitHub Actions PR run is the active verification path; local Flutter SDK is unavailable in this session |
| Android package identity | BLOCKED | Must inspect an existing distributed APK before preserving an established application ID |
| Production signing | BLOCKED | Must establish whether a production keystore already exists; never rotate it without explicit approval |
| Permanent Android project | NOT IMPLEMENTED | Android folder is absent from the repository; do not generate identity defaults blindly |
| GitHub release pipeline | NOT IMPLEMENTED | Requires committed Android Gradle configuration and verified signing identity |
| In-app updater | NOT IMPLEMENTED | Must be integrated after package identity, signing and release metadata are fixed |
| Payment ledgers / returns | NOT IMPLEMENTED | Requires separately designed Drift migrations and historical compatibility tests |
| Hardware, GST and cloud gaps | NOT IMPLEMENTED | Follow the audit priority order; no mock completion claims |

## Data-safety changes in this branch

1. `AppDatabase.importSnapshot` now validates the snapshot before entering the restore transaction.
2. A backup with a malformed collection, non-object row, missing required identity, duplicate record ID, or broken invoice/purchase/supplier reference is rejected before writes.
3. A merge restore no longer discards missing invoice lines merely because the invoice header already exists.
4. A merge restore no longer discards missing purchase lines merely because the purchase header already exists.
5. Backup exports preserve invoice-level GST breakup and supply type; older backups without these fields remain readable through existing import defaults.
6. Invalid import previews now report validation failures as invalid, and the import path surfaces those errors rather than attempting restore.

## Safety rules

- No database schema version change has been made in this first data-safety batch.
- No existing records are deleted or overwritten by these changes.
- No Android package ID or namespace has been guessed.
- No keystore has been generated, replaced or committed.
- No production APK or GitHub Release has been published.
- No feature is marked TESTED or VERIFIED until the corresponding automated or device-level check actually passes.

## Remaining Android setup required

Before Android release implementation can be safely completed:

1. Provide the latest APK previously installed by any SBILL users, if one has been distributed.
2. Inspect its package ID and signing-certificate SHA-256 fingerprint.
3. Confirm who controls the matching production keystore.
4. Store the keystore and passwords in GitHub Actions secrets; retain a verified offline backup.
5. Commit deterministic Android Gradle/manifest configuration with the verified application ID.
6. Add release signing, artifact verification, monotonic version-code enforcement, release metadata and GitHub Release publication.
7. Implement update download/hash verification and Android package-installer handoff.
8. Perform a real over-install test with existing business data on a test device.

## Verification policy

A successful CI run proves only the jobs it actually ran. It does not prove that a release can update an existing installation, that signing continuity is preserved, or that data survives on a physical device. Those remain separate release gates.
