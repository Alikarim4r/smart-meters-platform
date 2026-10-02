-- =============================================================================
-- Migration: 120_platform_owner_server_authority.sql
-- Platform-owner authorization becomes server-authoritative and consistent.
--
-- Problems fixed:
--   1. public.is_platform_owner() trusted public.profiles.email, which the
--      "profiles_update_own" policy lets every user rewrite on their own row
--      → any user could set their profile email to the owner address and gain
--      platform-owner powers in every RLS policy / RPC.
--   2. The client decided ownership from its own allowlist / dart-define, so
--      client and server could disagree.
--
-- Design (no secrets, no client config):
--   * public.platform_owner_emails()     — single server-side allowlist
--                                           (same address as 052/056).
--   * public.is_platform_owner_user(uid) — identity from auth.users (GoTrue
--                                           owned, email change needs
--                                           confirmation) + confirmed email.
--   * public.is_platform_owner()         — unchanged signature; now delegates.
--   * profiles.is_platform_owner         — server-maintained flag the clients
--                                           read; any client write is
--                                           overwritten by trigger.
--   * profiles.email can no longer be changed by API roles (anon/authenticated).
--
-- Non-destructive: adds a column/functions/triggers and backfills the new flag.
-- =============================================================================

create or replace function public.platform_owner_emails()
returns text[]
language sql
immutable
set search_path = public
as $$
  select array['alikarim4r@gmail.com']::text[];
$$;

comment on function public.platform_owner_emails() is
  'Server-side platform-owner allowlist (lower-case). Change only via migration.';

revoke all on function public.platform_owner_emails() from public, anon, authenticated;

create or replace function public.is_platform_owner_user(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select p_user_id is not null
    and exists (
      select 1
      from auth.users u
      where u.id = p_user_id
        and u.email_confirmed_at is not null
        and lower(trim(u.email)) = any (public.platform_owner_emails())
    );
$$;

comment on function public.is_platform_owner_user(uuid) is
  'True when the auth user has a confirmed email in platform_owner_emails(). Source of truth for ownership.';

revoke all on function public.is_platform_owner_user(uuid) from public, anon, authenticated;

-- Same signature/grant as 052 — every existing policy/RPC keeps working.
create or replace function public.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_owner_user(auth.uid());
$$;

comment on function public.is_platform_owner() is
  'True when the signed-in auth user is a platform owner (auth.users email, confirmed). Server-authoritative.';

grant execute on function public.is_platform_owner() to authenticated;

-- -----------------------------------------------------------------------------
-- Server-maintained client flag + email lock
-- -----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists is_platform_owner boolean not null default false;

comment on column public.profiles.is_platform_owner is
  'Server-maintained mirror of is_platform_owner_user(id). Clients read it; writes are overwritten.';

-- SECURITY INVOKER on purpose: current_user must be the caller's role.
-- API roles may not rewrite their identity email (it fed ownership checks in
-- 052/056). Privileged paths (SECURITY DEFINER RPCs, migrations,
-- service_role) run as other roles and are unaffected.
create or replace function public.profiles_lock_email()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.email is distinct from old.email
     and current_user in ('anon', 'authenticated') then
    raise exception 'profiles.email is managed by authentication and cannot be changed here'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_lock_email on public.profiles;
create trigger profiles_lock_email
  before update on public.profiles
  for each row execute function public.profiles_lock_email();

-- SECURITY DEFINER: reads auth.users. Overwrites any client-supplied value.
create or replace function public.profiles_enforce_owner_flag()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  new.is_platform_owner := public.is_platform_owner_user(new.id);
  return new;
end;
$$;

revoke all on function public.profiles_enforce_owner_flag() from public, anon, authenticated;

drop trigger if exists profiles_enforce_owner_flag on public.profiles;
create trigger profiles_enforce_owner_flag
  before insert or update on public.profiles
  for each row execute function public.profiles_enforce_owner_flag();

-- Keep the flag current when the auth identity changes.
create or replace function public.auth_user_sync_owner_flag()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  update public.profiles
  set is_platform_owner = public.is_platform_owner_user(new.id)
  where id = new.id
    and is_platform_owner is distinct from public.is_platform_owner_user(new.id);
  return new;
end;
$$;

revoke all on function public.auth_user_sync_owner_flag() from public, anon, authenticated;

drop trigger if exists auth_user_sync_owner_flag on auth.users;
create trigger auth_user_sync_owner_flag
  after update of email, email_confirmed_at on auth.users
  for each row execute function public.auth_user_sync_owner_flag();

-- Backfill (only rows whose flag differs; trigger recomputes the value).
update public.profiles p
set is_platform_owner = public.is_platform_owner_user(p.id)
where p.is_platform_owner is distinct from public.is_platform_owner_user(p.id);

-- Operator visibility: warn (do not fail) when no confirmed owner exists yet.
do $$
begin
  if not exists (
    select 1 from auth.users u
    where u.email_confirmed_at is not null
      and lower(trim(u.email)) = any (public.platform_owner_emails())
  ) then
    raise warning 'No confirmed platform-owner auth user found; is_platform_owner() is false for everyone until one exists.';
  end if;
end;
$$;
