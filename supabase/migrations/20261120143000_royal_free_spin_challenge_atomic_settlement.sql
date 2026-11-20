-- Royal free-spin challenge and unified paid/free spin settlement.
-- TEST-first: all machine rows remain disabled until the trusted game-server caller is integrated.

create table if not exists private.arcade_slot_challenge_rules (
    machine_id text primary key references private.arcade_slot_machine_rules(machine_id) on delete restrict,
    collectible_symbol_indices integer[] not null
        check (
            pg_catalog.cardinality(collectible_symbol_indices) between 1 and 2
            and collectible_symbol_indices <@ array[0,1,2,3,4]::integer[]
        ),
    created_at timestamptz not null default pg_catalog.now()
);

insert into private.arcade_slot_challenge_rules(machine_id, collectible_symbol_indices) values
    ('vip_royal_classic', array[0,4]),
    ('vip_diamond_royale', array[3,4]),
    ('vip_golden_crown', array[2,4])
on conflict (machine_id) do nothing;

create table if not exists private.arcade_slot_challenge_state (
    user_id uuid not null references auth.users(id) on delete restrict,
    machine_id text not null references private.arcade_slot_challenge_rules(machine_id) on delete restrict,
    challenge_progress smallint not null default 0 check (challenge_progress between 0 and 14),
    free_spins bigint not null default 0 check (free_spins between 0 and 2000000000),
    updated_at timestamptz not null default pg_catalog.now(),
    primary key (user_id, machine_id)
);

alter table private.arcade_slot_round_ledger
    add column if not exists spin_type text not null default 'paid'
        check (spin_type in ('paid', 'free')),
    add column if not exists collection_symbols integer[] not null default array[0,0,0,0,0,0,0,0,0]
        check (
            pg_catalog.cardinality(collection_symbols) = 9
            and collection_symbols <@ array[0,1,2,3,4]::integer[]
        ),
    add column if not exists collection_match_count smallint not null default 0
        check (collection_match_count between 0 and 9),
    add column if not exists collection_activity_multiplier smallint not null default 0
        check (collection_activity_multiplier in (0,10,15,20,30,40,50,100)),
    add column if not exists challenge_progress_before smallint not null default 0
        check (challenge_progress_before between 0 and 14),
    add column if not exists challenge_progress_after smallint not null default 0
        check (challenge_progress_after between 0 and 14),
    add column if not exists free_spins_before bigint not null default 0
        check (free_spins_before between 0 and 2000000000),
    add column if not exists free_spins_after bigint not null default 0
        check (free_spins_after between 0 and 2000000000),
    add column if not exists free_spins_awarded smallint not null default 0
        check (free_spins_awarded between 0 and 10);

create index if not exists arcade_slot_challenge_state_user_idx
    on private.arcade_slot_challenge_state(user_id, updated_at desc);

alter table private.arcade_slot_challenge_rules enable row level security;
alter table private.arcade_slot_challenge_rules force row level security;
alter table private.arcade_slot_challenge_state enable row level security;
alter table private.arcade_slot_challenge_state force row level security;

revoke all on table private.arcade_slot_challenge_rules from public, anon, authenticated, service_role;
revoke all on table private.arcade_slot_challenge_state from public, anon, authenticated, service_role;
grant usage on schema private to service_role;

