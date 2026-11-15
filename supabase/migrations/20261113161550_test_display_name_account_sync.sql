-- Create the test-only profile table before any migration reads or grants on it.
-- Name changes remain restricted to the authenticated server-side RPC.
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

alter table game_test.player_profiles enable row level security;

grant select on table game_test.player_profiles to authenticated;

drop policy if exists player_profiles_select_own on game_test.player_profiles;
create policy player_profiles_select_own
on game_test.player_profiles
for select
to authenticated
using (
  exists (
    select 1
    from game_test.auth_account_links l
    where l.test_account_id = player_profiles.test_account_id
      and l.auth_user_id = (select auth.uid())
  )
);

create or replace function public.get_my_test_display_name()
returns table (
  display_name text,
  last_name_change_at timestamptz,
  next_change_at timestamptz
)
language sql
stable
security invoker
set search_path = pg_catalog, game_test
as $function$
  select
    p.display_name,
    p.last_name_change_at,
    case
      when p.last_name_change_at is null then null::timestamptz
      else (
        date_trunc('day', p.last_name_change_at at time zone 'UTC')
        + interval '1 day'
      ) at time zone 'UTC'
    end as next_change_at
  from game_test.auth_account_links l
  join game_test.player_profiles p
    on p.test_account_id = l.test_account_id
  where l.auth_user_id = (select auth.uid())
  limit 1;
$function$;

revoke all on function public.get_my_test_display_name() from public, anon, authenticated, service_role;
grant execute on function public.get_my_test_display_name() to authenticated;
