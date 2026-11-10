-- SECURITY TEMPLATE — NOT EXECUTED.
-- Read supabase/README.md and run VERIFY_SECURITY.sql first.
-- Stop if the real schema, existing grants, policies, or function owner are
-- unknown. This template deliberately does NOT enable anonymous table reads.
-- It assumes public.visa_demo_records already exists and contains demo data.

begin;

-- Intentionally fail if this table already exists: inspect/reconcile it first.
create table public.visa_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.visa_admins owner to postgres;
alter table public.visa_admins enable row level security;
revoke all on table public.visa_admins from public, anon, authenticated;

-- Intentionally fail if this function already exists: inspect it before
-- deciding whether replacement is safe.
create function public.is_visa_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.visa_admins as admins
    where admins.user_id = (select auth.uid())
  );
$function$;

-- Trusted Supabase owner can read the protected allow-list. Validate owner
-- against your project role model before applying.
alter function public.is_visa_admin() owner to postgres;
revoke all on function public.is_visa_admin() from public, anon, authenticated;
grant execute on function public.is_visa_admin() to authenticated;

alter table public.visa_demo_records enable row level security;

-- Admin-only access. No anon SELECT grant/policy is created.
-- Anonymous lookup in the current browser app will be denied until a
-- separately reviewed public-safe view/RPC/backend endpoint is implemented.
create policy "Visa admins can read demo records"
  on public.visa_demo_records for select to authenticated
  using ((select public.is_visa_admin()));

create policy "Visa admins can insert demo records"
  on public.visa_demo_records for insert to authenticated
  with check ((select public.is_visa_admin()));

create policy "Visa admins can update demo records"
  on public.visa_demo_records for update to authenticated
  using ((select public.is_visa_admin()))
  with check ((select public.is_visa_admin()));

create policy "Visa admins can delete demo records"
  on public.visa_demo_records for delete to authenticated
  using ((select public.is_visa_admin()));

revoke all on table public.visa_demo_records from public, anon, authenticated;
grant select, insert, update, delete on table public.visa_demo_records to authenticated;

commit;

-- Bootstrap only after verifying the user's UUID in Supabase Auth:
-- insert into public.visa_admins (user_id)
-- values ('REPLACE-WITH-VERIFIED-AUTH-USER-UUID');
