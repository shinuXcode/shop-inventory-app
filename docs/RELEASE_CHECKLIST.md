# SBILL Release Checklist

## Current implementation status
- [x] Phase 0 repository audit documented
- [x] Phase 1 Material 3/adaptive shell foundation
- [x] Phase 2 Drift tables and transactional local checkout foundation
- [x] Phase 3 inventory search + edit + deactivate foundation
- [x] Phase 5 deterministic integer billing calculator
- [x] Phase 11 persistent local settings foundation
- [x] Supabase multi-tenant schema/RLS foundation
- [ ] Full authentication/workspace onboarding
- [ ] Cloud synchronization and conflict resolution
- [ ] Thermal receipt generation
- [ ] Complete customer history/edit flow
- [ ] Full invoice detail/print/share/download flow
- [ ] Analytics expansion
- [ ] Desktop keyboard shortcuts
- [ ] Full website/showcase validation
- [ ] Android release build
- [ ] Windows release build
- [ ] macOS release build where supported

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

Only mark SBILL production-ready after all supported builds and acceptance tests pass.
