-- READ-ONLY SECURITY VERIFICATION QUERIES.
-- Run manually in Supabase SQL editor. No statements here modify data.

-- 1. Actual column spelling: note vs notes.
select table_schema, table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'visa_demo_records'
  and column_name in ('id','reference_number','visa_category','status','note','notes','created_at')
order by ordinal_position;

-- Frontend branch expects notes. If the only column is note, do not apply the
-- template until the frontend/schema mismatch is resolved deliberately.

-- 2. RLS state and table owner.
select n.nspname as schema_name, c.relname as table_name,
       pg_get_userbyid(c.relowner) as table_owner,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as force_rls
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('visa_demo_records','visa_admins');

-- 3. All policies. Permissive policies combine with OR and can preserve access
-- even when a new admin-only policy is added.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('visa_demo_records','visa_admins')
order by tablename, policyname;

-- 4. Explicit table grants.
select grantee, table_schema, table_name, privilege_type, is_grantable
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('visa_demo_records','visa_admins')
order by table_name, grantee, privilege_type;

-- 5. Effective table privileges for client roles.
select role_name,
       has_table_privilege(role_name, 'public.visa_demo_records', 'SELECT') as can_select,
       has_table_privilege(role_name, 'public.visa_demo_records', 'INSERT') as can_insert,
       has_table_privilege(role_name, 'public.visa_demo_records', 'UPDATE') as can_update,
       has_table_privilege(role_name, 'public.visa_demo_records', 'DELETE') as can_delete,
       has_table_privilege(role_name, 'public.visa_admins', 'SELECT') as can_read_admin_allowlist
from (values ('anon'), ('authenticated'), ('public')) as roles(role_name);

-- 6. Function owner, SECURITY DEFINER, volatility, settings, ACL, and body.
select p.oid::regprocedure as function_name,
       pg_get_userbyid(p.proowner) as function_owner,
       p.prosecdef as security_definer,
       p.provolatile as volatility,
       p.proconfig as function_settings,
       p.proacl as function_acl,
       pg_get_functiondef(p.oid) as function_definition
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'is_visa_admin'
  and pg_get_function_identity_arguments(p.oid) = '';

-- 7. Effective EXECUTE permissions.
select role_name,
       has_function_privilege(role_name, 'public.is_visa_admin()', 'EXECUTE') as can_execute
from (values ('anon'), ('authenticated'), ('public')) as roles(role_name);

-- Review every result. Test actual behavior with anon, non-admin, and admin JWTs.
