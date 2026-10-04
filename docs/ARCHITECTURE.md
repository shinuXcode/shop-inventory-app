# SBILL Architecture

## Phase 0 audit
- Flutter/Dart: declared SDK >=3.3.0 <4.0.0; CI uses the current stable Flutter channel.
- Architecture: Flutter + Riverpod + Drift/SQLite with a feature-oriented folder layout.
- Screens: Dashboard, Billing, Inventory, Customers, Invoices.
- Routing/navigation: adaptive NavigationRail/NavigationBar shell; no dedicated route package yet.
- Database: Drift/SQLite with Items, Customers, Invoices, InvoiceItems and SyncQueue.
- Cloud: optional Supabase Auth + PostgreSQL/RLS with email authentication, workspace bootstrap RPC, persisted sync queue and idempotent upserts.
- Website: responsive static product website under website/ with feature, privacy, workflow and download sections.
- Assets: no external asset pipeline currently required; Material icons are used.
- Tests: a basic cart unit test exists.
- CI/CD: GitHub Actions pins the Flutter toolchain and verifies analysis, tests, Android, Windows, macOS and unsigned iOS compilation.

## Proposed production architecture
- Presentation: feature pages + Riverpod state/controllers.
- Domain: deterministic billing calculations and business rules.
- Data: Drift repositories as the local source of truth; sync queue persisted locally.
- Cloud: Supabase Auth + PostgreSQL + RLS, isolated by business/workspace.
- Services: PDF/printing, synchronization, connectivity, settings and desktop shortcuts.
- UI: Material 3 tokens and reusable responsive components.

## Important existing components
- lib/app.dart
- lib/core/database/app_database.dart
- lib/core/theme.dart
- lib/core/pdf/invoice_pdf_service.dart
- lib/core/sync/sync_service.dart
- lib/features/*

## Files to modify
- Database/repository and billing services
- Feature screens for inventory, customers, billing and invoices
- Theme/app shell
- Sync service
- PDF service
- Supabase schema
- CI workflow
- README

## Files to create
- docs/ARCHITECTURE.md
- docs/RELEASE_CHECKLIST.md
- reusable UI/token files
- billing calculation tests
- database/transaction tests
- Supabase security tests/documentation

## Migration strategy
1. Preserve the existing main-branch foundation.
2. Add schema changes through Drift migrations rather than destructive resets.
3. Keep local SQLite authoritative for billing.
4. Add business/workspace identifiers locally before enabling cloud sync.
5. Introduce Supabase Auth and RLS without making offline billing dependent on it.
6. Validate each phase with analyzer/tests/builds before advancing.
7. Never delete historical invoice snapshots when products change.
