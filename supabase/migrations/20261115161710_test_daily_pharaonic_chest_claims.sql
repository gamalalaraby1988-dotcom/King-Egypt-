-- Server-authoritative daily pharaonic chest claims for the test game environment.
create table if not exists game_test.daily_chest_reward_config (
  singleton boolean primary key default true check (singleton),
  reward_cash bigint,
  reward_chips bigint,
  reward_xp bigint,
  updated_at timestamptz not null default now(),
  constraint daily_chest_reward_config_nonnegative
    check (
      (reward_cash is null or reward_cash >= 0) and
      (reward_chips is null or reward_chips >= 0) and
      (reward_xp is null or reward_xp >= 0)
    )
);

insert into game_test.daily_chest_reward_config(singleton, reward_cash, reward_chips, reward_xp)
values (true, null, null, null)
on conflict (singleton) do nothing;

create table if not exists game_test.daily_chest_claims (
  test_account_id uuid not null references game_test.player_identities(test_account_id) on delete cascade,
  reward_day date not null,
  claimed_at timestamptz not null default now(),
  reward_cash bigint not null check (reward_cash >= 0),
  reward_chips bigint not null check (reward_chips >= 0),
  reward_xp bigint not null check (reward_xp >= 0),
  primary key (test_account_id, reward_day)
);

create index if not exists daily_chest_claims_recent
  on game_test.daily_chest_claims(reward_day desc, claimed_at desc);

alter table game_test.daily_chest_reward_config enable row level security;
alter table game_test.daily_chest_claims enable row level security;
revoke all on game_test.daily_chest_reward_config from public, anon, authenticated;
revoke all on game_test.daily_chest_claims from public, anon, authenticated;

create or replace function game_private.get_my_test_daily_chest_status()
returns jsonb language plpgsql stable security definer set search_path = pg_catalog as $function$
declare
  v_account_id uuid;
  v_reward_day date;
  v_claim game_test.daily_chest_claims%rowtype;
begin
  v_account_id := game_private.my_test_account_id();
  if v_account_id is null then
    return jsonb_build_object('status', 'authentication_required');
  end if;
  v_reward_day := (now() at time zone 'Africa/Cairo')::date;
  select * into v_claim from game_test.daily_chest_claims c
  where c.test_account_id = v_account_id and c.reward_day = v_reward_day;
  return jsonb_build_object(
    'status', case when found then 'claimed' else 'available' end,
    'reward_day', v_reward_day,
    'next_reset_at', ((v_reward_day + 1)::timestamp at time zone 'Africa/Cairo'),
    'claimed_at', case when found then v_claim.claimed_at else null end
  );
end;
$function$;

create or replace function game_private.claim_my_test_daily_chest()
returns jsonb language plpgsql security definer set search_path = pg_catalog as $function$
declare
  v_account_id uuid;
  v_reward_day date;
  v_cash bigint;
  v_chips bigint;
  v_xp bigint;
  v_cash_after bigint;
  v_chips_after bigint;
  v_xp_after bigint;
  v_existing game_test.daily_chest_claims%rowtype;
begin
  v_account_id := game_private.my_test_account_id();
  if v_account_id is null then
    return jsonb_build_object('status', 'authentication_required');
  end if;
  v_reward_day := (now() at time zone 'Africa/Cairo')::date;
  perform pg_advisory_xact_lock(hashtextextended(v_account_id::text, 41));
  select * into v_existing from game_test.daily_chest_claims c
  where c.test_account_id = v_account_id and c.reward_day = v_reward_day;
  if found then
    return jsonb_build_object('status', 'already_claimed', 'reward_day', v_reward_day,
      'reward_cash', v_existing.reward_cash, 'reward_chips', v_existing.reward_chips, 'reward_xp', v_existing.reward_xp);
  end if;
  select coalesce(c.reward_cash, 0), coalesce(c.reward_chips, 0), coalesce(c.reward_xp, 0)
    into v_cash, v_chips, v_xp
  from game_test.daily_chest_reward_config c where c.singleton = true for share;
  if not found or (v_cash = 0 and v_chips = 0 and v_xp = 0) then
    return jsonb_build_object('status', 'reward_not_configured');
  end if;
  select w.cash_balance + v_cash, w.chips_balance + v_chips
    into v_cash_after, v_chips_after
  from game_test.wallets w where w.test_account_id = v_account_id for update;
  if not found then return jsonb_build_object('status', 'player_account_not_ready'); end if;
  if v_cash_after < 0 or v_chips_after < 0 or v_cash_after > 2000000000 or v_chips_after > 2000000000 then
    return jsonb_build_object('status', 'wallet_limit_reached');
  end if;
  select p.xp_total + v_xp into v_xp_after
  from game_test.account_progress p where p.test_account_id = v_account_id for update;
  if not found then return jsonb_build_object('status', 'player_progress_not_ready'); end if;
  update game_test.wallets set cash_balance = v_cash_after, chips_balance = v_chips_after,
    account_version = account_version + 1, updated_at = now()
  where test_account_id = v_account_id;
  update game_test.account_progress set xp_total = v_xp_after, updated_at = now()
  where test_account_id = v_account_id;
  if v_cash > 0 then
    insert into game_test.ledger(test_account_id, delta, balance_after, request_key, asset_type)
    values (v_account_id, v_cash, v_cash_after, 'daily_chest:' || v_reward_day::text || ':' || v_account_id::text || ':cash', 'cash');
  end if;
  if v_chips > 0 then
    insert into game_test.ledger(test_account_id, delta, balance_after, request_key, asset_type)
    values (v_account_id, v_chips, v_chips_after, 'daily_chest:' || v_reward_day::text || ':' || v_account_id::text || ':chips', 'chips');
  end if;
  if v_xp > 0 then
    insert into game_test.ledger(test_account_id, delta, balance_after, request_key, asset_type)
    values (v_account_id, v_xp, v_xp_after, 'daily_chest:' || v_reward_day::text || ':' || v_account_id::text || ':xp', 'xp');
  end if;
  insert into game_test.daily_chest_claims(test_account_id, reward_day, reward_cash, reward_chips, reward_xp)
  values (v_account_id, v_reward_day, v_cash, v_chips, v_xp);
  return jsonb_build_object('status', 'claimed', 'reward_day', v_reward_day,
    'reward_cash', v_cash, 'reward_chips', v_chips, 'reward_xp', v_xp,
    'next_reset_at', ((v_reward_day + 1)::timestamp at time zone 'Africa/Cairo'));
end;
$function$;

create or replace function public.get_my_test_daily_chest_status()
returns jsonb language sql stable set search_path = pg_catalog as $function$
  select game_private.get_my_test_daily_chest_status()
$function$;
create or replace function public.claim_my_test_daily_chest()
returns jsonb language sql set search_path = pg_catalog as $function$
  select game_private.claim_my_test_daily_chest()
$function$;

revoke all on function game_private.get_my_test_daily_chest_status() from public, anon, authenticated;
revoke all on function game_private.claim_my_test_daily_chest() from public, anon, authenticated;
grant execute on function game_private.get_my_test_daily_chest_status() to authenticated;
grant execute on function game_private.claim_my_test_daily_chest() to authenticated;
revoke all on function public.get_my_test_daily_chest_status() from public, anon;
revoke all on function public.claim_my_test_daily_chest() from public, anon;
grant execute on function public.get_my_test_daily_chest_status() to authenticated;
grant execute on function public.claim_my_test_daily_chest() to authenticated;
