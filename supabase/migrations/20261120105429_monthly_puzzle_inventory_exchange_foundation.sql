-- Empty server-owned foundation for monthly puzzle pieces and atomic two-way exchanges.
-- No season, piece drops, prices, probabilities, or rewards are seeded.

create schema if not exists private;

create table if not exists private.puzzle_seasons (
    season_id uuid primary key default gen_random_uuid(),
    puzzle_id text not null check (puzzle_id ~ '^[a-z0-9][a-z0-9_.-]{0,79}$'),
    status text not null default 'draft' check (status in ('draft', 'active', 'archived')),
    start_at timestamptz not null,
    end_at timestamptz not null,
    created_at timestamptz not null default pg_catalog.now(),
    unique (season_id, puzzle_id),
    check (end_at = start_at + interval '720 hours')
);
create unique index if not exists puzzle_seasons_one_active_idx
    on private.puzzle_seasons (status) where status = 'active';

create table if not exists private.puzzle_piece_catalog (
    puzzle_id text not null,
    piece_id text not null check (piece_id ~ '^[a-z0-9][a-z0-9_.-]{0,79}$'),
    piece_index integer not null check (piece_index >= 0),
    rarity text not null check (rarity in ('standard', 'rare', 'gold')),
    asset_key text check (asset_key is null or pg_catalog.length(asset_key) <= 160),
    created_at timestamptz not null default pg_catalog.now(),
    primary key (puzzle_id, piece_id),
    unique (puzzle_id, piece_index)
);

create table if not exists private.player_puzzle_piece_balances (
    season_id uuid not null,
    puzzle_id text not null,
    user_id uuid not null references auth.users(id) on delete cascade,
    piece_id text not null,
    quantity integer not null check (quantity > 0),
    updated_at timestamptz not null default pg_catalog.now(),
    primary key (season_id, user_id, piece_id),
    foreign key (season_id, puzzle_id)
        references private.puzzle_seasons(season_id, puzzle_id) on delete cascade,
    foreign key (puzzle_id, piece_id)
        references private.puzzle_piece_catalog(puzzle_id, piece_id)
);
create index if not exists player_puzzle_piece_balances_user_idx
    on private.player_puzzle_piece_balances (user_id, season_id);

create table if not exists private.puzzle_piece_exchanges (
    exchange_id uuid primary key default gen_random_uuid(),
    season_id uuid not null,
    puzzle_id text not null,
    from_user_id uuid not null references auth.users(id) on delete cascade,
    to_user_id uuid not null references auth.users(id) on delete cascade,
    offered_piece_id text not null,
    offered_quantity integer not null check (offered_quantity > 0),
    requested_piece_id text not null,
    requested_quantity integer not null check (requested_quantity > 0),
    request_id uuid not null,
    created_at timestamptz not null default pg_catalog.now(),
    check (from_user_id <> to_user_id),
    check (offered_piece_id <> requested_piece_id),
    unique (from_user_id, request_id),
    foreign key (season_id, puzzle_id)
        references private.puzzle_seasons(season_id, puzzle_id) on delete cascade,
    foreign key (puzzle_id, offered_piece_id)
        references private.puzzle_piece_catalog(puzzle_id, piece_id),
    foreign key (puzzle_id, requested_piece_id)
        references private.puzzle_piece_catalog(puzzle_id, piece_id)
);
create index if not exists puzzle_piece_exchanges_recipient_idx
    on private.puzzle_piece_exchanges (to_user_id, created_at desc);

alter table private.puzzle_seasons enable row level security;
alter table private.puzzle_seasons force row level security;
alter table private.puzzle_piece_catalog enable row level security;
alter table private.puzzle_piece_catalog force row level security;
alter table private.player_puzzle_piece_balances enable row level security;
alter table private.player_puzzle_piece_balances force row level security;
alter table private.puzzle_piece_exchanges enable row level security;
alter table private.puzzle_piece_exchanges force row level security;

create policy puzzle_seasons_read_published on private.puzzle_seasons
    for select to authenticated using (status in ('active', 'archived'));
create policy puzzle_seasons_service_all on private.puzzle_seasons
    for all to service_role using (true) with check (true);
create policy puzzle_piece_catalog_read_published on private.puzzle_piece_catalog
    for select to authenticated using (
        exists (select 1 from private.puzzle_seasons s
            where s.puzzle_id = puzzle_piece_catalog.puzzle_id
              and s.status in ('active', 'archived'))
    );
create policy puzzle_piece_catalog_service_all on private.puzzle_piece_catalog
    for all to service_role using (true) with check (true);
