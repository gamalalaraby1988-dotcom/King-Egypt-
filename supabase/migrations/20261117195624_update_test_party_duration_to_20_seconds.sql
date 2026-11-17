-- Update the test-party lifetime to the user-approved 20 seconds.
-- Keep the party-start RPC disabled until authoritative server-side location validation exists.

alter table game_test.party_sessions
  drop constraint if exists party_sessions_duration_check;

-- Normalize already-created test sessions before enforcing the new duration.
update game_test.party_sessions
   set ends_at = started_at + interval '20 seconds'
 where ends_at = started_at + interval '15 seconds';

alter table game_test.party_sessions
  add constraint party_sessions_duration_check
  check (ends_at = started_at + interval '20 seconds');

create or replace function game_private.start_my_test_party(p_station_key text)
returns table (
  party_id uuid,
  started_at timestamptz,
  ends_at timestamptz,
  gems_balance bigint
)
language plpgsql
security definer
set search_path = pg_catalog, game_test, game_private
as $function$
declare
  v_account_id uuid;
  v_party_id uuid;
  v_started_at timestamptz;
  v_ends_at timestamptz;
  v_balance bigint;
  v_request_key text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if p_station_key is null
     or length(btrim(p_station_key)) < 1
     or length(btrim(p_station_key)) > 80
     or p_station_key !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'invalid party station';
  end if;

  v_account_id := game_private.my_test_account_id();
  if v_account_id is null then
    raise exception 'test player account is not linked';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_station_key, 0));

  update game_test.party_sessions
     set status = 'ended'
   where status = 'active'
     and ends_at <= clock_timestamp();

  if exists (
    select 1 from game_test.party_sessions
     where station_key = p_station_key and status = 'active'
  ) then
    raise exception 'party station is already active';
  end if;

  v_request_key := 'party-start:' || gen_random_uuid()::text;
  select resulting_balance
    into v_balance
    from game_test.apply_test_asset_delta(
      v_account_id,
      v_request_key,
      'party_start',
      'gems',
      -150
    );

  v_started_at := clock_timestamp();
  v_ends_at := v_started_at + interval '20 seconds';

  insert into game_test.party_sessions (
    station_key, host_account_id, started_at, ends_at, status, price_gems
  ) values (
    btrim(p_station_key), v_account_id, v_started_at, v_ends_at, 'active', 150
  )
  returning game_test.party_sessions.party_id into v_party_id;

  return query select v_party_id, v_started_at, v_ends_at, v_balance;
end;
$function$;

-- Preserve the existing safety lock: the client cannot start a paid party yet.
revoke all on function game_private.start_my_test_party(text) from public, anon, authenticated;