create or replace function private.settle_arcade_slot_spin(
    p_user_id uuid,
    p_session_id uuid,
    p_server_event_id uuid,
    p_machine_id text,
    p_spin_type text,
    p_wager_chips bigint,
    p_reel_symbols integer[],
    p_collection_symbols integer[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_rules private.arcade_slot_machine_rules%rowtype;
    v_challenge_rules private.arcade_slot_challenge_rules%rowtype;
    v_state private.arcade_slot_challenge_state%rowtype;
    v_wallet public.player_wallets%rowtype;
    v_existing private.arcade_slot_round_ledger%rowtype;
    v_round private.arcade_slot_round_ledger%rowtype;
    v_multiplier integer;
    v_gross_return bigint;
    v_balance_after bigint;
    v_debit bigint;
    v_match_count integer := 0;
    v_symbol_index integer;
    v_symbol_count integer;
    v_total_progress integer;
    v_challenge_cycles integer;
    v_progress_after integer;
    v_awarded integer;
    v_free_spins_after bigint;
    v_activity_multiplier integer := 0;
begin
    if p_user_id is null or p_session_id is null or p_server_event_id is null
       or p_machine_id is null or p_spin_type is null or p_spin_type not in ('paid','free')
       or p_wager_chips is null or p_reel_symbols is null or p_collection_symbols is null then
        raise exception 'slot_spin_values_invalid' using errcode = '22023';
    end if;
    if pg_catalog.cardinality(p_reel_symbols) <> 3
       or exists (select 1 from pg_catalog.unnest(p_reel_symbols) as s where s < 0 or s > 4)
       or pg_catalog.cardinality(p_collection_symbols) <> 9
       or exists (select 1 from pg_catalog.unnest(p_collection_symbols) as s where s < 0 or s > 4) then
        raise exception 'slot_spin_symbols_invalid' using errcode = '22023';
    end if;
    if (p_spin_type = 'paid' and p_wager_chips not between 10 and 2000000000)
       or (p_spin_type = 'free' and p_wager_chips <> 10) then
        raise exception 'slot_spin_wager_invalid' using errcode = '22023';
    end if;

    -- Check idempotency before locking state, then re-check after acquiring the per-player/machine lock.
    select * into v_existing from private.arcade_slot_round_ledger
    where server_event_id = p_server_event_id;
    if found then
        if v_existing.user_id <> p_user_id or v_existing.session_id <> p_session_id
           or v_existing.machine_id <> p_machine_id or v_existing.spin_type <> p_spin_type
           or v_existing.wager_chips <> p_wager_chips or v_existing.symbols <> p_reel_symbols
           or v_existing.collection_symbols <> p_collection_symbols then
            raise exception 'slot_round_event_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object(
            'settled', true, 'duplicate', true, 'round_id', v_existing.round_id,
            'spin_type', v_existing.spin_type, 'wager_chips', v_existing.wager_chips,
            'gross_return_chips', v_existing.gross_return_chips,
            'payout_multiplier_tenths', v_existing.payout_multiplier_tenths,
            'balance_before', v_existing.balance_before, 'balance_after', v_existing.balance_after,
            'symbols', v_existing.symbols, 'collection_symbols', v_existing.collection_symbols,
            'collection_match_count', v_existing.collection_match_count,
            'collection_activity_multiplier', v_existing.collection_activity_multiplier,
            'challenge_progress', v_existing.challenge_progress_after,
            'free_spins_balance', v_existing.free_spins_after,
            'free_spins_awarded', v_existing.free_spins_awarded
        );
    end if;

    select * into v_rules from private.arcade_slot_machine_rules
    where machine_id = p_machine_id and enabled = true;
    if not found then
        raise exception 'slot_machine_not_enabled' using errcode = '55000';
    end if;
    select * into v_challenge_rules from private.arcade_slot_challenge_rules
    where machine_id = p_machine_id;
    if not found then
        raise exception 'slot_challenge_rules_missing' using errcode = '55000';
    end if;

    insert into private.arcade_slot_challenge_state(user_id, machine_id)
    values (p_user_id, p_machine_id)
    on conflict (user_id, machine_id) do nothing;
    select * into v_state from private.arcade_slot_challenge_state
    where user_id = p_user_id and machine_id = p_machine_id
    for update;

    select * into v_existing from private.arcade_slot_round_ledger
    where server_event_id = p_server_event_id;
    if found then
        if v_existing.user_id <> p_user_id or v_existing.session_id <> p_session_id
           or v_existing.machine_id <> p_machine_id or v_existing.spin_type <> p_spin_type
           or v_existing.wager_chips <> p_wager_chips or v_existing.symbols <> p_reel_symbols
           or v_existing.collection_symbols <> p_collection_symbols then
            raise exception 'slot_round_event_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object(
            'settled', true, 'duplicate', true, 'round_id', v_existing.round_id,
            'spin_type', v_existing.spin_type, 'wager_chips', v_existing.wager_chips,
            'gross_return_chips', v_existing.gross_return_chips,
            'payout_multiplier_tenths', v_existing.payout_multiplier_tenths,
            'balance_before', v_existing.balance_before, 'balance_after', v_existing.balance_after,
            'symbols', v_existing.symbols, 'collection_symbols', v_existing.collection_symbols,
            'collection_match_count', v_existing.collection_match_count,
            'collection_activity_multiplier', v_existing.collection_activity_multiplier,
            'challenge_progress', v_existing.challenge_progress_after,
            'free_spins_balance', v_existing.free_spins_after,
            'free_spins_awarded', v_existing.free_spins_awarded
        );
    end if;

    if p_spin_type = 'free' and v_state.free_spins < 1 then
        raise exception 'free_spin_balance_insufficient' using errcode = '22003';
    end if;

    select * into v_wallet from public.player_wallets
    where user_id = p_user_id for update;
    if not found then
        raise exception 'player_wallet_not_found' using errcode = 'P0002';
    end if;

    if p_spin_type = 'paid' and v_wallet.chips < p_wager_chips then
        raise exception 'insufficient_game_chips' using errcode = '22003';
    end if;

    v_multiplier := private.calculate_slot_payout_tenths(p_machine_id, p_reel_symbols);
    v_gross_return := (p_wager_chips * v_multiplier) / 10;
    v_debit := case when p_spin_type = 'paid' then p_wager_chips else 0 end;
    v_balance_after := v_wallet.chips - v_debit + v_gross_return;
    if v_balance_after < 0 or v_balance_after > 2000000000 or v_gross_return > 2000000000 then
        raise exception 'player_wallet_limit_exceeded' using errcode = '22003';
    end if;

    foreach v_symbol_index in array v_challenge_rules.collectible_symbol_indices loop
        select pg_catalog.count(*)::integer into v_symbol_count
        from pg_catalog.unnest(p_collection_symbols) as cell(symbol_index)
        where cell.symbol_index = v_symbol_index;
        v_match_count := greatest(v_match_count, v_symbol_count);
    end loop;

    v_activity_multiplier := case v_match_count
        when 3 then 10 when 4 then 15 when 5 then 20 when 6 then 30
        when 7 then 40 when 8 then 50 when 9 then 100 else 0 end;
    v_total_progress := v_state.challenge_progress + v_match_count;
    v_challenge_cycles := v_total_progress / 15;
    v_progress_after := v_total_progress % 15;
    v_awarded := v_challenge_cycles * 5;
    v_free_spins_after := v_state.free_spins
        - case when p_spin_type = 'free' then 1 else 0 end
        + v_awarded;
    if v_free_spins_after > 2000000000 then
        raise exception 'free_spin_wallet_limit_exceeded' using errcode = '22003';
    end if;

    insert into private.arcade_slot_round_ledger (
        server_event_id, user_id, session_id, machine_id, wager_chips, symbols,
        payout_multiplier_tenths, gross_return_chips, balance_before, balance_after,
        spin_type, collection_symbols, collection_match_count, collection_activity_multiplier,
        challenge_progress_before, challenge_progress_after, free_spins_before, free_spins_after,
        free_spins_awarded
    ) values (
        p_server_event_id, p_user_id, p_session_id, p_machine_id, p_wager_chips, p_reel_symbols,
        v_multiplier, v_gross_return, v_wallet.chips, v_balance_after,
        p_spin_type, p_collection_symbols, v_match_count, v_activity_multiplier,
        v_state.challenge_progress, v_progress_after, v_state.free_spins, v_free_spins_after,
        v_awarded
    )
    on conflict (server_event_id) do nothing
    returning * into v_round;

    if not found then
        select * into v_existing from private.arcade_slot_round_ledger
        where server_event_id = p_server_event_id;
        if not found or v_existing.user_id <> p_user_id or v_existing.session_id <> p_session_id
           or v_existing.machine_id <> p_machine_id or v_existing.spin_type <> p_spin_type
           or v_existing.wager_chips <> p_wager_chips or v_existing.symbols <> p_reel_symbols
           or v_existing.collection_symbols <> p_collection_symbols then
            raise exception 'slot_round_event_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object('settled', true, 'duplicate', true,
            'round_id', v_existing.round_id, 'balance_after', v_existing.balance_after,
            'challenge_progress', v_existing.challenge_progress_after,
            'free_spins_balance', v_existing.free_spins_after,
            'free_spins_awarded', v_existing.free_spins_awarded);
    end if;

    update public.player_wallets set chips = v_balance_after, updated_at = pg_catalog.now()
    where user_id = p_user_id;
    update private.arcade_slot_challenge_state
    set challenge_progress = v_progress_after, free_spins = v_free_spins_after,
        updated_at = pg_catalog.now()
    where user_id = p_user_id and machine_id = p_machine_id;

    return pg_catalog.jsonb_build_object(
        'settled', true, 'duplicate', false, 'round_id', v_round.round_id,
        'spin_type', p_spin_type, 'wager_chips', p_wager_chips,
        'gross_return_chips', v_gross_return, 'payout_multiplier_tenths', v_multiplier,
        'balance_before', v_wallet.chips, 'balance_after', v_balance_after,
        'symbols', p_reel_symbols, 'collection_symbols', p_collection_symbols,
        'collection_match_count', v_match_count,
        'collection_activity_multiplier', v_activity_multiplier,
        'challenge_progress', v_progress_after,
        'free_spins_balance', v_free_spins_after, 'free_spins_awarded', v_awarded
    );
