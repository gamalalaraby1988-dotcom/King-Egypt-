-- Server-authoritative settlement for virtual slot chips.
-- The three approved machines are intentionally disabled until the dedicated
-- game-server controller and HMAC settlement path are deployed and verified.

create schema if not exists private;

create or replace function private.is_valid_slot_integer_array(
    p_values integer[],
    p_expected_length integer,
    p_max_value integer
)
returns boolean
language sql
immutable
set search_path = ''
as $function$
    select p_values is not null
       and pg_catalog.cardinality(p_values) = p_expected_length
       and not exists (
           select 1
           from pg_catalog.unnest(p_values) as value
           where value <= 0 or value > p_max_value
       );
$function$;

create or replace function private.is_valid_slot_weights(p_values integer[])
returns boolean
language sql
immutable
set search_path = ''
as $function$
    select private.is_valid_slot_integer_array(p_values, 5, 10000)
       and (select pg_catalog.sum(value) from pg_catalog.unnest(p_values) as value) = 10000;
$function$;

create table if not exists private.arcade_slot_machine_rules (
    machine_id text primary key
        check (machine_id in ('vip_royal_classic', 'vip_diamond_royale', 'vip_golden_crown')),
    reel_count smallint not null default 3 check (reel_count = 3),
    symbol_weights_bps integer[] not null
        check (private.is_valid_slot_weights(symbol_weights_bps)),
    triple_payout_tenths integer[] not null
        check (private.is_valid_slot_integer_array(triple_payout_tenths, 5, 5000)),
    pair_payout_tenths integer not null default 1 check (pair_payout_tenths = 1),
    minimum_bet_chips bigint not null default 10 check (minimum_bet_chips = 10),
    enabled boolean not null default false,
    created_at timestamptz not null default pg_catalog.now(),
    updated_at timestamptz not null default pg_catalog.now()
);

insert into private.arcade_slot_machine_rules (
    machine_id, reel_count, symbol_weights_bps, triple_payout_tenths,
    pair_payout_tenths, minimum_bet_chips, enabled
) values
    ('vip_royal_classic', 3, array[4000,3000,1800,900,300], array[50,100,300,1200,5000], 1, 10, false),
    ('vip_diamond_royale', 3, array[4000,3000,1800,900,300], array[50,100,300,1200,5000], 1, 10, false),
    ('vip_golden_crown', 3, array[4000,3000,1800,900,300], array[50,100,300,1200,5000], 1, 10, false)
on conflict (machine_id) do nothing;

create table if not exists private.arcade_slot_round_ledger (
    round_id uuid primary key default gen_random_uuid(),
    server_event_id uuid not null unique,
    user_id uuid not null references auth.users(id) on delete restrict,
    session_id uuid not null,
    machine_id text not null references private.arcade_slot_machine_rules(machine_id),
    wager_chips bigint not null check (wager_chips between 10 and 2000000000),
    symbols integer[] not null
        check (
            pg_catalog.cardinality(symbols) = 3
            and symbols <@ array[0,1,2,3,4]::integer[]
        ),
    payout_multiplier_tenths integer not null check (payout_multiplier_tenths between 0 and 5000),
    gross_return_chips bigint not null check (gross_return_chips between 0 and 2000000000),
    balance_before bigint not null check (balance_before between 0 and 2000000000),
    balance_after bigint not null check (balance_after between 0 and 2000000000),
    settled_at timestamptz not null default pg_catalog.now()
);

create index if not exists arcade_slot_round_ledger_user_time_idx
    on private.arcade_slot_round_ledger(user_id, settled_at desc);
create index if not exists arcade_slot_round_ledger_session_idx
    on private.arcade_slot_round_ledger(session_id, settled_at);

alter table private.arcade_slot_machine_rules enable row level security;
alter table private.arcade_slot_machine_rules force row level security;
alter table private.arcade_slot_round_ledger enable row level security;
alter table private.arcade_slot_round_ledger force row level security;

revoke all on table private.arcade_slot_machine_rules from public, anon, authenticated, service_role;
revoke all on table private.arcade_slot_round_ledger from public, anon, authenticated, service_role;
grant usage on schema private to service_role;

