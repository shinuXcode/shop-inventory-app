# SBILL Release Checklist

## Current implementation status
- [x] Phase 0 repository audit documented
- [x] Phase 1 Material 3/adaptive shell foundation
- [x] Phase 2 Drift tables and transactional local checkout foundation
- [x] Phase 3 inventory search + edit + deactivate foundation
- [x] Phase 5 deterministic integer billing calculator
- [x] Phase 11 persistent local settings foundation
- [x] Supabase multi-tenant schema/RLS foundation
- [x] Supabase email authentication and workspace bootstrap
- [x] Cloud synchronization with persisted retry queue and idempotent entity upserts
- [x] Account-based multi-device workspace restore and conflict-aware sync foundation
- [x] Thermal receipt PDF generation
- [x] Complete customer history/edit flow
- [x] Full invoice detail/print/share/save flow
- [x] Dashboard analytics expansion
- [x] Billing desktop keyboard shortcuts
- [x] Responsive showcase website content and static validation
- [x] Android release artifact verified in CI
- [x] Windows release artifact verified in CI
- [x] macOS release artifact verified in CI
- [x] iOS unsigned compile verified in CI

## Mandatory release gate
Run:
- flutter pub get
- dart run build_runner build --delete-conflicting-outputs
- dart format --output=none --set-exit-if-changed .
- flutter analyze
- flutter test
- flutter build apk --release
- flutter build windows --release
- flutter build macos --release
- flutter build ios --no-codesign

The checklist marks implemented gates; the repository must still remain CI-green on the latest main commit before a release is declared production-ready.
