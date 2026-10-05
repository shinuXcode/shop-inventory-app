# SBILL account and cross-device sync

SBILL remains offline-first. An account is optional for local billing and becomes the identity used for cloud synchronization when Supabase is configured.

## Account flow

1. Create an account or sign in with email and password.
2. SBILL binds the local device to the authenticated Supabase user.
3. If the account already owns or belongs to a business workspace, the first available workspace is linked automatically.
4. If no workspace exists, create one from Account & Sync.
5. Workspace profile data is restored locally before sync starts.
6. Local changes continue to enter the SQLite sync queue and are retried when connectivity is available.
7. Sign out stops cloud synchronization and preserves the local database.

## Supported platforms

The same account flow is compiled into Android, Windows, macOS and iOS builds. Supabase's persisted session is used so a signed-in account can remain signed in between app launches.

## Supabase setup

Create the schema from `supabase/schema.sql`, enable email/password authentication in the Supabase project, and keep the client publishable key in client configuration only.

For GitHub Actions, add repository Variables:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

The CI workflow passes both values with `--dart-define` to every platform build. When either variable is absent, the build remains offline-only and the Account page clearly reports that cloud configuration is disabled.

## Data isolation

RLS policies scope every cloud business table through `business_members`. A user can only read or write rows belonging to a workspace where that user is a member. The `create_business` function is security-definer and executable by authenticated users only.

## iOS distribution

CI verifies that the iOS application compiles with `--no-codesign`. A real App Store/TestFlight-installable build additionally requires Apple signing certificates, provisioning profiles and the appropriate Apple developer configuration. Those credentials are intentionally not stored in the repository.
