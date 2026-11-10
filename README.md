# Australia Visa Check — Independent Demo

> **DEMO ONLY — NOT AN AUSTRALIAN GOVERNMENT SERVICE.** This independent website stores and displays illustrative sample records. It is not affiliated with the Australian Government or Department of Home Affairs, does not connect to government immigration systems, and cannot verify a real visa, application, grant, status, or decision.

Do not enter passport numbers, real visa details, or other personal or sensitive information. Use synthetic demonstration data only.

## What this project does

- Looks up a sample row in the Supabase `public.visa_demo_records` table using a demonstration reference number.
- Provides an administrator sign-in and dashboard for creating, editing, listing, and deleting sample records.
- Uses Supabase Auth for password authentication and the Supabase JavaScript client for database access.
- Uses the database function `public.is_visa_admin()` to determine whether the signed-in user is an administrator.

The public lookup is only a lookup of records deliberately seeded for demonstration. A “record found” message is not evidence of any real-world visa or immigration outcome.

## Repository files

- `index.html` — single-page website, styles, browser-side Supabase client, public demo lookup, and admin interface.
- `supabase/SECURITY_SETUP.sql` — reviewed setup template for the admin allow-list, authorization function, grants, and row-level security policies. Review and run it manually in the correct Supabase project only after confirming the schema.
- `supabase/README.md` — deployment and security notes, including assumptions and validation steps.

## Configuration

The browser uses a Supabase project URL and a **publishable** key. These values are intended to be exposed to browsers; a publishable key is not an authorization secret. Never place a Supabase `service_role` key, secret API key, database password, access token, or other privileged credential in this repository or client-side code.

For a different Supabase project, replace the project URL and publishable key in `index.html` with that project's public client configuration. Prefer a deployment-time configuration mechanism if the site is later moved to a build system. Restrict allowed authentication redirect URLs in Supabase Auth settings.

## Database contract

The frontend expects a table named `public.visa_demo_records` with at least these columns:

| Column | Expected use |
| --- | --- |
| `id` | Stable row identifier used for editing and deletion |
| `reference_number` | Demo lookup key |
| `visa_category` | Sample category label |
| `status` | Sample status label |
| `notes` | Optional sample notes |
| `created_at` | Timestamp shown in the UI |

The application now consistently reads and writes `notes` (plural). Confirm the actual table schema before applying any SQL. This repository does not contain a verified production schema or a live database connection.

### Required authorization model

1. Enable RLS on `public.visa_demo_records`.
2. Maintain an administrator allow-list in `public.visa_admins`, keyed by the Supabase Auth user UUID.
3. Implement `public.is_visa_admin()` as a stable, narrowly scoped `SECURITY DEFINER` function that checks `auth.uid()` against that allow-list. Pin its `search_path`, fully qualify referenced objects, and grant execution only to authenticated users.
4. Use RLS policies—not JavaScript flags—to authorize every database operation. The browser-side admin check is only a user-interface convenience and is not a security boundary.
5. Grant anonymous/authenticated SELECT only if public lookup is intended. The included template does so because the current public lookup queries the table directly. That means every row permitted by the SELECT policy is readable through the public API. Only synthetic, non-sensitive demo rows may be stored there. If that is not acceptable, move public lookup behind a narrowly scoped server-side endpoint or a restricted view/RPC and do not expose the base table.
6. Allow INSERT, UPDATE, and DELETE only when `is_visa_admin()` returns true.

See [Supabase security setup](supabase/README.md) and review [the SQL template](supabase/SECURITY_SETUP.sql). No SQL is applied automatically by this website or repository.

## Authentication and request flow

1. An administrator submits an email and password to `supabase.auth.signInWithPassword()`.
2. Supabase Auth validates the credentials and returns a user/session. The Supabase client manages session persistence and token refresh using its standard browser behavior.
3. The app calls `supabase.rpc("is_visa_admin")`. The function evaluates the current authenticated identity using `auth.uid()`; it does not trust an email address or a browser-supplied role.
4. If authorized, the UI displays the dashboard. Database requests still carry the user's Supabase session and are independently checked by RLS.
5. Signing out calls `supabase.auth.signOut()` and clears the app's admin UI state.

Passwords are sent to Supabase Auth over HTTPS; this app does not implement password storage or password hashing. Do not log credentials or tokens. Never treat the publishable key as a secret or as a substitute for RLS.

## Run locally

This is a static HTML page with an ES module import. Serve the repository using a local HTTP server rather than opening the file directly. For example:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000`.

Before testing admin functions, configure Supabase Auth, apply and review the SQL setup, add the intended administrator UUID to `public.visa_admins`, and seed only fake demo records.

## Security and operational checklist

- [ ] Confirm the target Supabase project URL and publishable key; ensure no secret/service-role key is present in client code or Git history.
- [ ] Confirm the real `visa_demo_records` schema matches the frontend contract, especially `notes`.
- [ ] Review and apply the SQL template manually; do not run it blindly against a database with existing policies or objects.
- [ ] Verify RLS is enabled and test anonymous SELECT, authenticated non-admin SELECT, and non-admin writes.
- [ ] Verify an allow-listed administrator can perform intended CRUD operations and a removed administrator immediately loses access.
- [ ] Confirm public SELECT exposes only synthetic data; use a server-side endpoint or restricted view/RPC if column-level privacy is required.
- [ ] Configure Supabase Auth password policy, email verification, rate limits, redirect URLs, and MFA as appropriate for the deployment.
- [ ] Test on a staging project before production.

## Scope and limitations

This repository is a demonstration interface, not a visa verification product, immigration service, legal service, or government portal. It does not query Australian government records and must not be marketed or described as verifying genuine visas or applications. All labels, categories, statuses, and notes shown by the app are illustrative sample data.


## Additional security review

Before deployment, run the read-only catalog checks in [supabase/VERIFY_SECURITY.sql](supabase/VERIFY_SECURITY.sql). The repository does not establish the live `note`/`notes` column, current grants/policies, or deployed function owner; those require results from the actual Supabase project. See [Supabase security review and rollback notes](supabase/README.md). No SQL is run automatically.