create policy player_puzzle_piece_balances_read_own on private.player_puzzle_piece_balances
    for select to authenticated using ((select auth.uid()) = user_id);
create policy player_puzzle_piece_balances_service_all on private.player_puzzle_piece_balances
    for all to service_role using (true) with check (true);
create policy puzzle_piece_exchanges_read_participant on private.puzzle_piece_exchanges
    for select to authenticated using (
        (select auth.uid()) = from_user_id or (select auth.uid()) = to_user_id
    );
create policy puzzle_piece_exchanges_service_all on private.puzzle_piece_exchanges
    for all to service_role using (true) with check (true);

revoke all on table private.puzzle_seasons from public, anon, authenticated;
revoke all on table private.puzzle_piece_catalog from public, anon, authenticated;
revoke all on table private.player_puzzle_piece_balances from public, anon, authenticated;
revoke all on table private.puzzle_piece_exchanges from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;
grant select on table private.puzzle_seasons, private.puzzle_piece_catalog,
    private.player_puzzle_piece_balances, private.puzzle_piece_exchanges to authenticated;
grant select, insert, update, delete on table private.puzzle_seasons,
    private.puzzle_piece_catalog, private.player_puzzle_piece_balances,
    private.puzzle_piece_exchanges to service_role;

create or replace function private.exchange_monthly_puzzle_pieces(
    p_season_id uuid, p_to_user_id uuid,
    p_offered_piece_id text, p_offered_quantity integer,
    p_requested_piece_id text, p_requested_quantity integer, p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_user_id uuid := auth.uid();
    v_season private.puzzle_seasons%rowtype;
    v_existing private.puzzle_piece_exchanges%rowtype;
    v_exchange_id uuid;
    v_offered_balance integer;
    v_requested_balance integer;
begin
    if v_user_id is null then
        raise exception 'authentication_required' using errcode = '28000';
    end if;
    if p_season_id is null or p_to_user_id is null or p_request_id is null
       or p_offered_piece_id is null or p_requested_piece_id is null
       or p_offered_piece_id = p_requested_piece_id or p_to_user_id = v_user_id
       or p_offered_quantity is null or p_offered_quantity <= 0
       or p_requested_quantity is null or p_requested_quantity <= 0 then
        raise exception 'invalid_puzzle_exchange_request' using errcode = '22023';
    end if;

    insert into private.puzzle_piece_exchanges (
        season_id, puzzle_id, from_user_id, to_user_id,
        offered_piece_id, offered_quantity, requested_piece_id, requested_quantity, request_id
    )
    select s.season_id, s.puzzle_id, v_user_id, p_to_user_id,
        p_offered_piece_id, p_offered_quantity, p_requested_piece_id, p_requested_quantity, p_request_id
    from private.puzzle_seasons s where s.season_id = p_season_id
    on conflict (from_user_id, request_id) do nothing
    returning exchange_id into v_exchange_id;

    if v_exchange_id is null then
        select * into v_existing from private.puzzle_piece_exchanges
        where from_user_id = v_user_id and request_id = p_request_id;
        if not found or v_existing.season_id <> p_season_id
           or v_existing.to_user_id <> p_to_user_id
           or v_existing.offered_piece_id <> p_offered_piece_id
           or v_existing.offered_quantity <> p_offered_quantity
           or v_existing.requested_piece_id <> p_requested_piece_id
           or v_existing.requested_quantity <> p_requested_quantity then
            raise exception 'puzzle_exchange_request_id_conflict' using errcode = '23505';
        end if;
        return pg_catalog.jsonb_build_object(
            'success', true, 'duplicate', true, 'exchange_id', v_existing.exchange_id
        );
    end if;

    select * into v_season from private.puzzle_seasons
    where season_id = p_season_id and status = 'active'
      and start_at <= pg_catalog.now() and end_at > pg_catalog.now()
    for update;
    if not found then
        raise exception 'puzzle_season_not_active' using errcode = '22023';
    end if;

    if not exists (select 1 from private.puzzle_piece_catalog c
        where c.puzzle_id = v_season.puzzle_id and c.piece_id = p_offered_piece_id)
       or not exists (select 1 from private.puzzle_piece_catalog c
        where c.puzzle_id = v_season.puzzle_id and c.piece_id = p_requested_piece_id) then
        raise exception 'puzzle_piece_not_in_season_catalog' using errcode = '22023';
    end if;

    perform 1 from private.player_puzzle_piece_balances b
    where b.season_id = p_season_id and (
        (b.user_id = v_user_id and b.piece_id = p_offered_piece_id)
        or (b.user_id = p_to_user_id and b.piece_id = p_requested_piece_id)
    )
    order by b.user_id, b.piece_id for update;

    select b.quantity into v_offered_balance from private.player_puzzle_piece_balances b
    where b.season_id = p_season_id and b.user_id = v_user_id and b.piece_id = p_offered_piece_id;
    select b.quantity into v_requested_balance from private.player_puzzle_piece_balances b
    where b.season_id = p_season_id and b.user_id = p_to_user_id and b.piece_id = p_requested_piece_id;

    if coalesce(v_offered_balance, 0) < p_offered_quantity
       or coalesce(v_requested_balance, 0) < p_requested_quantity then
        raise exception 'puzzle_piece_balance_insufficient' using errcode = '22023';
    end if;

    update private.player_puzzle_piece_balances
    set quantity = quantity - p_offered_quantity, updated_at = pg_catalog.now()
    where season_id = p_season_id and user_id = v_user_id and piece_id = p_offered_piece_id;
    delete from private.player_puzzle_piece_balances
    where season_id = p_season_id and user_id = v_user_id and piece_id = p_offered_piece_id and quantity = 0;

    update private.player_puzzle_piece_balances
    set quantity = quantity - p_requested_quantity, updated_at = pg_catalog.now()
    where season_id = p_season_id and user_id = p_to_user_id and piece_id = p_requested_piece_id;
    delete from private.player_puzzle_piece_balances
    where season_id = p_season_id and user_id = p_to_user_id and piece_id = p_requested_piece_id and quantity = 0;

    insert into private.player_puzzle_piece_balances (season_id, puzzle_id, user_id, piece_id, quantity)
    values (p_season_id, v_season.puzzle_id, p_to_user_id, p_offered_piece_id, p_offered_quantity)
    on conflict (season_id, user_id, piece_id) do update
    set quantity = private.player_puzzle_piece_balances.quantity + excluded.quantity,
        updated_at = pg_catalog.now();

    insert into private.player_puzzle_piece_balances (season_id, puzzle_id, user_id, piece_id, quantity)
    values (p_season_id, v_season.puzzle_id, v_user_id, p_requested_piece_id, p_requested_quantity)
    on conflict (season_id, user_id, piece_id) do update
    set quantity = private.player_puzzle_piece_balances.quantity + excluded.quantity,
        updated_at = pg_catalog.now();

    return pg_catalog.jsonb_build_object('success', true, 'duplicate', false, 'exchange_id', v_exchange_id);
end;
$function$;

revoke all on function private.exchange_monthly_puzzle_pieces(uuid, uuid, text, integer, text, integer, uuid)
    from public, anon;
grant execute on function private.exchange_monthly_puzzle_pieces(uuid, uuid, text, integer, text, integer, uuid)
    to authenticated;

create or replace function public.exchange_monthly_puzzle_pieces(
    p_season_id uuid, p_to_user_id uuid,
    p_offered_piece_id text, p_offered_quantity integer,
    p_requested_piece_id text, p_requested_quantity integer, p_request_id uuid
)
returns jsonb
language sql
security invoker
set search_path = ''
as $wrapper$
    select private.exchange_monthly_puzzle_pieces(
        p_season_id, p_to_user_id, p_offered_piece_id, p_offered_quantity,
        p_requested_piece_id, p_requested_quantity, p_request_id
    );
$wrapper$;

revoke all on function public.exchange_monthly_puzzle_pieces(uuid, uuid, text, integer, text, integer, uuid)
    from public, anon;
grant execute on function public.exchange_monthly_puzzle_pieces(uuid, uuid, text, integer, text, integer, uuid)
    to authenticated;

comment on table private.puzzle_seasons is
'Server-managed exact 30-day puzzle seasons. Archived seasons remain available for the player album.';
comment on table private.puzzle_piece_catalog is
'Server-managed puzzle piece definitions and rarity. No drop probabilities or reward values are defined.';
comment on table private.player_puzzle_piece_balances is
'Server-owned inventory. Players may read only their own balances; client writes are not granted.';
comment on table private.puzzle_piece_exchanges is
'Idempotency ledger for atomic two-way exchanges. Both debits and credits commit or roll back together.';
comment on function public.exchange_monthly_puzzle_pieces(uuid, uuid, text, integer, text, integer, uuid) is
'Atomic two-way puzzle-piece exchange during an active season. Authenticated owner only; idempotent request_id; no currency or reward settlement.';
