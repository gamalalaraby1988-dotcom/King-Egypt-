-- Test-only provisioning. The allowlist is intentionally empty by default.
create table game_private.test_account_provisioning_allowlist (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

alter table game_private.test_account_provisioning_allowlist enable row level security;
revoke all on game_private.test_account_provisioning_allowlist from public, anon, authenticated;

create or replace function game_private.ensure_my_test_player_account()
returns table(test_account_id uuid, player_code text, created boolean)
language plpgsql
security definer
set search_path = pg_catalog
as $function$
declare
  v_auth_user_id uuid;
  v_test_account_id uuid;
  v_player_code text;
begin
  v_auth_user_id := auth.uid();
  if v_auth_user_id is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  if not exists (
    select 1 from game_private.test_account_provisioning_allowlist a
    where a.auth_user_id = v_auth_user_id and a.enabled
  ) then
    raise exception 'test_provisioning_not_enabled' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended(v_auth_user_id::text, 0));
  select l.test_account_id into v_test_account_id
  from game_test.auth_account_links l where l.auth_user_id = v_auth_user_id;
  if v_test_account_id is not null then
    select i.player_code into v_player_code
    from game_test.player_identities i where i.test_account_id = v_test_account_id;
    if v_player_code is null then
      raise exception 'linked_test_account_missing_player_identity' using errcode = '23514';
    end if;
    return query select v_test_account_id, v_player_code, false;
    return;
  end if;
  v_test_account_id := gen_random_uuid();
  insert into game_test.wallets(test_account_id) values (v_test_account_id);
  insert into game_test.player_profiles(test_account_id) values (v_test_account_id);
  loop
    v_player_code := upper(substr(md5(gen_random_uuid()::text), 1, 10));
    insert into game_test.player_identities(test_account_id, player_code)
    values (v_test_account_id, v_player_code)
    on conflict (player_code) do nothing;
    exit when found;
  end loop;
  insert into game_test.auth_account_links(auth_user_id, test_account_id)
  values (v_auth_user_id, v_test_account_id);
  return query select v_test_account_id, v_player_code, true;
end;
$function$;

revoke all on function game_private.ensure_my_test_player_account() from public, anon;
grant execute on function game_private.ensure_my_test_player_account() to authenticated;

create or replace function public.ensure_my_test_player_account()
returns table(test_account_id uuid, player_code text, created boolean)
language sql
security invoker
set search_path = pg_catalog
as $function$
  select * from game_private.ensure_my_test_player_account()
$function$;

revoke all on function public.ensure_my_test_player_account() from public, anon;
grant execute on function public.ensure_my_test_player_account() to authenticated;