create or replace function private.calculate_slot_payout_tenths(
    p_machine_id text,
    p_symbols integer[]
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
    v_rules private.arcade_slot_machine_rules%rowtype;
begin
    if p_machine_id is null
       or p_symbols is null
       or pg_catalog.cardinality(p_symbols) <> 3
       or exists (
           select 1 from pg_catalog.unnest(p_symbols) as symbol
           where symbol < 0 or symbol > 4
       ) then
        return 0;
    end if;

    select * into v_rules
    from private.arcade_slot_machine_rules
    where machine_id = p_machine_id;

    if not found
       or not private.is_valid_slot_weights(v_rules.symbol_weights_bps)
       or not private.is_valid_slot_integer_array(v_rules.triple_payout_tenths, 5, 5000) then
        return 0;
    end if;

    if p_symbols[1] = p_symbols[2] and p_symbols[2] = p_symbols[3] then
        return v_rules.triple_payout_tenths[p_symbols[1] + 1];
    end if;

    if p_symbols[1] = p_symbols[2]
       or p_symbols[1] = p_symbols[3]
       or p_symbols[2] = p_symbols[3] then
        return v_rules.pair_payout_tenths;
    end if;

    return 0;
end;
$function$;

create or replace function private.settle_arcade_slot_round(
    p_user_id uuid,
    p_session_id uuid,
    p_server_event_id uuid,
    p_machine_id text,
    p_wager_chips bigint,
    p_symbols integer[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_rules private.arcade_slot_machine_rules%rowtype;
    v_wallet public.player_wallets%rowtype;
    v_existing private.arcade_slot_round_ledger%rowtype;
    v_round private.arcade_slot_round_ledger%rowtype;
    v_multiplier integer;
    v_gross_return bigint;
    v_balance_after bigint;
begin
    if p_user_id is null or p_session_id is null or p_server_event_id is null
       or p_machine_id is null or p_wager_chips is null or p_symbols is null then
        raise exception 'slot_round_payload_invalid' using errcode = '22023';
    end if;

    if p_wager_chips < 10 or p_wager_chips > 2000000000
       or pg_catalog.cardinality(p_symbols) <> 3
       or exists (
           select 1 from pg_catalog.unnest(p_symbols) as symbol
           where symbol < 0 or symbol > 4
       ) then
        raise exception 'slot_round_values_invalid' using errcode = '22023';
    end if;

    select * into v_existing
    from private.arcade_slot_round_ledger
    where server_event_id = p_server_event_id;

    if found then
        if v_existing.user_id <> p_user_id
           or v_existing.session_id <> p_session_id
           or v_existing.machine_id <> p_machine_id
           or v_existing.wager_chips <> p_wager_chips
           or v_existing.symbols <> p_symbols then
            raise exception 'slot_round_event_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object(
            'settled', true, 'duplicate', true, 'round_id', v_existing.round_id,
            'wager_chips', v_existing.wager_chips,
            'gross_return_chips', v_existing.gross_return_chips,
            'payout_multiplier_tenths', v_existing.payout_multiplier_tenths,
            'balance_before', v_existing.balance_before,
            'balance_after', v_existing.balance_after, 'symbols', v_existing.symbols
        );
    end if;

    select * into v_rules
    from private.arcade_slot_machine_rules
    where machine_id = p_machine_id and enabled = true;

    if not found then
        raise exception 'slot_machine_not_enabled' using errcode = '55000';
    end if;

    if p_wager_chips < v_rules.minimum_bet_chips then
        raise exception 'slot_bet_below_minimum' using errcode = '22023';
    end if;

    select * into v_wallet
    from public.player_wallets
    where user_id = p_user_id
    for update;

    if not found then
        raise exception 'player_wallet_not_found' using errcode = 'P0002';
    end if;

    select * into v_existing
    from private.arcade_slot_round_ledger
    where server_event_id = p_server_event_id;

    if found then
        if v_existing.user_id <> p_user_id
           or v_existing.session_id <> p_session_id
           or v_existing.machine_id <> p_machine_id
           or v_existing.wager_chips <> p_wager_chips
           or v_existing.symbols <> p_symbols then
            raise exception 'slot_round_event_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object(
            'settled', true, 'duplicate', true, 'round_id', v_existing.round_id,
            'wager_chips', v_existing.wager_chips,
            'gross_return_chips', v_existing.gross_return_chips,
            'payout_multiplier_tenths', v_existing.payout_multiplier_tenths,
            'balance_before', v_existing.balance_before,
            'balance_after', v_existing.balance_after, 'symbols', v_existing.symbols
        );
    end if;

    if v_wallet.chips < p_wager_chips then
        raise exception 'insufficient_game_chips' using errcode = '22003';
    end if;

    v_multiplier := private.calculate_slot_payout_tenths(p_machine_id, p_symbols);
    v_gross_return := (p_wager_chips * v_multiplier) / 10;
    v_balance_after := v_wallet.chips - p_wager_chips + v_gross_return;

    if v_balance_after < 0 or v_balance_after > 2000000000
       or v_gross_return > 2000000000 then
        raise exception 'player_wallet_limit_exceeded' using errcode = '22003';
    end if;

    insert into private.arcade_slot_round_ledger (
        server_event_id, user_id, session_id, machine_id, wager_chips,
        symbols, payout_multiplier_tenths, gross_return_chips,
        balance_before, balance_after
    ) values (
        p_server_event_id, p_user_id, p_session_id, p_machine_id, p_wager_chips,
        p_symbols, v_multiplier, v_gross_return, v_wallet.chips, v_balance_after
    )
    on conflict (server_event_id) do nothing
    returning * into v_round;

    if not found then
        select * into v_existing
        from private.arcade_slot_round_ledger
        where server_event_id = p_server_event_id;
        if not found
           or v_existing.user_id <> p_user_id
           or v_existing.session_id <> p_session_id
           or v_existing.machine_id <> p_machine_id
           or v_existing.wager_chips <> p_wager_chips
           or v_existing.symbols <> p_symbols then
            raise exception 'slot_round_event_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object(
            'settled', true, 'duplicate', true, 'round_id', v_existing.round_id,
            'wager_chips', v_existing.wager_chips,
            'gross_return_chips', v_existing.gross_return_chips,
            'payout_multiplier_tenths', v_existing.payout_multiplier_tenths,
            'balance_before', v_existing.balance_before,
            'balance_after', v_existing.balance_after, 'symbols', v_existing.symbols
        );
    end if;

    update public.player_wallets
    set chips = v_balance_after, updated_at = pg_catalog.now()
    where user_id = p_user_id;

    return pg_catalog.jsonb_build_object(
        'settled', true, 'duplicate', false, 'round_id', v_round.round_id,
        'wager_chips', p_wager_chips, 'gross_return_chips', v_gross_return,
        'payout_multiplier_tenths', v_multiplier,
        'balance_before', v_wallet.chips, 'balance_after', v_balance_after,
        'symbols', p_symbols
    );
