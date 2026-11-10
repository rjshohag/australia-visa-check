-- Security setup template for the demo application.
-- REVIEW BEFORE RUNNING: assumes public.visa_demo_records already exists and
-- contains only synthetic, non-sensitive demonstration rows.
-- This script does not create or alter the demo records table.

begin;

create table if not exists public.visa_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.visa_admins enable row level security;

-- No browser role receives direct access to the administrator allow-list.
revoke all on table public.visa_admins from anon, authenticated;

create or replace function public.is_visa_admin()
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

-- The function owner must be a trusted database role that can read visa_admins.
revoke all on function public.is_visa_admin() from public;
grant execute on function public.is_visa_admin() to authenticated;

-- RLS is the actual security boundary. UI checks are not authorization.
alter table public.visa_demo_records enable row level security;

-- The current public lookup reads this table directly. This policy permits
-- public reads of every row, so keep this table strictly synthetic.
drop policy if exists "Public can read demo records" on public.visa_demo_records;
create policy "Public can read demo records"
  on public.visa_demo_records
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Visa admins can insert demo records" on public.visa_demo_records;
create policy "Visa admins can insert demo records"
  on public.visa_demo_records
  for insert
  to authenticated
  with check ((select public.is_visa_admin()));

drop policy if exists "Visa admins can update demo records" on public.visa_demo_records;
create policy "Visa admins can update demo records"
  on public.visa_demo_records
  for update
  to authenticated
  using ((select public.is_visa_admin()))
  with check ((select public.is_visa_admin()));

drop policy if exists "Visa admins can delete demo records" on public.visa_demo_records;
create policy "Visa admins can delete demo records"
  on public.visa_demo_records
  for delete
  to authenticated
  using ((select public.is_visa_admin()));

grant select on table public.visa_demo_records to anon, authenticated;
grant insert, update, delete on table public.visa_demo_records to authenticated;

commit;

-- Bootstrap an administrator manually after creating the Auth user:
-- insert into public.visa_admins (user_id)
-- values ('REPLACE-WITH-AUTH-USER-UUID');
--
-- Never add an administrator based only on an email supplied by the browser.
-- Verify the UUID in Supabase Auth before inserting it.
