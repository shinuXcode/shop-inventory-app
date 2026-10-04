# SBILL

**Simple Billing. Smarter Business.**

Offline-first billing and shop management for Android, Windows and macOS.

## Stack

Flutter, Dart, Material 3, Riverpod, Drift/SQLite, Supabase, PDF/printing.

## Development

Run:

flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test

For a clean checkout, platform folders can be generated with:

flutter create --platforms=android,windows,macos .

Money is stored as integer minor units (paise). Checkout writes invoice, invoice items, stock changes and sync-queue data inside one SQLite transaction.

Apply supabase/schema.sql to configure the cloud schema and RLS. Never ship a service-role key in the client.

The showcase website is under website/.

## Production roadmap

SBILL is being implemented phase-by-phase. The current main branch contains the offline-first foundation, transactional local checkout, deterministic billing engine, inventory editing/deactivation, persistent business settings, and the multi-tenant Supabase schema/RLS foundation.

Cloud synchronization, full authentication/workspace onboarding, thermal receipts, complete invoice workflows, desktop shortcuts, expanded analytics, and final release builds remain explicit release-gate work. See `docs/ARCHITECTURE.md` and `docs/RELEASE_CHECKLIST.md`.
