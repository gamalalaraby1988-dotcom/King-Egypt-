-- Test-only daily display-name change gate.
-- Uses authenticated Supabase identity and server UTC date.
-- Direct table access stays closed; only the authenticated RPC is executable.

create table if not exists game_test.player_profiles (
  test_account_id uuid primary key
    references game_test.wallets(test_account_id) on delete restrict,
  display_name text,
  last_name_change_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_profiles_display_name_length
    check (display_name is null or char_length(display_name) between 1 and 24)
);

create unique index if not exists player_profiles_display_name_ci_uq
  on game_test.player_profiles (lower(display_name))
  where display_name is not null;

alter table game_test.player_profiles enable row level security;

insert into game_test.player_profiles (test_account_id)
select test_account_id
from game_test.auth_account_links
on conflict (test_account_id) do nothing;

create or replace function public.change_my_test_display_name(p_new_display_name text)
returns table (
  success boolean,
  current_display_name text,
  next_change_at timestamptz,
  error_code text
)
language plpgsql
security definer
set search_path = pg_catalog, game_test
as $function$
declare
  v_user_id uuid := auth.uid();
  v_account_id uuid;
  v_new_name text := btrim(coalesce(p_new_display_name, ''));
  v_old_name text;
  v_last_change timestamptz;
  v_now timestamptz := now();
  v_next_change timestamptz;
begin
  if v_user_id is null then
    return query select false, null::text, null::timestamptz, 'authentication_required';
    return;
  end if;

  if char_length(v_new_name) < 1 or char_length(v_new_name) > 24 then
    return query select false, null::text, null::timestamptz, 'invalid_display_name';
    return;
  end if;

  select l.test_account_id into v_account_id
  from game_test.auth_account_links l
  where l.auth_user_id = v_user_id;

  if v_account_id is null then
    return query select false, null::text, null::timestamptz, 'test_account_not_linked';
    return;
  end if;

  insert into game_test.player_profiles (test_account_id)
  values (v_account_id)
  on conflict (test_account_id) do nothing;

  select p.display_name, p.last_name_change_at
    into v_old_name, v_last_change
  from game_test.player_profiles p
  where p.test_account_id = v_account_id
  for update;

  if v_old_name is not null and lower(v_old_name) = lower(v_new_name) then
    return query select false, v_old_name, null::timestamptz, 'name_unchanged';
    return;
  end if;

  if v_last_change is not null
     and (v_last_change at time zone 'UTC')::date = (v_now at time zone 'UTC')::date then
    v_next_change := (date_trunc('day', v_now at time zone 'UTC') + interval '1 day') at time zone 'UTC';
    return query select false, v_old_name, v_next_change, 'daily_limit_reached';
    return;
  end if;

  update game_test.player_profiles p
  set display_name = v_new_name,
      last_name_change_at = v_now,
      updated_at = v_now
  where p.test_account_id = v_account_id;

  return query
  select true, v_new_name,
    (date_trunc('day', v_now at time zone 'UTC') + interval '1 day') at time zone 'UTC',
    null::text;
exception
  when unique_violation then
    return query select false, v_old_name, null::timestamptz, 'display_name_taken';
end;
$function$;

revoke all on function public.change_my_test_display_name(text) from public;
revoke all on function public.change_my_test_display_name(text) from anon;
grant execute on function public.change_my_test_display_name(text) to authenticated;

revoke all on table game_test.player_profiles from public, anon, authenticated, service_role;
