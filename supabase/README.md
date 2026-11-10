# Supabase security review and deployment notes

**No live Supabase SQL has been run for this pull request.** This repository contains no schema dump, migration history, live catalog output, or database credentials. Existing policies/grants, actual column spelling, and deployed function ownership cannot be verified from GitHub alone.

## Preflight review

1. Run [VERIFY_SECURITY.sql](VERIFY_SECURITY.sql) manually against the intended Supabase project.
2. Save results securely; do not paste credentials, JWTs, or sensitive row data into GitHub.
3. Confirm whether `visa_demo_records` has `note` or `notes`. The frontend in this branch expects `notes`. The old HTML selected `note` while reading/writing `notes`, but that does not prove the live schema.
4. Inspect all policies and grants. PostgreSQL permissive policies combine with OR; a pre-existing `USING (true)` policy can continue to permit access despite a new admin-only policy. Inspect grants to PUBLIC, inherited role grants, and effective privileges too.
5. If any policy/grant is broader than intended, stop and reconcile it in a separately reviewed migration. Do not blindly drop or overwrite existing policies.
6. Back up and test in staging first.

## Function owner and permissions

The template defines `public.is_visa_admin()` as `SECURITY DEFINER`, `STABLE`, with an empty `search_path`, schema-qualified references, and no caller-supplied identity. It assigns the owner to the trusted Supabase `postgres` role, intended to read the protected `visa_admins` table. It revokes EXECUTE from PUBLIC/anon/authenticated, then grants it only to authenticated.

Validate this owner against the project's role model before applying. Confirm owner, `prosecdef`, definition, settings, and ACL with query 6; confirm effective EXECUTE with query 7. The owner must be trusted and not client-controlled. Keep the body static; no dynamic SQL or caller-controlled identifiers.

The template uses `CREATE TABLE` and `CREATE FUNCTION` without `IF NOT EXISTS` or `OR REPLACE`. If either object exists already, the script stops instead of silently adopting or replacing an object whose ownership or behavior has not been audited.

## RLS and public lookup

The template is admin-only: no anonymous SELECT grant or policy is created. The current browser app performs a direct public table lookup, so anonymous lookup will be denied after this strict policy set is applied. This is intentional until a separately reviewed public-safe view/RPC/backend endpoint exists.

Prefer a narrowly scoped endpoint/view/RPC returning only safe sample fields. Do not add `USING (true)` to the base table unless every row and every column is safe for public exposure. RLS filters rows, not columns.

## Apply and test

- Review [SECURITY_SETUP.sql](SECURITY_SETUP.sql) only after understanding preflight output.
- Reconcile existing policies/grants manually; do not run on top of unknown policies.
- Confirm actual columns and resolve `note` versus `notes` before applying.
- Apply in staging, add only a verified Auth UUID to `visa_admins`, and test anonymous, non-admin, and admin clients.
- Verify removing an allow-list row revokes admin access and no other permissive policy restores it.

## Rollback plan

Rollback is manual and must be adapted to the pre-deployment catalog snapshot. Do not blindly drop objects that may have existed before this change.

If the template was applied to a previously clean schema and these four policy names were created by it, the following reverses those new policies/grants:

```sql
begin;
drop policy if exists "Visa admins can read demo records" on public.visa_demo_records;
drop policy if exists "Visa admins can insert demo records" on public.visa_demo_records;
drop policy if exists "Visa admins can update demo records" on public.visa_demo_records;
drop policy if exists "Visa admins can delete demo records" on public.visa_demo_records;
revoke select, insert, update, delete on table public.visa_demo_records from authenticated;
revoke all on function public.is_visa_admin() from public, anon, authenticated;
drop function if exists public.is_visa_admin();
revoke all on table public.visa_admins from public, anon, authenticated;
drop table if exists public.visa_admins;
commit;
```

This does not disable RLS on `visa_demo_records`, drop the records table, restore prior grants/policies, or restore a previous function definition. Restore those only from the saved snapshot and an explicitly reviewed migration. If an object existed beforehand, do not run its DROP. Preserve allow-list membership before dropping the allow-list table.

## Data and secrets

Only synthetic demonstration data belongs here. Never store real passport/visa data. Never commit service-role keys, secret API keys, database passwords, or user tokens. A publishable browser key is not a database authorization mechanism; RLS and grants are the security boundary.
