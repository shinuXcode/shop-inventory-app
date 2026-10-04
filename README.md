# SBILL

**Simple Billing. Smarter Business.**

Offline-first billing and shop management for Android, Windows and macOS.

## Stack

Flutter, Dart, Material 3, Riverpod, Drift/SQLite, Supabase, PDF/printing.

## Development

Run:

flutter pub get
dart run build_runner build
dart format .
flutter analyze
flutter test

For a clean checkout, platform folders can be generated with:

flutter create --platforms=android,windows,macos .

Money is stored as integer minor units (paise). Checkout calculates tax/discounts deterministically and writes the invoice, invoice items, stock changes and sync-queue events inside one SQLite transaction.

Apply `supabase/schema.sql` to configure the multi-tenant cloud schema, RLS and the authenticated `create_business` bootstrap RPC. Build with `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...` to enable cloud features. Never ship a service-role key in the client.

The product website is under website.

## Production roadmap

SBILL now includes the production-critical offline POS flow: deterministic billing, editable carts, customer selection/history, payment methods, responsive inventory, invoice detail with A4/thermal PDF actions, persistent settings, optional Supabase authentication/workspace sync, dashboard analytics, responsive showcase site and cross-platform CI build jobs.

Final release gating still requires successful CI verification of the generated Android, Windows and macOS release artifacts plus multi-device conflict/pull validation. See `docs/ARCHITECTURE.md` and `docs/RELEASE_CHECKLIST.md`.