end;
$function$;

revoke all on function private.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[])
    from public, anon, authenticated;
grant execute on function private.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[])
    to service_role;

create or replace function public.settle_arcade_slot_spin(
    p_user_id uuid,
    p_session_id uuid,
    p_server_event_id uuid,
    p_machine_id text,
    p_spin_type text,
    p_wager_chips bigint,
    p_reel_symbols integer[],
    p_collection_symbols integer[]
)
returns jsonb
language sql
security invoker
set search_path = ''
as $wrapper$
    select private.settle_arcade_slot_spin(
        p_user_id, p_session_id, p_server_event_id, p_machine_id,
        p_spin_type, p_wager_chips, p_reel_symbols, p_collection_symbols
    );
$wrapper$;

revoke all on function public.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[])
    from public, anon, authenticated;
grant execute on function public.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[])
    to service_role;

comment on table private.arcade_slot_challenge_state is
'Per-player, per-machine server-owned challenge progress and free-spin balance. Paid and free spins both advance progress.';
comment on table private.arcade_slot_challenge_rules is
'Server-owned machine-specific collectible symbol identities used by the one-spin 3x3 collection and 15-appearance challenge.';
comment on function public.settle_arcade_slot_spin(uuid,uuid,uuid,text,text,bigint,integer[],integer[]) is
'Service-role-only atomic settlement for paid/free spins. Server-generated results are recorded once; free spins use a 10-chip reference wager without debiting chips; both spin types advance the challenge.';
