# SBILL synchronization integration test plan

The normal Flutter test suite validates local queue creation, ordering, retry metadata, transactional stock updates and backup restoration. A real Supabase staging project is still required to validate authentication, RLS, network retries and multi-device reconciliation.

## Staging prerequisites

- A dedicated Supabase staging project, never production.
- Apply `supabase/schema.sql` to the staging database.
- Enable email/password authentication.
- Configure `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in a protected staging CI environment.
- Use two disposable test accounts and one test business workspace.
- Never place a service-role key in the Flutter app or CI build variables.

## Required end-to-end scenarios

1. Sign in on device A, create a business and add a product.
2. Verify the product is scoped to that business and invisible to a second account.
3. Sign in on device B with the same account and verify initial workspace restore.
4. Create an invoice offline on device A; reconnect and verify the invoice and stock update reach Supabase.
5. Verify device B pulls the invoice and stock update without duplicate invoice lines.
6. Edit the same product on both devices while offline; reconnect in both orders and verify the documented last-updated conflict rule.
7. Archive a product and verify the remote state is reconciled (hard deletes are not used for historical invoice references).
8. Force a temporary network failure and verify queue attempts/error details remain available for retry.
9. Insert more than 500 remote products and verify paginated pulls retrieve all records.
10. Confirm that an unsupported queue entity/operation is retained and surfaced as an error rather than silently discarded.

## Current limitation

Supplier records, purchase history, expenses, stock adjustments and expiry batches are local-first and included in SBILL JSON backups. Item stock changes caused by purchases/adjustments enqueue the existing item upsert. The new supplier/purchase/expense history tables are not yet mirrored to Supabase; multi-device sync of those records must be added before claiming complete cloud parity.

## Release gate

Do not mark sync production-ready until the two-device scenarios pass against staging and the app's CI build is green.