end;
$function$;

revoke all on function private.is_valid_slot_integer_array(integer[], integer, integer) from public, anon, authenticated;
revoke all on function private.is_valid_slot_weights(integer[]) from public, anon, authenticated;
revoke all on function private.calculate_slot_payout_tenths(text, integer[]) from public, anon, authenticated;
revoke all on function private.settle_arcade_slot_round(uuid, uuid, uuid, text, bigint, integer[]) from public, anon, authenticated;
grant execute on function private.settle_arcade_slot_round(uuid, uuid, uuid, text, bigint, integer[]) to service_role;

create or replace function public.settle_arcade_slot_round(
    p_user_id uuid,
    p_session_id uuid,
    p_server_event_id uuid,
    p_machine_id text,
    p_wager_chips bigint,
    p_symbols integer[]
)
returns jsonb
language sql
security invoker
set search_path = ''
as $wrapper$
    select private.settle_arcade_slot_round(
        p_user_id, p_session_id, p_server_event_id, p_machine_id, p_wager_chips, p_symbols
    );
$wrapper$;

revoke all on function public.settle_arcade_slot_round(uuid, uuid, uuid, text, bigint, integer[])
    from public, anon, authenticated;
grant execute on function public.settle_arcade_slot_round(uuid, uuid, uuid, text, bigint, integer[])
    to service_role;

comment on table private.arcade_slot_machine_rules is
'Server-owned slot odds and payout configuration. All three approved VIP machines are disabled until the trusted game-server controller is deployed and verified.';
comment on table private.arcade_slot_round_ledger is
'Immutable server-settled slot round ledger. Each server event can debit and credit chips at most once in the same database transaction.';
comment on function public.settle_arcade_slot_round(uuid, uuid, uuid, text, bigint, integer[]) is
'Service-role-only wrapper called by the HMAC-verifying slot-machine-settlement Edge Function. Client roles cannot execute it; all chip settlement and ledger insertion are atomic.';
