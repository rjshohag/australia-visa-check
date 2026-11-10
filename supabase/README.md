# Supabase security setup

This directory documents a **manual setup template**, not an automatically deployed migration. The repository has no verified database schema export and no connection to the project's Supabase database. Review every statement against the target project before running it.

## Assumptions

- `public.visa_demo_records` already exists.
- It contains only synthetic demonstration rows, never real visa, passport, identity, or other sensitive information.
- The frontend uses the `notes` column (plural), plus `id`, `reference_number`, `visa_category`, `status`, and `created_at`.
- Public lookup is intentionally public. The current frontend reads `visa_demo_records` directly, so the template grants SELECT to `anon` and `authenticated` and adds a public SELECT policy. This makes all rows and columns on that table readable through the Supabase API, not just the columns selected by the UI. If the table contains anything private, do not use this policy: implement a server-side lookup or a carefully designed view/RPC and grant access only to that interface.

## Function requirements

`public.is_visa_admin()` must:
- Derive identity from `auth.uid()`, never a user ID/email argument from the browser.
- Check membership in a server-controlled `public.visa_admins` allow-list.
- Be `STABLE`, narrowly scoped, and `SECURITY DEFINER` only because the allow-list is intentionally not directly readable by clients.
- Set an empty/pinned `search_path` and fully qualify referenced objects.
- Have EXECUTE revoked from PUBLIC and granted only to authenticated users.
- Be owned by a trusted database role with the minimum required access.

The setup SQL creates a private allow-list table and this function. Add an administrator only after verifying their Auth UUID in the Supabase dashboard. Remove the row to revoke the allow-list membership.

## RLS requirements

The template enables RLS on both tables. It grants no direct client access to `visa_admins`. For `visa_demo_records`, it grants public SELECT to support the current public demo lookup, and admin-only INSERT, UPDATE, and DELETE. The admin policies call `is_visa_admin()`; the frontend's `isAuthorizedAdmin` flag is never treated as enforcement.

If your actual table has sensitive columns or should not be publicly enumerable, do not apply the public SELECT policy. Replace direct table lookup with a backend endpoint/RPC that returns only the intended public sample fields. RLS is row-level, not column-level.

## Apply and test

1. Back up the database and inspect existing grants, RLS status, and policies.
2. Confirm table and column names, then review `SECURITY_SETUP.sql`.
3. Run it manually in the intended Supabase project's SQL editor or deployment pipeline.
4. Insert the verified Auth UUID for the administrator.
5. Test with an anonymous client, a signed-in non-admin, and an allow-listed admin:
   - Anonymous: may read demo rows only if public lookup is intentionally enabled; must not write.
   - Signed-in non-admin: must not insert, update, or delete.
   - Admin: may perform intended CRUD; removing their allow-list row must remove write access.
6. Confirm the public API cannot reveal any real or sensitive data.

Do not place service-role keys, database passwords, secret API keys, or user tokens in browser code, SQL checked into source control, or issue/PR comments.
